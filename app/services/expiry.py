"""Expiry checking service for wishes."""

from datetime import datetime
from enum import Enum
from typing import Optional

from app.models import Wish


class ExpiryType(str, Enum):
    """Types of expiry."""
    TIME = "time"
    VIEWS = "views"
    NONE = "none"


class ExpiryResult:
    """Result of expiry checking."""
    
    def __init__(
        self, 
        is_expired: bool, 
        expiry_type: ExpiryType, 
        reason: Optional[str] = None
    ):
        self.is_expired = is_expired
        self.expiry_type = expiry_type
        self.reason = reason
    
    def __repr__(self) -> str:
        if self.is_expired:
            return f"ExpiryResult(expired=True, type={self.expiry_type}, reason={self.reason})"
        return "ExpiryResult(expired=False)"


def check_expiry(wish: Wish) -> ExpiryResult:
    """Check if a wish has expired.
    
    Args:
        wish: The wish to check
    
    Returns:
        ExpiryResult with expiration status
    """
    now = datetime.utcnow()
    
    # Check time-based expiry
    if wish.expires_at and now > wish.expires_at:
        return ExpiryResult(
            is_expired=True,
            expiry_type=ExpiryType.TIME,
            reason=f"Wish expired at {wish.expires_at}"
        )
    
    # Check view-based expiry
    if wish.max_views and wish.current_views >= wish.max_views:
        remaining = wish.max_views - wish.current_views
        return ExpiryResult(
            is_expired=True,
            expiry_type=ExpiryType.VIEWS,
            reason=f"Maximum views reached ({wish.current_views}/{wish.max_views})"
        )
    
    return ExpiryResult(is_expired=False, expiry_type=ExpiryType.NONE)


def should_soft_delete(wish: Wish) -> bool:
    """Check if a wish should be soft deleted after viewing.
    
    This is used to determine if a wish should be marked as deleted
    after being viewed (for 1-time views).
    
    Args:
        wish: The wish to check
    
    Returns:
        True if wish should be soft deleted
    """
    # If max_views is set and we've reached it, soft delete
    if wish.max_views and wish.current_views >= wish.max_views:
        return True
    
    # If time-based expiry is set and we've passed it, soft delete
    if wish.expires_at and datetime.utcnow() > wish.expires_at:
        return True
    
    return False


def get_remaining_views(wish: Wish) -> Optional[int]:
    """Get the remaining views for a wish.
    
    Args:
        wish: The wish to check
    
    Returns:
        Remaining views count, or None if no limit
    """
    if wish.max_views is None:
        return None
    return max(0, wish.max_views - wish.current_views)