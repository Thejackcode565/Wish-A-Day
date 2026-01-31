"""Image upload API routes."""

import logging
from typing import Annotated

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models import Wish, WishImage
from app.schemas import WishImageResponse, ErrorResponse
from app.services.image import validate_image, process_image

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["uploads"])


@router.post(
    "/wishes/{slug}/images",
    response_model=WishImageResponse,
    status_code=status.HTTP_201_CREATED,
    responses={
        400: {"model": ErrorResponse, "description": "Invalid image or too many images"},
        404: {"model": ErrorResponse, "description": "Wish not found"},
        410: {"model": ErrorResponse, "description": "Wish has expired"},
        413: {"model": ErrorResponse, "description": "File too large"},
        507: {"model": ErrorResponse, "description": "Insufficient storage"},
    }
)
async def upload_image(
    slug: str,
    file: Annotated[UploadFile, File(...)],
    db: Session = Depends(get_db)
):
    """Upload an image for a wish.
    
    Validates the image, converts it to WEBP format, and saves it.
    Maximum {} images per wish, maximum file size {}MB.
    """.format(settings.MAX_IMAGES_PER_WISH, settings.MAX_FILE_SIZE // 1024 // 1024)
    
    # Find the wish
    wish = db.query(Wish).filter(Wish.slug == slug).first()
    
    if not wish:
        logger.debug(f"Wish not found for image upload: {slug}")
        raise HTTPException(status_code=404, detail="Wish not found")
    
    # Check if wish is deleted or expired
    if wish.is_deleted:
        raise HTTPException(status_code=410, detail="Wish has expired or already been viewed")
    
    from app.services.expiry import check_expiry
    expiry_result = check_expiry(wish)
    if expiry_result.is_expired:
        raise HTTPException(status_code=410, detail="Wish has expired or already been viewed")
    
    # Check max images per wish
    image_count = db.query(WishImage).filter(WishImage.wish_id == wish.id).count()
    if image_count >= settings.MAX_IMAGES_PER_WISH:
        raise HTTPException(
            status_code=400, 
            detail=f"Maximum {settings.MAX_IMAGES_PER_WISH} images per wish"
        )
    
    # Validate image
    is_valid, error_msg = validate_image(file)
    if not is_valid:
        if "too large" in error_msg.lower():
            raise HTTPException(status_code=413, detail=error_msg)
        raise HTTPException(status_code=400, detail=error_msg)
    
    # Check disk space
    from app.services.cleanup import check_disk_space
    if not check_disk_space():
        raise HTTPException(status_code=507, detail="Insufficient storage space")
    
    # Process image
    try:
        relative_path = process_image(file, wish.id)
    except ValueError as e:
        logger.error(f"Failed to process image: {e}")
        raise HTTPException(status_code=400, detail=f"Failed to process image: {e}")
    
    # Create image record
    wish_image = WishImage(
        wish_id=wish.id,
        path=relative_path
    )
    db.add(wish_image)
    db.commit()
    db.refresh(wish_image)
    
    # Build response URL
    image_url = f"{settings.BASE_URL}/media/{relative_path}"
    
    logger.info(f"Uploaded image for wish {slug}: {relative_path}")
    
    return WishImageResponse(url=image_url)


@router.delete(
    "/wishes/{slug}/images/{image_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    responses={
        404: {"model": ErrorResponse, "description": "Image not found"},
    }
)
async def delete_image(
    slug: str,
    image_id: int,
    db: Session = Depends(get_db)
):
    """Delete an image from a wish."""
    # Find the wish
    wish = db.query(Wish).filter(Wish.slug == slug).first()
    
    if not wish:
        raise HTTPException(status_code=404, detail="Wish not found")
    
    # Find the image
    image = db.query(WishImage).filter(
        WishImage.id == image_id,
        WishImage.wish_id == wish.id
    ).first()
    
    if not image:
        raise HTTPException(status_code=404, detail="Image not found")
    
    # Delete the file
    from app.services.image import delete_image
    delete_image(image.path)
    
    # Delete the record
    db.delete(image)
    db.commit()
    
    logger.info(f"Deleted image {image_id} from wish {slug}")


@router.get(
    "/wishes/{slug}/images",
    response_model=list[WishImageResponse]
)
async def list_images(slug: str, db: Session = Depends(get_db)):
    """List all images for a wish."""
    # Find the wish
    wish = db.query(Wish).filter(Wish.slug == slug).first()
    
    if not wish:
        raise HTTPException(status_code=404, detail="Wish not found")
    
    # Get images
    images = db.query(WishImage).filter(WishImage.wish_id == wish.id).all()
    
    return [
        WishImageResponse(url=f"{settings.BASE_URL}/media/{img.path}")
        for img in images
    ]