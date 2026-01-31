# Wishaday MVP

A wish sharing platform with self-destructing wishes. Create wishes that automatically expire based on time or number of views, with optional image attachments.

## Features

- **Create Wishes**: Share wishes with custom messages and themes
- **Image Uploads**: Attach up to 5 images per wish (converted to WEBP)
- **Auto-Expire**: Wishes can expire based on:
  - Time-based expiry (set a specific date/time)
  - View-based expiry (1-time or N-times view)
- **Soft Delete**: Expired wishes are marked as deleted before hard cleanup
- **Background Cleanup**: Automatically removes expired wishes after grace period
- **Rate Limiting**: Max 10 wishes per IP per day
- **Public Sharing**: Shareable links like `https://wishaday.hareeshworks.in/w/{slug}`

## Tech Stack

- **Language**: Python 3.11+
- **Framework**: FastAPI
- **ORM**: SQLAlchemy
- **Database**: SQLite (dev), PostgreSQL (prod)
- **Image Processing**: Pillow
- **Scheduler**: APScheduler
- **Server**: Uvicorn

## Quick Start

### 1. Clone and Install

```bash
# Clone the repository
git clone <repository-url>
cd Wish-A-Day

# Create virtual environment
python -m venv venv
source venv/bin/activate  # Linux/Mac
# or
.\venv\Scripts\activate  # Windows

# Install dependencies
pip install -e ".[dev]"
```

### 2. Configure

```bash
# Copy environment template
cp .env.example .env

# Edit configuration (optional)
nano .env
```

### 3. Initialize Database

```bash
python scripts/init_db.py
```

### 4. Run Development Server

```bash
uvicorn app.main:app --reload --port 8000
```

The API will be available at `http://localhost:8000`

- **API Docs**: http://localhost:8000/api/docs
- **ReDoc**: http://localhost:8000/api/redoc

## API Endpoints

### Create Wish

**POST** `/api/wishes`

```json
{
  "title": "Happy Birthday",
  "message": "Have a great day!",
  "theme": "birthday",
  "expires_at": "2026-02-05T10:00:00Z",
  "max_views": 1
}
```

Response:
```json
{
  "slug": "8Fk2QaL9",
  "public_url": "https://wishaday.hareeshworks.in/w/8Fk2QaL9"
}
```

### Upload Image

**POST** `/api/wishes/{slug}/images`

- Content-Type: `multipart/form-data`
- Max file size: 2MB
- Max images per wish: 5

### View Wish

**GET** `/api/wishes/{slug}`

Response:
```json
{
  "title": "Happy Birthday",
  "message": "Have a great day!",
  "theme": "birthday",
  "images": ["/media/wishes/123/image.webp"],
  "remaining_views": 0
}
```

### Delete Wish

**DELETE** `/api/wishes/{slug}`

### Health Check

**GET** `/health`

## Project Structure

```
Wish-A-Day/
├── app/
│   ├── __init__.py
│   ├── main.py              # FastAPI application entry point
│   ├── config.py            # Configuration settings
│   ├── database.py          # Database connection and session management
│   ├── models.py            # SQLAlchemy ORM models
│   ├── schemas.py           # Pydantic schemas
│   ├── routes/
│   │   ├── __init__.py
│   │   ├── wishes.py        # Wish-related endpoints
│   │   └── uploads.py       # Image upload endpoints
│   ├── services/
│   │   ├── __init__.py
│   │   ├── slug.py          # Slug generation service
│   │   ├── image.py         # Image processing service
│   │   ├── expiry.py        # Expiry checking service
│   │   └── cleanup.py       # Cleanup job for deleted records
│   └── uploads/
│       └── wishes/          # Image storage directory
├── tests/
│   ├── __init__.py
│   ├── conftest.py          # Test configuration
│   ├── test_services.py     # Unit tests for services
│   └── test_api.py          # Integration tests for API
├── scripts/
│   └── init_db.py           # Database initialization script
├── pyproject.toml           # Project configuration
├── .env.example             # Environment template
└── README.md                # This file
```

## Configuration

The following environment variables can be configured:

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_URL` | `sqlite:///./wishaday.db` | Database connection URL |
| `UPLOAD_DIR` | `./app/uploads` | Image upload directory |
| `MAX_FILE_SIZE` | `2097152` | Max upload file size (bytes) |
| `MAX_IMAGES_PER_WISH` | `5` | Max images per wish |
| `MAX_WISHES_PER_IP_PER_DAY` | `10` | Rate limit per IP |
| `CLEANUP_INTERVAL_MINUTES` | `30` | Cleanup job frequency |
| `SOFT_DELETE_GRACE_PERIOD_MINUTES` | `10` | Time before hard delete |
| `BASE_URL` | `http://localhost:8000` | Public base URL |
| `DEBUG` | `false` | Enable debug mode |
| `PORT` | `8000` | Server port |

## Testing

```bash
# Run all tests
pytest -v

# Run with coverage
pytest --cov=app --cov-report=html

# Open coverage report
open htmlcov/index.html
```

## Development

```bash
# Format code
black app/ tests/

# Sort imports
isort app/ tests/

# Type checking
mypy app/
```

## Production Deployment

For production, consider:

1. **Use PostgreSQL** instead of SQLite
2. **Set up Nginx** for static file serving
3. **Configure proper CORS** origins
4. **Add authentication** for admin endpoints
5. **Set up logging** and monitoring
6. **Use Gunicorn** with multiple workers:

```bash
gunicorn app.main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000
```

## License

MIT