@echo off
REM Wishaday Production Deployment Launcher for Windows
REM Uses SQLite for production (as per requirements)
REM Runs with Uvicorn worker for better performance

echo =========================================
echo Wishaday - Production Mode
echo =========================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.11 or higher from https://python.org
    pause
    exit /b 1
)

echo [1/7] Python version:
python --version
echo.

REM Check if virtual environment exists, create if not
if not exist "venv" (
    echo [2/7] Creating virtual environment...
    python -m venv venv
    if errorlevel 1 (
        echo ERROR: Failed to create virtual environment
        pause
        exit /b 1
    )
) else (
    echo [2/7] Virtual environment already exists
)
echo.

REM Activate virtual environment
echo [3/7] Activating virtual environment...
call venv\Scripts\activate
if errorlevel 1 (
    echo ERROR: Failed to activate virtual environment
    pause
    exit /b 1
)
echo.

REM Install dependencies (production only, no dev dependencies)
echo [4/7] Installing production dependencies...
pip install -q --upgrade pip
pip install -q -e "."
if errorlevel 1 (
    echo ERROR: Failed to install dependencies
    pause
    exit /b 1
)
echo Dependencies installed successfully
echo.

REM Create production environment file if not exists
echo [5/7] Setting up production environment...
if not exist ".env" (
    echo Creating .env file for production...
    (
        echo # Wishaday Production Configuration
        echo # SQLite is used for both local and production
echo.
        echo # Database Configuration - SQLite
        echo DATABASE_URL=sqlite:///./wishaday.db
        echo.
        echo # Upload Configuration
        echo UPLOAD_DIR=./app/uploads
        echo MAX_FILE_SIZE=2097152
        echo MAX_IMAGES_PER_WISH=5
        echo.
        echo # Rate Limiting
        echo MAX_WISHES_PER_IP_PER_DAY=10
        echo.
        echo # Cleanup Configuration
        echo CLEANUP_INTERVAL_MINUTES=30
        echo SOFT_DELETE_GRACE_PERIOD_MINUTES=10
        echo.
        echo # Server Configuration - Production
        echo BASE_URL=http://localhost:8000
        echo DEBUG=false
        echo PORT=8000
        echo.
        echo # Security - CHANGE THIS IN PRODUCTION!
        echo SECRET_KEY=change-this-to-a-secure-random-string-in-production
    ) > .env
    echo.
    echo WARNING: A default .env file has been created.
    echo IMPORTANT: Please edit .env and configure:
    echo   - BASE_URL: Your public domain URL
echo   - SECRET_KEY: A secure random string
echo   - PORT: The port you want to run on
echo.
    echo Press any key to continue with default settings...
    pause >nul
) else (
    echo .env file already exists - using existing configuration
)
echo.

REM Initialize database
echo [6/7] Initializing database...
python scripts/init_db.py
if errorlevel 1 (
    echo ERROR: Failed to initialize database
    pause
    exit /b 1
)
echo.

REM Get port from environment or use default
for /f "tokens=2 delims==" %%a in ('findstr /B "PORT=" .env') do set WISHADAY_PORT=%%a
if not defined WISHADAY_PORT set WISHADAY_PORT=8000

echo [7/7] Production configuration complete
echo.

echo =========================================
echo Starting Wishaday Production Server
echo =========================================
echo.
echo Server will be available at: http://localhost:%WISHADAY_PORT%
echo.
echo Production Settings:
echo   - Workers: 4
echo   - Database: SQLite
echo   - Debug: OFF
echo   - Auto-reload: OFF
echo.
echo Press Ctrl+C to stop the server
echo.

REM Run production server with multiple workers
REM Using uvicorn directly with workers (gunicorn not available on Windows)
python -m uvicorn app.main:app --host 0.0.0.0 --port %WISHADAY_PORT% --workers 4

REM Deactivate virtual environment on exit
call venv\Scripts\deactivate

echo.
echo Server stopped.
pause
