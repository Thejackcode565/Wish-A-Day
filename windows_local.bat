@echo off
REM Wishaday Local Development Launcher for Windows
REM Uses SQLite for both local and production (as per requirements)

echo =========================================
echo Wishaday - Local Development Mode
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

echo [1/6] Python version:
python --version
echo.

REM Check if virtual environment exists, create if not
if not exist "venv" (
    echo [2/6] Creating virtual environment...
    python -m venv venv
    if errorlevel 1 (
        echo ERROR: Failed to create virtual environment
        pause
        exit /b 1
    )
) else (
    echo [2/6] Virtual environment already exists
)
echo.

REM Activate virtual environment
echo [3/6] Activating virtual environment...
call venv\Scripts\activate
if errorlevel 1 (
    echo ERROR: Failed to activate virtual environment
    pause
    exit /b 1
)
echo.

REM Install dependencies
echo [4/6] Installing/updating dependencies...
pip install -q --upgrade pip
pip install -q -e ".[dev]"
if errorlevel 1 (
    echo ERROR: Failed to install dependencies
    pause
    exit /b 1
)
echo Dependencies installed successfully
echo.

REM Create local environment file if not exists
echo [5/6] Setting up local environment...
if not exist ".env" (
    echo Creating .env file for local development...
    (
        echo # Wishaday Local Development Configuration
        echo # SQLite is used for both local and production
        echo.
        echo # Database Configuration - SQLite
        echo DATABASE_URL=sqlite:///./wishaday_local.db
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
        echo # Server Configuration
        echo BASE_URL=http://localhost:8000
        echo DEBUG=true
        echo PORT=8000
        echo.
        echo # Security
        echo SECRET_KEY=local-dev-secret-key-change-in-production
    ) > .env
    echo .env file created with local settings
) else (
    echo .env file already exists - using existing configuration
)
echo.

REM Initialize database
echo [6/6] Initializing database...
python scripts/init_db.py
if errorlevel 1 (
    echo ERROR: Failed to initialize database
    pause
    exit /b 1
)
echo.

echo =========================================
echo Starting Wishaday Development Server
echo =========================================
echo.
echo API will be available at: http://localhost:8000
echo API Docs: http://localhost:8000/api/docs
echo.
echo Press Ctrl+C to stop the server
echo.

REM Run the development server with auto-reload
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

REM Deactivate virtual environment on exit
call venv\Scripts\deactivate

echo.
echo Server stopped.
pause
