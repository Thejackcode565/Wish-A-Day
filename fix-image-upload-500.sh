#!/bin/bash
################################################################################
# Fix Image Upload 500 Error Script
# 
# This script diagnoses and fixes the 500 Internal Server Error when uploading
# images to the Wishaday application.
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
APP_DIR="/opt/wishaday"
SERVICE_NAME="wishaday"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "${CYAN}${BOLD}$1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Step 1: Check current service status and logs
check_service_status() {
    log_header "Step 1: Checking Service Status"
    echo ""
    
    log_info "Current service status:"
    systemctl status $SERVICE_NAME --no-pager -l || true
    
    echo ""
    log_info "Recent service logs (last 20 lines):"
    journalctl -u $SERVICE_NAME -n 20 --no-pager || true
    
    echo ""
    log_info "Checking for Python errors in logs:"
    journalctl -u $SERVICE_NAME --since "1 hour ago" | grep -i "error\|exception\|traceback" || log_info "No Python errors found in recent logs"
    
    echo ""
}

# Step 2: Check environment configuration
check_environment() {
    log_header "Step 2: Checking Environment Configuration"
    echo ""
    
    cd $APP_DIR
    
    # Check if .env file exists
    if [[ -f ".env" ]]; then
        log_success ".env file exists"
        log_info "Current .env configuration:"
        cat .env | grep -v "SECRET_KEY" || true
    else
        log_error ".env file is missing!"
        log_info "Creating .env file from .env.example..."
        
        if [[ -f ".env.example" ]]; then
            cp .env.example .env
            log_success "Created .env file from .env.example"
            
            # Set production values
            sed -i 's|DATABASE_URL=sqlite:///./wishaday.db|DATABASE_URL=sqlite:///./app/wishaday.db|g' .env
            sed -i 's|UPLOAD_DIR=./app/uploads|UPLOAD_DIR=/opt/wishaday/app/uploads|g' .env
            sed -i 's|BASE_URL=http://localhost:8000|BASE_URL=https://wishaday.hareeshworks.in|g' .env
            sed -i 's|DEBUG=true|DEBUG=false|g' .env
            sed -i 's|SECRET_KEY=your-secret-key-change-in-production|SECRET_KEY='$(openssl rand -hex 32)'|g' .env
            
            log_success "Updated .env with production values"
        else
            log_error ".env.example file not found!"
            return 1
        fi
    fi
    
    # Check upload directory
    UPLOAD_DIR=$(grep "UPLOAD_DIR=" .env | cut -d'=' -f2)
    if [[ -z "$UPLOAD_DIR" ]]; then
        UPLOAD_DIR="/opt/wishaday/app/uploads"
    fi
    
    log_info "Checking upload directory: $UPLOAD_DIR"
    if [[ ! -d "$UPLOAD_DIR" ]]; then
        log_warn "Upload directory doesn't exist, creating..."
        mkdir -p "$UPLOAD_DIR"
        mkdir -p "$UPLOAD_DIR/wishes"
        chown -R www-data:www-data "$UPLOAD_DIR"
        chmod 775 "$UPLOAD_DIR"
        log_success "Created upload directory with proper permissions"
    else
        log_success "Upload directory exists"
        # Fix permissions anyway
        chown -R www-data:www-data "$UPLOAD_DIR"
        chmod 775 "$UPLOAD_DIR"
        log_info "Fixed upload directory permissions"
    fi
    
    echo ""
}

# Step 3: Check Python dependencies
check_dependencies() {
    log_header "Step 3: Checking Python Dependencies"
    echo ""
    
    cd $APP_DIR
    
    log_info "Testing Python imports..."
    
    # Test basic imports
    python3 -c "
import sys
print(f'Python version: {sys.version}')

try:
    import fastapi
    print('✅ FastAPI imported successfully')
except ImportError as e:
    print(f'❌ FastAPI import failed: {e}')

try:
    import uvicorn
    print('✅ Uvicorn imported successfully')
except ImportError as e:
    print(f'❌ Uvicorn import failed: {e}')

try:
    import sqlalchemy
    print('✅ SQLAlchemy imported successfully')
except ImportError as e:
    print(f'❌ SQLAlchemy import failed: {e}')

try:
    from PIL import Image
    print('✅ Pillow (PIL) imported successfully')
except ImportError as e:
    print(f'❌ Pillow import failed: {e}')

try:
    import pydantic_settings
    print('✅ Pydantic Settings imported successfully')
except ImportError as e:
    print(f'❌ Pydantic Settings import failed: {e}')

try:
    from apscheduler.schedulers.background import BackgroundScheduler
    print('✅ APScheduler imported successfully')
except ImportError as e:
    print(f'❌ APScheduler import failed: {e}')
" || {
        log_error "Python import test failed"
        log_info "Installing missing dependencies..."
        pip3 install fastapi uvicorn sqlalchemy pydantic-settings pillow apscheduler
        log_success "Dependencies installed"
    }
    
    # Test app import
    log_info "Testing application import..."
    python3 -c "
try:
    from app.main import app
    print('✅ Application imported successfully')
except Exception as e:
    print(f'❌ Application import failed: {e}')
    import traceback
    traceback.print_exc()
" || {
        log_error "Application import failed - this is likely the cause of the 500 error"
        return 1
    }
    
    echo ""
}

# Step 4: Check database
check_database() {
    log_header "Step 4: Checking Database"
    echo ""
    
    cd $APP_DIR
    
    # Check if database file exists
    DB_PATH="./app/wishaday.db"
    if [[ -f "$DB_PATH" ]]; then
        log_success "Database file exists: $DB_PATH"
        ls -la "$DB_PATH"
    else
        log_warn "Database file doesn't exist, initializing..."
        python3 -c "
from app.database import init_db
init_db()
print('Database initialized successfully')
" || {
            log_error "Database initialization failed"
            return 1
        }
        log_success "Database initialized"
    fi
    
    # Test database connection
    log_info "Testing database connection..."
    python3 -c "
from app.database import SessionLocal
from app.models import Wish

db = SessionLocal()
try:
    # Try to query wishes
    count = db.query(Wish).count()
    print(f'✅ Database connection successful - {count} wishes found')
except Exception as e:
    print(f'❌ Database connection failed: {e}')
    raise
finally:
    db.close()
" || {
        log_error "Database connection test failed"
        return 1
    }
    
    echo ""
}

# Step 5: Test image upload functionality
test_image_upload() {
    log_header "Step 5: Testing Image Upload Functionality"
    echo ""
    
    cd $APP_DIR
    
    log_info "Testing image processing functions..."
    python3 -c "
from app.services.image import validate_image, process_image, ALLOWED_CONTENT_TYPES, ALLOWED_EXTENSIONS
from app.config import settings

print(f'✅ Image service imported successfully')
print(f'Allowed content types: {ALLOWED_CONTENT_TYPES}')
print(f'Allowed extensions: {ALLOWED_EXTENSIONS}')
print(f'Max file size: {settings.MAX_FILE_SIZE} bytes ({settings.MAX_FILE_SIZE // 1024 // 1024}MB)')
print(f'Max images per wish: {settings.MAX_IMAGES_PER_WISH}')
print(f'Upload path: {settings.upload_path}')

# Test upload directory creation
wish_upload_path = settings.get_wish_upload_path(1)
print(f'Test wish upload path: {wish_upload_path}')
" || {
        log_error "Image service test failed"
        return 1
    }
    
    echo ""
}

# Step 6: Fix service and restart
fix_and_restart() {
    log_header "Step 6: Fixing Service and Restarting"
    echo ""
    
    # Stop service
    log_info "Stopping service..."
    systemctl stop $SERVICE_NAME || true
    sleep 2
    
    # Kill any remaining processes
    if netstat -tlnp | grep -q ":8000 "; then
        log_warn "Port 8000 still in use, killing processes..."
        lsof -ti:8000 | xargs kill -9 2>/dev/null || true
        sleep 2
    fi
    
    # Fix ownership
    log_info "Fixing file ownership..."
    chown -R www-data:www-data $APP_DIR
    
    # Update service file to include better error handling
    log_info "Updating service file..."
    cat > "/etc/systemd/system/$SERVICE_NAME.service" << 'EOF'
[Unit]
Description=Wishaday - Wish Sharing Platform
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/wishaday
Environment=PATH=/usr/local/bin:/usr/bin:/bin
Environment=PYTHONPATH=/opt/wishaday
ExecStart=/usr/bin/python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --log-level info
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=wishaday

# Resource limits
MemoryMax=512M
TasksMax=100

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    log_success "Service file updated"
    
    # Start service
    log_info "Starting service..."
    systemctl enable $SERVICE_NAME
    systemctl start $SERVICE_NAME
    
    # Wait and check
    sleep 5
    
    if systemctl is-active --quiet $SERVICE_NAME; then
        log_success "Service started successfully"
        
        # Wait for service to be ready
        log_info "Waiting for service to be ready..."
        sleep 5
        
        # Test backend
        if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/health 2>/dev/null | grep -q "200"; then
            log_success "Backend is responding"
        else
            log_error "Backend is not responding"
            log_info "Recent logs:"
            journalctl -u $SERVICE_NAME -n 10 --no-pager
            return 1
        fi
    else
        log_error "Service failed to start"
        log_info "Service status:"
        systemctl status $SERVICE_NAME --no-pager -l
        log_info "Recent logs:"
        journalctl -u $SERVICE_NAME -n 10 --no-pager
        return 1
    fi
    
    echo ""
}

# Step 7: Test image upload endpoint
test_upload_endpoint() {
    log_header "Step 7: Testing Image Upload Endpoint"
    echo ""
    
    # First, create a test wish to upload to
    log_info "Creating a test wish..."
    WISH_RESPONSE=$(curl -s -X POST "http://127.0.0.1:8000/api/wishes" \
        -H "Content-Type: application/json" \
        -d '{
            "message": "Test wish for image upload",
            "theme": "default"
        }' || echo "")
    
    if [[ -n "$WISH_RESPONSE" ]]; then
        WISH_SLUG=$(echo "$WISH_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['slug'])" 2>/dev/null || echo "")
        
        if [[ -n "$WISH_SLUG" ]]; then
            log_success "Test wish created with slug: $WISH_SLUG"
            
            # Create a small test image
            log_info "Creating test image..."
            python3 -c "
from PIL import Image
import io

# Create a small test image
img = Image.new('RGB', (100, 100), color='red')
img.save('/tmp/test_image.jpg', 'JPEG')
print('Test image created: /tmp/test_image.jpg')
"
            
            # Test image upload
            log_info "Testing image upload..."
            UPLOAD_RESPONSE=$(curl -s -X POST "http://127.0.0.1:8000/api/wishes/$WISH_SLUG/images" \
                -F "file=@/tmp/test_image.jpg" || echo "ERROR")
            
            if [[ "$UPLOAD_RESPONSE" == "ERROR" ]]; then
                log_error "Image upload failed with curl error"
            elif echo "$UPLOAD_RESPONSE" | grep -q "url"; then
                log_success "Image upload successful!"
                echo "Response: $UPLOAD_RESPONSE"
            else
                log_error "Image upload failed"
                echo "Response: $UPLOAD_RESPONSE"
            fi
            
            # Clean up
            rm -f /tmp/test_image.jpg
        else
            log_error "Failed to extract wish slug from response"
        fi
    else
        log_error "Failed to create test wish"
    fi
    
    echo ""
}

# Main execution
main() {
    log_header "Wishaday Image Upload 500 Error Fix"
    echo ""
    
    check_root
    
    check_service_status
    check_environment
    check_dependencies
    check_database
    test_image_upload
    fix_and_restart
    test_upload_endpoint
    
    log_header "Fix Complete!"
    echo ""
    log_success "The image upload 500 error should now be resolved."
    log_info "You can test the image upload functionality in your frontend."
    log_info "If issues persist, check the logs with: journalctl -u wishaday -f"
    echo ""
}

# Run main function
main "$@"