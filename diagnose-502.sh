#!/bin/bash
################################################################################
# Diagnose 502 Bad Gateway Error
# 
# This script helps diagnose why Nginx is getting 502 when trying to 
# connect to the FastAPI backend.
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

echo "========================================="
echo "  Diagnosing 502 Bad Gateway Error"
echo "========================================="
echo ""

log_info "Step 1: Checking if Wishaday service is running..."
if systemctl is-active --quiet wishaday; then
    log_success "Wishaday service is active"
else
    log_error "Wishaday service is NOT active"
    echo ""
    log_info "Service status:"
    systemctl status wishaday --no-pager -l
    echo ""
    log_info "Recent logs:"
    journalctl -u wishaday -n 20 --no-pager
    exit 1
fi

log_info "Step 2: Checking if backend is listening on port 8000..."
if netstat -tlnp | grep -q ":8000 "; then
    log_success "Something is listening on port 8000"
    netstat -tlnp | grep ":8000 "
else
    log_error "Nothing is listening on port 8000"
    echo ""
    log_info "Checking what ports are in use:"
    netstat -tlnp | grep python || echo "No Python processes found listening"
fi

log_info "Step 3: Testing direct backend connection..."
echo -n "Testing localhost:8000/health: "
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health 2>/dev/null | grep -q "200"; then
    echo "✅ OK"
else
    echo "❌ FAILED"
    log_error "Backend is not responding on localhost:8000"
fi

echo -n "Testing 127.0.0.1:8000/health: "
if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/health 2>/dev/null | grep -q "200"; then
    echo "✅ OK"
else
    echo "❌ FAILED"
    log_error "Backend is not responding on 127.0.0.1:8000"
fi

log_info "Step 4: Checking Nginx error logs..."
echo ""
log_info "Recent Nginx error log entries:"
tail -n 10 /var/log/nginx/error.log | grep -E "(wishaday|upstream|502|connect)" || echo "No relevant errors found"

log_info "Step 5: Checking Wishaday service logs..."
echo ""
log_info "Recent Wishaday service logs:"
journalctl -u wishaday -n 10 --no-pager

log_info "Step 6: Checking process information..."
echo ""
log_info "Wishaday processes:"
ps aux | grep -E "(wishaday|uvicorn|python.*main)" | grep -v grep || echo "No Wishaday processes found"

log_info "Step 7: Checking configuration..."
echo ""
log_info "Wishaday service file:"
if [[ -f /etc/systemd/system/wishaday.service ]]; then
    cat /etc/systemd/system/wishaday.service
else
    log_error "Service file not found at /etc/systemd/system/wishaday.service"
fi

echo ""
log_info "Environment variables (if any):"
if [[ -f /opt/wishaday/.env ]]; then
    echo "Found .env file"
    grep -E "^(PORT|HOST|DATABASE_URL)" /opt/wishaday/.env || echo "No relevant env vars found"
else
    echo "No .env file found"
fi

echo ""
echo "========================================="
echo "  Diagnosis Complete"
echo "========================================="
echo ""
echo "Common causes of 502 Bad Gateway:"
echo "  1. Backend service not running"
echo "  2. Backend listening on wrong port/interface"
echo "  3. Firewall blocking connection"
echo "  4. Backend crashed or failed to start"
echo "  5. Wrong proxy_pass configuration in Nginx"
echo ""
echo "Next steps:"
echo "  - If service is not running: sudo systemctl start wishaday"
echo "  - If service fails to start: sudo journalctl -u wishaday -f"
echo "  - If port is wrong: check service configuration"
echo "  - If backend is not responding: check application logs"
echo ""