"""Cleanup service for soft-deleted wishes."""

import logging
import shutil
from datetime import datetime, timedelta
from pathlib import Path
from typing import List, Tuple

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.models import Wish, WishImage

logger = logging.getLogger(__name__)


def cleanup_expired_wishes(db: Session) -> Tuple[int, int, int]:
    """Clean up expired wishes and their images.
    
    Deletes wishes that have been soft-deleted for longer than the
    grace period, along with their associated image files.
    
    Args:
        db: Database session
    
    Returns:
        Tuple of (wishes_deleted, images_deleted, errors_count)
    """
    grace_period = timedelta(minutes=settings.SOFT_DELETE_GRACE_PERIOD_MINUTES)
    cutoff_time = datetime.utcnow() - grace_period
    
    # Find wishes to delete
    result = db.execute(
        select(Wish).where(
            Wish.is_deleted == True,
            Wish.deleted_at != None,
            Wish.deleted_at < cutoff_time
        )
    )
    wishes_to_delete = result.scalars().all()
    
    wishes_deleted = 0
    images_deleted = 0
    errors_count = 0
    
    for wish in wishes_to_delete:
        try:
            # Delete image files
            wish_upload_path = settings.get_wish_upload_path(wish.id)
            if wish_upload_path.exists():
                try:
                    shutil.rmtree(wish_upload_path)
                    logger.info(f"Deleted image directory: {wish_upload_path}")
                except Exception as e:
                    logger.error(f"Failed to delete image directory {wish_upload_path}: {e}")
                    errors_count += 1
            
            # Delete from database (cascades to images)
            db.delete(wish)
            wishes_deleted += 1
            images_deleted += len(wish.images)
            logger.info(f"Deleted wish: {wish.slug} (id={wish.id})")
            
        except Exception as e:
            logger.error(f"Failed to delete wish {wish.id}: {e}")
            errors_count += 1
    
    db.commit()
    return wishes_deleted, images_deleted, errors_count


def cleanup_orphaned_images(db: Session) -> int:
    """Clean up orphaned image files that have no database record.
    
    Args:
        db: Database session
    
    Returns:
        Number of orphaned images deleted
    """
    # Get all image records
    result = db.execute(select(WishImage))
    all_images = result.scalars().all()
    
    # Get all existing image paths from database
    existing_paths = {img.path for img in all_images}
    
    # Check for orphaned files
    upload_path = settings.upload_path
    orphaned_count = 0
    
    for image_path in existing_paths:
        full_path = upload_path / image_path
        if not full_path.exists():
            # Find and delete the orphaned record
            img_record = db.query(WishImage).filter(WishImage.path == image_path).first()
            if img_record:
                db.delete(img_record)
                orphaned_count += 1
                logger.info(f"Deleted orphaned image record: {image_path}")
    
    db.commit()
    return orphaned_count


def check_disk_space() -> bool:
    """Check if there's enough disk space for uploads.
    
    Returns:
        True if there's at least 1GB free, False otherwise
    """
    try:
        upload_path = settings.upload_path
        if not upload_path.exists():
            upload_path.mkdir(parents=True, exist_ok=True)
        
        # Get free space in bytes
        stat = upload_path.stat()
        free_bytes = shutil.disk_usage(upload_path.parent).free
        
        # Check if at least 1GB free
        min_free_bytes = 1024 * 1024 * 1024  # 1GB
        return free_bytes >= min_free_bytes
        
    except Exception as e:
        logger.error(f"Failed to check disk space: {e}")
        return True  # Allow operation if check fails


def get_cleanup_summary(db: Session) -> dict:
    """Get a summary of items eligible for cleanup.
    
    Args:
        db: Database session
    
    Returns:
        Dictionary with cleanup statistics
    """
    grace_period = timedelta(minutes=settings.SOFT_DELETE_GRACE_PERIOD_MINUTES)
    cutoff_time = datetime.utcnow() - grace_period
    
    # Count soft-deleted wishes
    result = db.execute(
        select(Wish).where(
            Wish.is_deleted == True,
            Wish.deleted_at != None,
            Wish.deleted_at < cutoff_time
        )
    )
    expired_count = len(result.scalars().all())
    
    # Count soft-deleted wishes still in grace period
    result = db.execute(
        select(Wish).where(
            Wish.is_deleted == True,
            Wish.deleted_at != None,
            Wish.deleted_at >= cutoff_time
        )
    )
    grace_period_count = len(result.scalars().all())
    
    # Count total wishes
    total_wishes = db.query(Wish).count()
    total_images = db.query(WishImage).count()
    
    return {
        "expired_wishes_ready_for_deletion": expired_count,
        "wishes_in_grace_period": grace_period_count,
        "total_wishes": total_wishes,
        "total_images": total_images,
        "grace_period_minutes": settings.SOFT_DELETE_GRACE_PERIOD_MINUTES,
        "cleanup_interval_minutes": settings.CLEANUP_INTERVAL_MINUTES,
    }