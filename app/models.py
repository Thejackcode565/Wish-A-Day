"""SQLAlchemy ORM models for Wishaday application."""

from datetime import datetime
from typing import List, Optional

from sqlalchemy import Column, Integer, String, Text, DateTime, Boolean, ForeignKey, func
from sqlalchemy.orm import relationship, Mapped, mapped_column

from app.database import Base


class Wish(Base):
    """Model representing a wish."""
    
    __tablename__ = "wishes"
    
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    slug: Mapped[str] = mapped_column(String(10), unique=True, nullable=False, index=True)
    title: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    message: Mapped[str] = mapped_column(Text, nullable=False)
    theme: Mapped[str] = mapped_column(String(50), default="default")
    expires_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    max_views: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    current_views: Mapped[int] = mapped_column(Integer, default=0)
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), 
        server_default=func.now(),
        default=datetime.utcnow
    )
    deleted_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    ip_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    
    # Relationship to images
    images: Mapped[List["WishImage"]] = relationship(
        "WishImage", 
        back_populates="wish", 
        cascade="all, delete-orphan",
        lazy="selectin"
    )
    
    def __repr__(self) -> str:
        return f"<Wish(id={self.id}, slug='{self.slug}', title='{self.title}')>"
    
    @property
    def is_expired_by_time(self) -> bool:
        """Check if wish has expired by time."""
        if self.expires_at is None:
            return False
        return datetime.utcnow() > self.expires_at
    
    @property
    def is_expired_by_views(self) -> bool:
        """Check if wish has expired by views."""
        if self.max_views is None:
            return False
        return self.current_views >= self.max_views
    
    @property
    def remaining_views(self) -> Optional[int]:
        """Get remaining views if view limit is set."""
        if self.max_views is None:
            return None
        return max(0, self.max_views - self.current_views)
    
    @property
    def is_expired(self) -> bool:
        """Check if wish has expired by any means."""
        return self.is_expired_by_time or self.is_expired_by_views
    
    def soft_delete(self) -> None:
        """Mark wish as soft deleted."""
        self.is_deleted = True
        self.deleted_at = datetime.utcnow()


class WishImage(Base):
    """Model representing an image attached to a wish."""
    
    __tablename__ = "wish_images"
    
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    wish_id: Mapped[int] = mapped_column(
        Integer, 
        ForeignKey("wishes.id", ondelete="CASCADE"),
        nullable=False
    )
    path: Mapped[str] = mapped_column(String(500), nullable=False)  # Relative path
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), 
        server_default=func.now(),
        default=datetime.utcnow
    )
    
    # Relationship back to wish
    wish: Mapped["Wish"] = relationship("Wish", back_populates="images")
    
    def __repr__(self) -> str:
        return f"<WishImage(id={self.id}, wish_id={self.wish_id}, path='{self.path}')>"
    
    @property
    def absolute_path(self) -> str:
        """Get the absolute file path."""
        from app.config import settings
        return str(settings.upload_path / self.path)
    
    @property
    def url(self) -> str:
        """Get the public URL for this image."""
        from app.config import settings
        return f"{settings.BASE_URL}/media/{self.path}"