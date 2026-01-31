"""Test configuration and fixtures for Wishaday tests."""

import sys
from pathlib import Path
import tempfile
from typing import Generator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import StaticPool

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from app.database import Base, get_db
from app.main import app
from app.config import settings


# Create in-memory SQLite database for testing
SQLALCHEMY_TEST_DATABASE_URL = "sqlite:///:memory:"

engine = create_engine(
    SQLALCHEMY_TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)

TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(scope="function")
def test_db() -> Generator[Session, None, None]:
    """Create a fresh test database for each test."""
    # Create all tables
    Base.metadata.create_all(bind=engine)
    
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()
        # Drop all tables after test
        Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def client(test_db: Session) -> Generator[TestClient, None, None]:
    """Create a test client with test database override."""
    
    def override_get_db():
        try:
            yield test_db
        finally:
            pass
    
    app.dependency_overrides[get_db] = override_get_db
    
    with TestClient(app) as test_client:
        yield test_client
    
    app.dependency_overrides.clear()


@pytest.fixture
def sample_wish_data() -> dict:
    """Sample wish creation data."""
    return {
        "title": "Test Wish",
        "message": "This is a test wish message",
        "theme": "default",
        "max_views": 1,
    }


@pytest.fixture
def sample_wish_with_expiry() -> dict:
    """Sample wish creation data with expiry."""
    from datetime import datetime, timedelta
    
    return {
        "title": "Expiring Wish",
        "message": "This wish will expire soon",
        "theme": "birthday",
        "expires_at": (datetime.utcnow() + timedelta(hours=1)).isoformat(),
        "max_views": 5,
    }


@pytest.fixture
def temp_image_file():
    """Create a temporary image file for testing."""
    from PIL import Image
    import io
    
    # Create a simple test image
    img = Image.new("RGB", (100, 100), color="red")
    img_bytes = io.BytesIO()
    img.save(img_bytes, format="JPEG")
    img_bytes.seek(0)
    
    return img_bytes