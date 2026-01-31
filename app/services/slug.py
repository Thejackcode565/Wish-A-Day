"""Slug generation service using nanoid."""

import hashlib
from typing import Optional

from nanoid import generate

from app.database import SessionLocal
from app.models import Wish


def generate_slug(length: int = 8) -> str:
    """Generate a random slug of specified length.
    
    Uses nanoid with the default alphabet (a-z, A-Z, 0-9, -_).
    The effective alphabet size is 64 characters.
    
    Args:
        length: Length of the slug (default 8)
    
    Returns:
        A random slug string
    """
    return generate(size=length)


def slug_exists(db: SessionLocal, slug: str) -> bool:
    """Check if a slug already exists in the database.
    
    Args:
        db: Database session
        slug: Slug to check
    
    Returns:
        True if slug exists, False otherwise
    """
    return db.query(Wish).filter(Wish.slug == slug).first() is not None


def generate_unique_slug(db: SessionLocal, max_attempts: int = 3) -> str:
    """Generate a unique slug that doesn't exist in the database.
    
    Args:
        db: Database session
        max_attempts: Maximum attempts to generate unique slug
    
    Returns:
        A unique slug string
    
    Raises:
        RuntimeError: If unable to generate unique slug after max attempts
    """
    for attempt in range(max_attempts):
        slug = generate_slug(length=8)
        if not slug_exists(db, slug):
            return slug
        # If first attempt fails, try longer slug
        if attempt == 0:
            slug = generate_slug(length=10)
            if not slug_exists(db, slug):
                return slug
    
    raise RuntimeError("Unable to generate unique slug after maximum attempts")


def get_client_ip_hash(client_ip: str) -> str:
    """Get a hash of the client IP for rate limiting.
    
    Args:
        client_ip: Client IP address
    
    Returns:
        Hashed IP string
    """
    return hashlib.sha256(client_ip.encode()).hexdigest()