#!/bin/bash
################################################################################
# Quick Diagnostic Script for Image Upload 500 Error
# 
# Run this first to understand what's causing the issue
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "${BLUE}=== Wishaday Image Upload Diagnostic ===${NC}"
echo ""

# Check service status
echo "1. Service Status:"
if systemctl is-active --quiet wishaday; then
    log_success "Wishaday service is running"
else
    log_error "Wishaday service is NOT running"
fi

# Check port
echo ""
echo "2. Port Status:"
if netstat -tlnp | grep -q ":8000 "; then
    log_success "Port 8000 is in use"
    netstat -tlnp | grep ":8000 "
else
    log_error "Port 8000 is NOT in use"
fi

# Check backend health
echo ""
echo "3. Backend Health:"
HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/health 2>/dev/null || echo "000")
if [[ "$HEALTH_STATUS" == "200" ]]; then
    log_success "Backend health check passed"
else
    log_error "Backend health check failed (HTTP $HEALTH_STATUS)"
fi

# Check recent logs for errors
echo ""
echo "4. Recent Error Logs:"
ERROR_LOGS=$(journalctl -u wishaday --since "10 minutes ago" | grep -i "error\|exception\|traceback" | tail -5)
if [[ -n "$ERROR_LOGS" ]]; then
    log_error "Found recent errors:"
    echo "$ERROR_LOGS"
else
    log_info "No recent errors found in logs"
fi

# Check .env file
echo ""
echo "5. Configuration:"
if [[ -f "/opt/wishaday/.env" ]]; then
    log_success ".env file exists"
else
    log_error ".env file is missing"
fi

# Check upload directory
echo ""
echo "6. Upload Directory:"
UPLOAD_DIR="/opt/wishaday/app/uploads"
if [[ -d "$UPLOAD_DIR" ]]; then
    log_success "Upload directory exists"
    ls -la "$UPLOAD_DIR" | head -3
else
    log_error "Upload directory missing: $UPLOAD_DIR"
fi

# Check Python dependencies
echo ""
echo "7. Python Dependencies:"
cd /opt/wishaday
python3 -c "
try:
    from app.main import app
    print('✅ App imports successfully')
except Exception as e:
    print(f'❌ App import failed: {e}')
" 2>/dev/null || log_error "Python import test failed"

# Test a simple API call
echo ""
echo "8. API Test:"
API_TEST=$(curl -s -X GET "http://127.0.0.1:8000/api/wishes" 2>/dev/null || echo "ERROR")
if [[ "$API_TEST" == "ERROR" ]]; then
    log_error "API test failed"
else
    log_success "API responds to GET requests"
fi

echo ""
echo -e "${BLUE}=== Diagnostic Complete ===${NC}"
echo ""
echo "If you see errors above, run: sudo ./fix-image-upload-500.sh"