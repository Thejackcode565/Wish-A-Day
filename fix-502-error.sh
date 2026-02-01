#!/bin/bash
################################################################################
# Fix 502 Bad Gateway Error
# 
# This script attempts to fix common causes of 502 Bad Gateway errors
# for the Wishaday application.
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

echo "========================================="
echo "  Fixing 502 Bad Gateway Error"
echo "========================================="
echo ""

log_info "Step 1: Checking current service status..."
systemctl status $SERVICE_NAME --no-pager -l || true

log_info "Step 2: Stopping service..."
systemctl stop $SERVICE_NAME || true
sleep 2

log_info "Step 3: Checking if port 8000 is still in use..."
if netstat -tlnp | grep -q ":8000 "; then
    log_warn "Port 8000 is still in use. Attempting to kill processes..."
    lsof -ti:8000 | xargs kill -9 2>/dev/null || true
    sleep 2
fi

log_info "Step 4: Updating application from git..."
cd $APP_DIR
git pull || log_warn "Git pull failed, continuing..."

log_info "Step 5: Installing/updating Python dependencies..."
if [[ -f "pyproject.toml" ]]; then
    pip install -e . || log_warn "Pip install failed, continuing..."
fi

log_info "Step 6: Checking service configuration..."
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
if [[ ! -f "$SERVICE_FILE" ]]; then
    log_error "Service file not found. Creating default service file..."
    
    cat > "$SERVICE_FILE" << 'EOF'
[Unit]
Description=Wishaday FastAPI Application
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/wishaday
Environment=PATH=/usr/local/bin:/usr/bin:/bin
ExecStart=/usr/bin/python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    log_success "Created service file"
    systemctl daemon-reload
fi

log_info "Step 7: Ensuring correct permissions..."
chown -R www-data:www-data $APP_DIR
chmod +x $APP_DIR

log_info "Step 8: Testing application manually..."
cd $APP_DIR
echo "Testing if the application starts..."
timeout 10s python3 -m uvicorn app.main:app --host 127.0.0.1 --port 8001 &
TEST_PID=$!
sleep 5

if kill -0 $TEST_PID 2>/dev/null; then
    log_success "Application starts successfully"
    kill $TEST_PID 2>/dev/null || true
else
    log_error "Application failed to start. Check dependencies and code."
    log_info "Trying to run directly to see errors..."
    python3 -c "from app.main import app; print('Import successful')" || {
        log_error "Import failed. Installing missing dependencies..."
        pip install fastapi uvicorn sqlalchemy pydantic-settings pillow apscheduler
    }
fi

log_info "Step 9: Reloading systemd and starting service..."
systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl start $SERVICE_NAME
sleep 3

log_info "Step 10: Checking service status..."
if systemctl is-active --quiet $SERVICE_NAME; then
    log_success "Service is running"
else
    log_error "Service failed to start"
    log_info "Service logs:"
    journalctl -u $SERVICE_NAME -n 20 --no-pager
    exit 1
fi

log_info "Step 11: Testing backend connectivity..."
sleep 2
echo -n "Testing backend health endpoint: "
if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/health 2>/dev/null | grep -q "200"; then
    echo "✅ OK"
else
    echo "❌ FAILED"
    log_error "Backend is not responding"
    log_info "Recent service logs:"
    journalctl -u $SERVICE_NAME -n 10 --no-pager
    exit 1
fi

log_info "Step 12: Testing through Nginx..."
echo -n "Testing through Nginx: "
if curl -s -o /dev/null -w "%{http_code}" http://localhost/health 2>/dev/null | grep -q "200"; then
    echo "✅ OK"
else
    echo "❌ FAILED - Check Nginx configuration"
fi

echo ""
log_success "502 error fix completed!"
echo ""
echo "Service Status:"
systemctl status $SERVICE_NAME --no-pager -l
echo ""
echo "Test URLs:"
echo "  - Direct backend: http://127.0.0.1:8000/health"
echo "  - Through Nginx: http://wishaday.hareeshworks.in/health"
echo "  - API docs: http://wishaday.hareeshworks.in/api/docs"
echo ""
echo "If issues persist, check:"
echo "  - sudo journalctl -u $SERVICE_NAME -f"
echo "  - sudo tail -f /var/log/nginx/error.log"
echo ""