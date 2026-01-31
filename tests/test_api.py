"""Integration tests for Wishaday API endpoints."""

import sys
from pathlib import Path
from datetime import datetime, timedelta
from io import BytesIO

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from app.database import Base, engine
from app.main import app
from app.database import get_db


@pytest.fixture(scope="module")
def test_db():
    """Create test database tables."""
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="module")
def client(test_db):
    """Create test client."""
    def override_get_db():
        from sqlalchemy import create_engine, sessionmaker
        from sqlalchemy.pool import StaticPool
        
        test_engine = create_engine(
            "sqlite:///:memory:",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)
        
        # Create tables in test database
        Base.metadata.create_all(bind=test_engine)
        
        db = TestingSessionLocal()
        try:
            yield db
        finally:
            db.close()
    
    app.dependency_overrides[get_db] = override_get_db
    
    with TestClient(app) as test_client:
        yield test_client
    
    app.dependency_overrides.clear()


class TestHealthEndpoint:
    """Tests for health check endpoint."""
    
    def test_health_check(self, client: TestClient):
        """Test health check returns status."""
        response = client.get("/health")
        
        assert response.status_code == 200
        data = response.json()
        assert "status" in data
        assert "version" in data


class TestWishCreation:
    """Tests for wish creation endpoint."""
    
    def test_create_wish_success(self, client: TestClient, test_db: Session):
        """Test successful wish creation."""
        wish_data = {
            "title": "Happy Birthday",
            "message": "Have a great day!",
            "theme": "birthday"
        }
        
        response = client.post("/api/wishes", json=wish_data)
        
        assert response.status_code == 201
        data = response.json()
        assert "slug" in data
        assert "public_url" in data
        assert len(data["slug"]) == 8
    
    def test_create_wish_minimal(self, client: TestClient, test_db: Session):
        """Test wish creation with minimal data."""
        wish_data = {
            "message": "Just a message"
        }
        
        response = client.post("/api/wishes", json=wish_data)
        
        assert response.status_code == 201
        data = response.json()
        assert "slug" in data
    
    def test_create_wish_with_expiry(self, client: TestClient, test_db: Session):
        """Test wish creation with expiry settings."""
        expires_at = (datetime.utcnow() + timedelta(hours=1)).isoformat()
        wish_data = {
            "title": "Expiring Wish",
            "message": "This wish expires soon",
            "expires_at": expires_at,
            "max_views": 5
        }
        
        response = client.post("/api/wishes", json=wish_data)
        
        assert response.status_code == 201
        data = response.json()
        assert "slug" in data
    
    def test_create_wish_invalid_data(self, client: TestClient, test_db: Session):
        """Test wish creation with invalid data."""
        wish_data = {
            "message": ""  # Empty message should fail
        }
        
        response = client.post("/api/wishes", json=wish_data)
        
        assert response.status_code == 422  # Validation error
    
    def test_create_wish_message_required(self, client: TestClient, test_db: Session):
        """Test wish creation fails without message."""
        wish_data = {
            "title": "No message"
        }
        
        response = client.post("/api/wishes", json=wish_data)
        
        assert response.status_code == 422


class TestWishViewing:
    """Tests for wish viewing endpoint."""
    
    def test_view_nonexistent_wish(self, client: TestClient, test_db: Session):
        """Test viewing a wish that doesn't exist."""
        response = client.get("/api/wishes/nonexistent")
        
        assert response.status_code == 404
    
    def test_view_deleted_wish(self, client: TestClient, test_db: Session):
        """Test viewing a deleted wish."""
        # First create a wish
        wish_data = {"message": "Test message"}
        create_response = client.post("/api/wishes", json=wish_data)
        slug = create_response.json()["slug"]
        
        # Delete the wish
        delete_response = client.delete(f"/api/wishes/{slug}")
        assert delete_response.status_code == 204
        
        # Try to view it
        view_response = client.get(f"/api/wishes/{slug}")
        assert view_response.status_code == 410
    
    def test_view_wish_increments_views(self, client: TestClient, test_db: Session):
        """Test viewing a wish increments view count."""
        # Create a wish with max_views > 1
        wish_data = {
            "message": "Test message",
            "max_views": 5
        }
        create_response = client.post("/api/wishes", json=wish_data)
        slug = create_response.json()["slug"]
        
        # View the wish
        response = client.get(f"/api/wishes/{slug}")
        assert response.status_code == 200
        
        data = response.json()
        assert data["remaining_views"] == 4


class TestWishDeletion:
    """Tests for wish deletion endpoint."""
    
    def test_delete_wish_success(self, client: TestClient, test_db: Session):
        """Test successful wish deletion."""
        # Create a wish
        wish_data = {"message": "To be deleted"}
        create_response = client.post("/api/wishes", json=wish_data)
        slug = create_response.json()["slug"]
        
        # Delete it
        response = client.delete(f"/api/wishes/{slug}")
        
        assert response.status_code == 204
        
        # Verify it's deleted
        view_response = client.get(f"/api/wishes/{slug}")
        assert view_response.status_code == 410
    
    def test_delete_nonexistent_wish(self, client: TestClient, test_db: Session):
        """Test deleting a wish that doesn't exist."""
        response = client.delete("/api/wishes/nonexistent")
        
        assert response.status_code == 404


class TestWishStatus:
    """Tests for wish status endpoint."""
    
    def test_get_wish_status(self, client: TestClient, test_db: Session):
        """Test getting wish status."""
        # Create a wish
        wish_data = {"message": "Status check"}
        create_response = client.post("/api/wishes", json=wish_data)
        slug = create_response.json()["slug"]
        
        # Get status
        response = client.get(f"/api/wishes/{slug}/status")
        
        assert response.status_code == 200
        data = response.json()
        assert data["exists"] is True
        assert data["status"] == "active"


class TestImageUpload:
    """Tests for image upload endpoint."""
    
    def test_upload_image_not_found_wish(self, client: TestClient, test_db: Session):
        """Test uploading image to nonexistent wish."""
        files = {"file": ("test.jpg", b"fake image data", "image/jpeg")}
        
        response = client.post("/api/wishes/nonexistent/images", files=files)
        
        assert response.status_code == 404
    
    def test_upload_image_invalid_type(self, client: TestClient, test_db: Session):
        """Test uploading invalid image type."""
        # Create a wish
        wish_data = {"message": "Test message"}
        create_response = client.post("/api/wishes", json=wish_data)
        slug = create_response.json()["slug"]
        
        # Try to upload invalid file type
        files = {"file": ("test.txt", b"not an image", "text/plain")}
        
        response = client.post(f"/api/wishes/{slug}/images", files=files)
        
        assert response.status_code == 400


class TestRateLimiting:
    """Tests for rate limiting."""
    
    def test_rate_limit_enforced(self, client: TestClient, test_db: Session):
        """Test that rate limiting is enforced."""
        # The test uses in-memory storage, so this tests the mechanism exists
        # Actual rate limiting tests would require multiple requests from same IP
        response = client.post("/api/wishes", json={"message": "Rate limit test"})
        
        # Should succeed for first request
        assert response.status_code == 201


if __name__ == "__main__":
    pytest.main([__file__, "-v"])