"""Configuration settings for Wishaday application."""

import os
from pathlib import Path
from functools import lru_cache
from typing import Optional

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""
    
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )
    
    # Database
    DATABASE_URL: str = "sqlite:///./wishaday.db"
    
    # Upload Configuration
    UPLOAD_DIR: str = "./app/uploads"
    MAX_FILE_SIZE: int = 2097152  # 2MB in bytes
    MAX_IMAGES_PER_WISH: int = 5
    
    # Rate Limiting
    MAX_WISHES_PER_IP_PER_DAY: int = 10
    
    # Cleanup Configuration
    CLEANUP_INTERVAL_MINUTES: int = 30
    SOFT_DELETE_GRACE_PERIOD_MINUTES: int = 10
    
    # Server Configuration
    BASE_URL: str = "http://localhost:8000"
    DEBUG: bool = False
    PORT: int = 8000
    
    # Security
    SECRET_KEY: str = "change-me-in-production"
    
    @property
    def upload_path(self) -> Path:
        """Get the absolute upload directory path."""
        return Path(self.UPLOAD_DIR).resolve()
    
    @property
    def media_url(self) -> str:
        """Get the media URL prefix."""
        return f"{self.BASE_URL}/media"
    
    def get_wish_upload_path(self, wish_id: int) -> Path:
        """Get the upload path for a specific wish."""
        return self.upload_path / "wishes" / str(wish_id)


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()


# Global settings instance
settings = get_settings()