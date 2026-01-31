"""API routes package for Wishaday application."""

from app.routes.wishes import router as wishes_router
from app.routes.uploads import router as uploads_router

__all__ = ["wishes_router", "uploads_router"]