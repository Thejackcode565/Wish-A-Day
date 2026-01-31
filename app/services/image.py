"""Image processing service using Pillow."""

import os
import uuid
from io import BytesIO
from pathlib import Path
from typing import Optional, Tuple

from fastapi import UploadFile
from PIL import Image

from app.config import settings


# Allowed image content types
ALLOWED_CONTENT_TYPES = {
    "image/jpeg",
    "image/png", 
    "image/gif",
    "image/webp",
}

# Allowed file extensions
ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".webp"}


def validate_image(file: UploadFile) -> Tuple[bool, str]:
    """Validate an uploaded image file.
    
    Args:
        file: FastAPI UploadFile object
    
    Returns:
        Tuple of (is_valid, error_message)
    """
    # Check content type
    if file.content_type not in ALLOWED_CONTENT_TYPES:
        return False, f"Invalid content type: {file.content_type}. Allowed: {', '.join(ALLOWED_CONTENT_TYPES)}"
    
    # Check file extension
    filename = file.filename or ""
    ext = Path(filename).suffix.lower()
    if ext not in ALLOWED_EXTENSIONS:
        return False, f"Invalid file extension: {ext}. Allowed: {', '.join(ALLOWED_EXTENSIONS)}"
    
    # Check file size
    file_size = 0
    content = file.file.read(1024)
    file_size += len(content)
    while content:
        if file_size > settings.MAX_FILE_SIZE:
            file.file.seek(0)
            return False, f"File too large: maximum size is {settings.MAX_FILE_SIZE // 1024 // 1024}MB"
        content = file.file.read(1024)
        file_size += len(content)
    
    # Reset file position
    file.file.seek(0)
    return True, ""


def process_image(file: UploadFile, wish_id: int) -> str:
    """Process an uploaded image and save as WEBP.
    
    Args:
        file: FastAPI UploadFile object
        wish_id: ID of the wish this image belongs to
    
    Returns:
        Relative path to the saved image
    
    Raises:
        ValueError: If image processing fails
    """
    # Read image
    image_data = file.file.read()
    file.file.seek(0)
    
    # Open with Pillow
    try:
        img = Image.open(BytesIO(image_data))
    except Exception as e:
        raise ValueError(f"Failed to open image: {e}")
    
    # Convert to RGB if necessary (WEBP doesn't support RGBA in all cases)
    if img.mode in ("RGBA", "P"):
        img = img.convert("RGB")
    
    # Create upload directory
    upload_dir = settings.get_wish_upload_path(wish_id)
    upload_dir.mkdir(parents=True, exist_ok=True)
    
    # Generate unique filename
    original_filename = file.filename or "image"
    name_stem = Path(original_filename).stem
    safe_name = "".join(c if c.isalnum() or c in "-_" else "_" for c in name_stem)
    unique_id = uuid.uuid4().hex[:8]
    filename = f"{safe_name}_{unique_id}.webp"
    
    # Save as WEBP
    output_path = upload_dir / filename
    try:
        img.save(
            output_path,
            format="WEBP",
            quality=85,
            method=6  # Slower but better compression
        )
    except Exception as e:
        raise ValueError(f"Failed to save image: {e}")
    
    # Return relative path
    relative_path = f"wishes/{wish_id}/{filename}"
    return relative_path


def delete_image(path: str) -> bool:
    """Delete an image file.
    
    Args:
        path: Relative path to the image
    
    Returns:
        True if deleted successfully, False otherwise
    """
    try:
        full_path = settings.upload_path / path
        if full_path.exists():
            full_path.unlink()
            return True
        return False
    except Exception:
        return False


def get_image_path(path: str) -> Optional[Path]:
    """Get the full path for an image.
    
    Args:
        path: Relative path to the image
    
    Returns:
        Full Path object or None if path is invalid
    """
    full_path = settings.upload_path / path
    if full_path.exists() and full_path.is_file():
        return full_path
    return None