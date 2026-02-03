"""Pydantic schemas for request/response validation."""

from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field, ConfigDict, model_validator


class WishCreate(BaseModel):
    """Schema for creating a new wish."""
    
    title: Optional[str] = Field(None, max_length=255)
    message: str = Field(..., min_length=1, max_length=5000)
    theme: str = Field(default="default", max_length=50)
    expires_at: Optional[datetime] = None
    max_views: Optional[int] = Field(None, ge=1, le=1000)
    
    @model_validator(mode='after')
    def validate_expiry(self):
        """Ensure either expires_at or max_views is provided."""
        if self.expires_at is None and self.max_views is None:
            raise ValueError("Either expires_at or max_views must be provided")
        return self
    
    model_config = ConfigDict(json_schema_extra={
        "example": {
            "title": "Happy Birthday",
            "message": "Have a great day!",
            "theme": "birthday",
            "expires_at": "2026-02-05T10:00:00Z",
            "max_views": 1
        }
    })


class WishCreateResponse(BaseModel):
    """Schema for wish creation response."""
    
    slug: str
    public_url: str
    
    model_config = ConfigDict(json_schema_extra={
        "example": {
            "slug": "8Fk2QaL9",
            "public_url": "https://wishaday.hareeshworks.in/w/8Fk2QaL9"
        }
    })


class WishImageResponse(BaseModel):
    """Schema for image upload response."""
    
    url: str
    
    model_config = ConfigDict(json_schema_extra={
        "example": {
            "url": "/media/wishes/123/image.webp"
        }
    })


class WishViewResponse(BaseModel):
    """Schema for viewing a wish."""
    
    title: Optional[str]
    message: str
    theme: str
    images: List[str]
    remaining_views: Optional[int]
    
    model_config = ConfigDict(json_schema_extra={
        "example": {
            "title": "Happy Birthday",
            "message": "Have a great day!",
            "theme": "birthday",
            "images": ["/media/wishes/123/image1.webp", "/media/wishes/123/image2.webp"],
            "remaining_views": 0
        }
    })


class ErrorResponse(BaseModel):
    """Schema for error responses."""
    
    detail: str
    
    model_config = ConfigDict(json_schema_extra={
        "example": {
            "detail": "Wish not found"
        }
    })


class RateLimitResponse(BaseModel):
    """Schema for rate limit responses."""
    
    detail: str = "Rate limit exceeded. Try again later."
    
    model_config = ConfigDict(json_schema_extra={
        "example": {
            "detail": "Rate limit exceeded. Maximum 10 wishes per day per IP."
        }
    })


class HealthResponse(BaseModel):
    """Schema for health check response."""
    
    status: str = "healthy"
    version: str