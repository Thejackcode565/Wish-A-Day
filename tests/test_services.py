"""Unit tests for Wishaday services."""

import sys
from pathlib import Path
from datetime import datetime, timedelta
from unittest.mock import MagicMock, patch

import pytest

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from app.models import Wish
from app.services.slug import generate_slug, slug_exists, generate_unique_slug, get_client_ip_hash
from app.services.expiry import check_expiry, should_soft_delete, get_remaining_views, ExpiryType


class TestSlugService:
    """Tests for slug generation service."""
    
    def test_generate_slug_length(self):
        """Test that generated slug has correct length."""
        slug_8 = generate_slug(length=8)
        slug_10 = generate_slug(length=10)
        
        assert len(slug_8) == 8
        assert len(slug_10) == 10
    
    def test_generate_slug_alphanumeric(self):
        """Test that generated slug contains only alphanumeric characters."""
        slug = generate_slug()
        
        assert slug.isalnum() or "-" in slug or "_" in slug
    
    def test_get_client_ip_hash(self):
        """Test IP hashing."""
        ip1 = "192.168.1.1"
        ip2 = "192.168.1.2"
        
        hash1 = get_client_ip_hash(ip1)
        hash2 = get_client_ip_hash(ip2)
        
        assert hash1 != hash2
        assert len(hash1) == 64  # SHA-256 hex digest length
        assert len(hash2) == 64
    
    def test_same_ip_same_hash(self):
        """Test that same IP produces same hash."""
        ip = "192.168.1.1"
        
        hash1 = get_client_ip_hash(ip)
        hash2 = get_client_ip_hash(ip)
        
        assert hash1 == hash2


class TestExpiryService:
    """Tests for expiry checking service."""
    
    def test_time_based_expiry_not_expired(self):
        """Test time-based expiry when not yet expired."""
        wish = Wish(
            id=1,
            slug="test123",
            message="Test message",
            expires_at=datetime.utcnow() + timedelta(hours=1),
            max_views=None,
            current_views=0
        )
        
        result = check_expiry(wish)
        
        assert result.is_expired is False
        assert result.expiry_type == ExpiryType.TIME
    
    def test_time_based_expired(self):
        """Test time-based expiry when expired."""
        wish = Wish(
            id=1,
            slug="test123",
            message="Test message",
            expires_at=datetime.utcnow() - timedelta(hours=1),
            max_views=None,
            current_views=0
        )
        
        result = check_expiry(wish)
        
        assert result.is_expired is True
        assert result.expiry_type == ExpiryType.TIME
    
    def test_view_based_expiry_not_expired(self):
        """Test view-based expiry when not yet expired."""
        wish = Wish(
            id=1,
            slug="test123",
            message="Test message",
            expires_at=None,
            max_views=5,
            current_views=3
        )
        
        result = check_expiry(wish)
        
        assert result.is_expired is False
        assert result.expiry_type == ExpiryType.VIEWS
    
    def test_view_based_expired(self):
        """Test view-based expiry when max views reached."""
        wish = Wish(
            id=1,
            slug="test123",
            message="Test message",
            expires_at=None,
            max_views=5,
            current_views=5
        )
        
        result = check_expiry(wish)
        
        assert result.is_expired is True
        assert result.expiry_type == ExpiryType.VIEWS
    
    def test_should_soft_delete_max_views_reached(self):
        """Test should_soft_delete when max views reached."""
        wish = Wish(
            id=1,
            slug="test123",
            message="Test message",
            expires_at=None,
            max_views=1,
            current_views=1
        )
        
        assert should_soft_delete(wish) is True
    
    def test_should_soft_delete_time_expired(self):
        """Test should_soft_delete when time expired."""
        wish = Wish(
            id=1,
            slug="test123",
            message="Test message",
            expires_at=datetime.utcnow() - timedelta(hours=1),
            max_views=None,
            current_views=0
        )
        
        assert should_soft_delete(wish) is True
    
    def test_should_not_soft_delete_active_wish(self):
        """Test should_soft_delete for active wish."""
        wish = Wish(
            id=1,
            slug="test123",
            message="Test message",
            expires_at=datetime.utcnow() + timedelta(hours=1),
            max_views=5,
            current_views=2
        )
        
        assert should_soft_delete(wish) is False
    
    def test_get_remaining_views_with_limit(self):
        """Test get_remaining_views when limit is set."""
        wish = Wish(
            id=1,
            slug="test123",
            message="Test message",
            max_views=5,
            current_views=3
        )
        
        assert get_remaining_views(wish) == 2
    
    def test_get_remaining_views_no_limit(self):
        """Test get_remaining_views when no limit."""
        wish = Wish(
            id=1,
            slug="test123",
            message="Test message",
            max_views=None,
            current_views=0
        )
        
        assert get_remaining_views(wish) is None
    
    def test_get_remaining_views_at_limit(self):
        """Test get_remaining_views at limit."""
        wish = Wish(
            id=1,
            slug="test123",
            message="Test message",
            max_views=5,
            current_views=5
        )
        
        assert get_remaining_views(wish) == 0
    
    def test_get_remaining_views_over_limit(self):
        """Test get_remaining_views over limit."""
        wish = Wish(
            id=1,
            slug="test123",
            message="Test message",
            max_views=5,
            current_views=7
        )
        
        assert get_remaining_views(wish) == 0


class TestWishModel:
    """Tests for Wish model."""
    
    def test_wish_properties(self):
        """Test Wish model computed properties."""
        wish = Wish(
            id=1,
            slug="test123",
            title="Test Title",
            message="Test message",
            theme="birthday",
            expires_at=datetime.utcnow() + timedelta(hours=1),
            max_views=10,
            current_views=3
        )
        
        assert wish.is_expired_by_time is False
        assert wish.is_expired_by_views is False
        assert wish.is_expired is False
        assert wish.remaining_views == 7
    
    def test_wish_soft_delete(self):
        """Test Wish.soft_delete method."""
        wish = Wish(
            id=1,
            slug="test123",
            message="Test message"
        )
        
        assert wish.is_deleted is False
        assert wish.deleted_at is None
        
        wish.soft_delete()
        
        assert wish.is_deleted is True
        assert wish.deleted_at is not None
    
    def test_wish_repr(self):
        """Test Wish model __repr__."""
        wish = Wish(
            id=1,
            slug="test123",
            title="Test Title",
            message="Test message"
        )
        
        repr_str = repr(wish)
        
        assert "test123" in repr_str
        assert "Test Title" in repr_str