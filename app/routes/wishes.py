"""Wishes API routes."""

import hashlib
import logging
from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session, joinedload

from app.config import settings
from app.database import get_db
from app.models import Wish, WishImage
from app.schemas import (
    WishCreate,
    WishCreateResponse,
    WishViewResponse,
    ErrorResponse,
    RateLimitResponse,
)
from app.services.slug import generate_unique_slug, get_client_ip_hash
from app.services.expiry import check_expiry, should_soft_delete

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["wishes"])

# In-memory rate limiting storage
# In production, use Redis
_rate_limit_storage: dict[str, dict] = {}


def get_client_ip(request: Request) -> str:
    """Get client IP from request, handling proxies."""
    # Check for X-Forwarded-For header (when behind proxy)
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    # Fall back to direct client IP
    return request.client.host if request.client else "unknown"


def check_rate_limit(client_ip: str) -> tuple[bool, Optional[str]]:
    """Check if client has exceeded rate limit.
    
    Args:
        client_ip: Client IP address
    
    Returns:
        Tuple of (is_allowed, error_message)
    """
    today = datetime.utcnow().strftime("%Y-%m-%d")
    key = f"{client_ip}:{today}"
    
    current_count = _rate_limit_storage.get(key, {}).get("count", 0)
    max_wishes = settings.MAX_WISHES_PER_IP_PER_DAY
    
    if current_count >= max_wishes:
        reset_time = _rate_limit_storage.get(key, {}).get("reset")
        if reset_time:
            time_until_reset = reset_time - datetime.utcnow()
            minutes = int(time_until_reset.total_seconds() / 60)
            return False, f"Rate limit exceeded. Maximum {max_wishes} wishes per day. Try again in {minutes} minutes."
        return False, f"Rate limit exceeded. Maximum {max_wishes} wishes per day per IP."
    
    return True, None


def increment_rate_limit(client_ip: str) -> None:
    """Increment rate limit counter for client IP."""
    today = datetime.utcnow().strftime("%Y-%m-%d")
    key = f"{client_ip}:{today}"
    
    if key not in _rate_limit_storage:
        _rate_limit_storage[key] = {
            "count": 0,
            "reset": datetime.utcnow() + timedelta(days=1)
        }
    
    _rate_limit_storage[key]["count"] += 1


@router.post(
    "/wishes", 
    response_model=WishCreateResponse,
    status_code=status.HTTP_201_CREATED,
    responses={
        429: {"model": RateLimitResponse, "description": "Rate limit exceeded"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    }
)
async def create_wish(
    wish_data: WishCreate,
    request: Request,
    db: Session = Depends(get_db)
):
    """Create a new wish.
    
    Creates a wish with optional expiry settings. The wish gets a unique
    slug that can be used to share the wish publicly.
    
    Rate limited to {} wishes per IP per day.
    """.format(settings.MAX_WISHES_PER_IP_PER_DAY)
    
    # Get client IP and check rate limit
    client_ip = get_client_ip(request)
    is_allowed, error_msg = check_rate_limit(client_ip)
    
    if not is_allowed:
        logger.warning(f"Rate limit exceeded for IP: {client_ip}")
        raise HTTPException(status_code=429, detail=error_msg)
    
    # Generate unique slug
    try:
        slug = generate_unique_slug(db)
    except RuntimeError as e:
        logger.error(f"Failed to generate slug: {e}")
        raise HTTPException(status_code=500, detail="Failed to generate wish slug")
    
    # Create wish
    ip_hash = get_client_ip_hash(client_ip)
    wish = Wish(
        slug=slug,
        title=wish_data.title,
        message=wish_data.message,
        theme=wish_data.theme,
        expires_at=wish_data.expires_at,
        max_views=wish_data.max_views,
        ip_hash=ip_hash
    )
    
    db.add(wish)
    db.commit()
    db.refresh(wish)
    
    # Increment rate limit
    increment_rate_limit(client_ip)
    
    # Build response
    public_url = f"{settings.BASE_URL}/w/{slug}"
    
    logger.info(f"Created wish: {slug} (id={wish.id})")
    
    return WishCreateResponse(slug=slug, public_url=public_url)


@router.get(
    "/wishes/{slug}",
    response_model=WishViewResponse,
    responses={
        404: {"model": ErrorResponse, "description": "Wish not found"},
        410: {"model": ErrorResponse, "description": "Wish expired or already viewed"},
    }
)
async def view_wish(slug: str, db: Session = Depends(get_db)):
    """View a wish by its slug.
    
    Returns the wish content and increments the view count.
    If the wish has expired (by time or views), it returns 410 Gone.
    If max_views is set, the wish is soft-deleted after viewing.
    """
    # Find wish
    wish = db.query(Wish).options(
        joinedload(Wish.images)
    ).filter(Wish.slug == slug).first()
    
    if not wish:
        logger.debug(f"Wish not found: {slug}")
        raise HTTPException(status_code=404, detail="Wish not found")
    
    # Check if soft-deleted
    if wish.is_deleted:
        logger.debug(f"Wish already deleted: {slug}")
        raise HTTPException(status_code=410, detail="Wish has expired or already been viewed")
    
    # Check expiry
    expiry_result = check_expiry(wish)
    if expiry_result.is_expired:
        # Soft delete the expired wish
        wish.soft_delete()
        db.commit()
        logger.info(f"Wish expired ({expiry_result.expiry_type.value}): {slug}")
        raise HTTPException(status_code=410, detail="Wish has expired or already been viewed")
    
    # Increment view count
    wish.current_views += 1
    
    # Check if should soft delete after this view
    if should_soft_delete(wish):
        wish.soft_delete()
        logger.info(f"Wish viewed and soft-deleted: {slug} (views={wish.current_views})")
    else:
        logger.info(f"Wish viewed: {slug} (views={wish.current_views})")
    
    db.commit()
    
    # Build response
    image_urls = [img.url for img in wish.images]
    remaining_views = wish.max_views - wish.current_views if wish.max_views else None
    
    return WishViewResponse(
        title=wish.title,
        message=wish.message,
        theme=wish.theme,
        images=image_urls,
        remaining_views=max(0, remaining_views) if remaining_views is not None else None
    )


@router.delete(
    "/wishes/{slug}",
    status_code=status.HTTP_204_NO_CONTENT,
    responses={
        404: {"model": ErrorResponse, "description": "Wish not found"},
    }
)
async def delete_wish(slug: str, db: Session = Depends(get_db)):
    """Soft delete a wish by its slug.
    
    This marks the wish as deleted. It will be permanently removed
    by the cleanup job after the grace period.
    """
    wish = db.query(Wish).filter(Wish.slug == slug).first()
    
    if not wish:
        raise HTTPException(status_code=404, detail="Wish not found")
    
    if wish.is_deleted:
        raise HTTPException(status_code=404, detail="Wish not found")
    
    wish.soft_delete()
    db.commit()
    
    logger.info(f"Wish manually deleted: {slug}")


@router.get("/wishes/{slug}/status")
async def get_wish_status(slug: str, db: Session = Depends(get_db)):
    """Get the status of a wish without incrementing views.
    
    Useful for checking if a wish exists and its status without
    affecting the view count.
    """
    wish = db.query(Wish).filter(Wish.slug == slug).first()
    
    if not wish:
        raise HTTPException(status_code=404, detail="Wish not found")
    
    if wish.is_deleted:
        return {
            "exists": True,
            "status": "deleted",
            "deleted_at": wish.deleted_at,
            "message": "Wish has expired or been deleted"
        }
    
    expiry_result = check_expiry(wish)
    
    return {
        "exists": True,
        "status": "expired" if expiry_result.is_expired else "active",
        "expiry_type": expiry_result.expiry_type.value if expiry_result.is_expired else None,
        "remaining_views": wish.remaining_views,
        "expires_at": wish.expires_at,
    }