"""Main FastAPI application for Wishaday."""

import logging
import sys
from contextlib import asynccontextmanager
from pathlib import Path

from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.interval import IntervalTrigger
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

from app import __version__
from app.config import settings
from app.database import init_db, SessionLocal
from app.routes import wishes_router, uploads_router
from app.services.cleanup import cleanup_expired_wishes
from app.services.cleanup import get_cleanup_summary

# Configure logging
logging.basicConfig(
    level=logging.DEBUG if settings.DEBUG else logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger(__name__)

# Global scheduler instance
scheduler: BackgroundScheduler | None = None


def run_cleanup_job():
    """Wrapper function to run cleanup with its own database session."""
    db = SessionLocal()
    try:
        cleanup_expired_wishes(db)
    finally:
        db.close()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler for startup and shutdown events."""
    global scheduler
    
    # Startup
    logger.info("Starting Wishaday application...")
    
    # Initialize database
    init_db()
    logger.info("Database initialized")
    
    # Ensure upload directory exists
    upload_path = settings.upload_path
    upload_path.mkdir(parents=True, exist_ok=True)
    (upload_path / "wishes").mkdir(exist_ok=True)
    logger.info(f"Upload directory: {upload_path}")
    
    # Start cleanup scheduler
    if settings.CLEANUP_INTERVAL_MINUTES > 0:
        scheduler = BackgroundScheduler()
        scheduler.add_job(
            run_cleanup_job,
            trigger=IntervalTrigger(minutes=settings.CLEANUP_INTERVAL_MINUTES),
            id="cleanup_job",
            name="Clean up expired wishes",
            replace_existing=True,
            max_instances=1,
        )
        scheduler.start()
        logger.info(
            f"Cleanup scheduler started (interval: {settings.CLEANUP_INTERVAL_MINUTES} minutes)"
        )
    
    logger.info(f"Wishaday v{__version__} started successfully")
    logger.info(f"Base URL: {settings.BASE_URL}")
    
    yield
    
    # Shutdown
    logger.info("Shutting down Wishaday application...")
    
    if scheduler and scheduler.running:
        scheduler.shutdown(wait=False)
        logger.info("Cleanup scheduler stopped")
    
    logger.info("Wishaday shutdown complete")


# Create FastAPI application
app = FastAPI(
    title="Wishaday API",
    description="A wish sharing platform with self-destructing wishes",
    version=__version__,
    lifespan=lifespan,
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    openapi_url="/api/openapi.json",
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:8080",
        "http://127.0.0.1:8080",
    ],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static files for media
media_path = settings.upload_path
if media_path.exists():
    app.mount(
        "/media",
        StaticFiles(directory=str(media_path)),
        name="media"
    )


# Include routers
app.include_router(wishes_router)
app.include_router(uploads_router)


# Public wish viewing page (frontend can use this)
@app.get("/w/{slug}")
async def public_wish_page(slug: str, request: Request):
    """Redirect to the wish viewing page or return wish data as JSON."""
    # Check if Accept header prefers HTML
    accept = request.headers.get("Accept", "")
    if "text/html" in accept:
        # Return a simple HTML page with the wish data
        from app.database import SessionLocal
        from app.models import Wish
        from app.services.expiry import check_expiry
        
        db = SessionLocal()
        try:
            wish = db.query(Wish).filter(Wish.slug == slug).first()
            
            if not wish or wish.is_deleted:
                return FileResponse("app/static/404.html")
            
            expiry_result = check_expiry(wish)
            if expiry_result.is_expired:
                return FileResponse("app/static/expired.html")
            
            # Simple HTML response
            html_content = f"""
            <!DOCTYPE html>
            <html>
            <head>
                <title>Wish: {wish.title or 'Untitled'}</title>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <style>
                    body {{ font-family: system-ui, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; }}
                    .wish {{ background: #f5f5f5; padding: 20px; border-radius: 8px; }}
                    .message {{ font-size: 1.2em; margin: 20px 0; }}
                    .meta {{ color: #666; font-size: 0.9em; }}
                    .images {{ display: flex; gap: 10px; flex-wrap: wrap; margin-top: 20px; }}
                    .images img {{ max-width: 200px; border-radius: 4px; }}
                </style>
            </head>
            <body>
                <div class="wish">
                    <h1>{wish.title or 'Untitled Wish'}</h1>
                    <p class="message">{wish.message}</p>
                    <p class="meta">Theme: {wish.theme}</p>
                    <div class="images">
                        {"".join(f'<img src="/media/{img.path}" alt="Wish image">' for img in wish.images)}
                    </div>
                </div>
            </body>
            </html>
            """
            return HTMLResponse(content=html_content)
        finally:
            db.close()
    
    # Return JSON response
    from app.routes.wishes import view_wish
    return await view_wish(slug)


# Create static directory and placeholder pages
static_dir = Path("app/static")
static_dir.mkdir(parents=True, exist_ok=True)


from fastapi.responses import HTMLResponse


@app.get("/static/404.html")
async def custom_404():
    """Custom 404 page."""
    return HTMLResponse(content="""
    <!DOCTYPE html>
    <html>
    <head><title>404 - Wish Not Found</title></head>
    <body>
        <h1>Wish Not Found</h1>
        <p>This wish does not exist or has been deleted.</p>
    </body>
    </html>
    """)


@app.get("/static/expired.html")
async def expired_page():
    """Expired wish page."""
    return HTMLResponse(content="""
    <!DOCTYPE html>
    <html>
    <head><title>Wish Expired</title></head>
    <body>
        <h1>This wish has expired</h1>
        <p>The wish you are looking for has expired or has already been viewed.</p>
    </body>
    </html>
    """)


# Health check endpoint
@app.get("/health", tags=["health"])
async def health_check():
    """Health check endpoint."""
    from sqlalchemy import text
    from app.database import SessionLocal
    
    db = SessionLocal()
    db_status = "healthy"
    cleanup_summary = {}
    
    try:
        # Check database connection
        db.execute(text("SELECT 1"))
        # Get cleanup summary
        cleanup_summary = get_cleanup_summary(db)
    except Exception as e:
        db_status = f"unhealthy: {e}"
    finally:
        db.close()
    
    return {
        "status": "healthy" if db_status == "healthy" else "degraded",
        "version": __version__,
        "database": db_status,
        "cleanup": cleanup_summary,
    }


# Admin cleanup endpoint (should be protected in production)
@app.post("/admin/cleanup", tags=["admin"])
async def manual_cleanup():
    """Manually trigger cleanup of expired wishes."""
    from app.database import SessionLocal
    
    db = SessionLocal()
    try:
        wishes, images, errors = cleanup_expired_wishes(db)
        return {
            "status": "completed",
            "wishes_deleted": wishes,
            "images_deleted": images,
            "errors": errors,
        }
    finally:
        db.close()


@app.get("/admin/status", tags=["admin"])
async def admin_status():
    """Get admin status including cleanup summary."""
    from app.database import SessionLocal
    
    db = SessionLocal()
    try:
        cleanup_summary = get_cleanup_summary(db)
        return {
            "version": __version__,
            "settings": {
                "cleanup_interval_minutes": settings.CLEANUP_INTERVAL_MINUTES,
                "grace_period_minutes": settings.SOFT_DELETE_GRACE_PERIOD_MINUTES,
            },
            "cleanup": cleanup_summary,
        }
    finally:
        db.close()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=settings.PORT,
        reload=settings.DEBUG,
    )