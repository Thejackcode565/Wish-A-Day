#!/bin/bash
################################################################################
# Wishaday Server Management Script
# 
# This comprehensive script handles deployment, diagnostics, and fixes for
# the Wishaday application server including Nginx configuration, permissions,
# and service management.
#
# Usage:
#   sudo ./server.sh [command]
#
# Commands:
#   install     - Full server setup and installation
#   diagnose    - Diagnose current issues (404, 502, 500 errors)
#   fix-nginx   - Fix Nginx configuration and routing
#   fix-502     - Fix 502 Bad Gateway errors
#   fix-perms   - Fix file permissions and ownership
#   restart     - Restart all services
#   status      - Show current status of all components
#   logs        - Show recent logs
#   test        - Test all endpoints
#   help        - Show this help message
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
APP_NAME="wishaday"
APP_DIR="/opt/wishaday"
NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"
SERVICE_NAME="wishaday"

# Default values
WISHADAY_PORT="${WISHADAY_PORT:-8000}"
WISHADAY_DOMAIN="${WISHADAY_DOMAIN:-wishaday.hareeshworks.in}"

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

# Show help
show_help() {
    echo -e "${BOLD}Wishaday Server Management Script${NC}"
    echo ""
    echo "Usage: sudo ./server.sh [command]"
    echo ""
    echo "Commands:"
    echo "  install     - Full server setup and installation"
    echo "  diagnose    - Diagnose current issues (404, 502, 500 errors)"
    echo "  fix-nginx   - Fix Nginx configuration and routing"
    echo "  fix-502     - Fix 502 Bad Gateway errors"
    echo "  fix-perms   - Fix file permissions and ownership"
    echo "  restart     - Restart all services"
    echo "  status      - Show current status of all components"
    echo "  logs        - Show recent logs"
    echo "  test        - Test all endpoints"
    echo "  help        - Show this help message"
    echo ""
    echo "Examples:"
    echo "  sudo ./server.sh diagnose    # Check what's wrong"
    echo "  sudo ./server.sh fix-502     # Fix 502 errors"
    echo "  sudo ./server.sh restart     # Restart everything"
    echo "  sudo ./server.sh test        # Test all endpoints"
    echo ""
}

# Test endpoints
test_endpoints() {
    log_header "Testing Endpoints"
    echo ""
    
    # Test backend directly
    echo -n "Backend health (localhost:8000): "
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health 2>/dev/null | grep -q "200"; then
        echo "✅ OK"
    else
        echo "❌ FAILED"
    fi
    
    # Test backend on 127.0.0.1
    echo -n "Backend health (127.0.0.1:8000): "
    if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/health 2>/dev/null | grep -q "200"; then
        echo "✅ OK"
    else
        echo "❌ FAILED"
    fi
    
    # Test through Nginx HTTP
    echo -n "Nginx proxy health (HTTP): "
    if curl -s -o /dev/null -w "%{http_code}" http://$WISHADAY_DOMAIN/health 2>/dev/null | grep -q "200"; then
        echo "✅ OK"
    else
        echo "❌ FAILED"
    fi
    
    # Test API docs
    echo -n "API documentation: "
    if curl -s -o /dev/null -w "%{http_code}" http://$WISHADAY_DOMAIN/api/docs 2>/dev/null | grep -q "200"; then
        echo "✅ OK"
    else
        echo "❌ FAILED"
    fi
    
    # Test frontend
    echo -n "Frontend (HTTP): "
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$WISHADAY_DOMAIN/ 2>/dev/null)
    if [[ "$STATUS" == "200" ]] || [[ "$STATUS" == "301" ]] || [[ "$STATUS" == "302" ]]; then
        echo "✅ OK (HTTP $STATUS)"
    else
        echo "❌ FAILED (HTTP $STATUS)"
    fi
    
    # Test HTTPS if available
    echo -n "Frontend (HTTPS): "
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://$WISHADAY_DOMAIN/ 2>/dev/null)
    if [[ "$STATUS" == "200" ]] || [[ "$STATUS" == "301" ]] || [[ "$STATUS" == "302" ]]; then
        echo "✅ OK (HTTP $STATUS)"
    else
        echo "❌ FAILED (HTTP $STATUS) - SSL may not be configured"
    fi
    
    echo ""
}

# Show current status
show_status() {
    log_header "System Status"
    echo ""
    
    # Service status
    log_info "Service Status:"
    if systemctl is-active --quiet $SERVICE_NAME; then
        log_success "Wishaday service: RUNNING"
    else
        log_error "Wishaday service: STOPPED"
    fi
    
    if systemctl is-active --quiet nginx; then
        log_success "Nginx service: RUNNING"
    else
        log_error "Nginx service: STOPPED"
    fi
    
    # Port status
    echo ""
    log_info "Port Status:"
    if netstat -tlnp | grep -q ":8000 "; then
        log_success "Port 8000: IN USE"
        netstat -tlnp | grep ":8000 " | head -1
    else
        log_error "Port 8000: NOT IN USE"
    fi
    
    if netstat -tlnp | grep -q ":80 "; then
        log_success "Port 80: IN USE (Nginx)"
    else
        log_error "Port 80: NOT IN USE"
    fi
    
    # File status
    echo ""
    log_info "File Status:"
    if [[ -f "$APP_DIR/frontend/dist/index.html" ]]; then
        log_success "Frontend build: EXISTS"
    else
        log_error "Frontend build: MISSING"
    fi
    
    if [[ -f "$NGINX_AVAILABLE/$APP_NAME" ]]; then
        log_success "Nginx config: EXISTS"
    else
        log_error "Nginx config: MISSING"
    fi
    
    if [[ -f "/etc/systemd/system/$SERVICE_NAME.service" ]]; then
        log_success "Service file: EXISTS"
    else
        log_error "Service file: MISSING"
    fi
    
    echo ""
}

# Show recent logs
show_logs() {
    log_header "Recent Logs"
    echo ""
    
    log_info "Wishaday Service Logs (last 10 lines):"
    journalctl -u $SERVICE_NAME -n 10 --no-pager || echo "No logs available"
    
    echo ""
    log_info "Nginx Error Logs (last 10 lines):"
    tail -n 10 /var/log/nginx/error.log 2>/dev/null || echo "No error logs available"
    
    echo ""
    log_info "Nginx Access Logs (last 5 lines):"
    tail -n 5 /var/log/nginx/access.log 2>/dev/null || echo "No access logs available"
    
    echo ""
}

# Diagnose issues
diagnose_issues() {
    log_header "Diagnosing Issues"
    echo ""
    
    # Check service status
    log_info "Step 1: Checking service status..."
    if systemctl is-active --quiet $SERVICE_NAME; then
        log_success "Wishaday service is active"
    else
        log_error "Wishaday service is NOT active"
        systemctl status $SERVICE_NAME --no-pager -l || true
        return 1
    fi
    
    # Check port availability
    log_info "Step 2: Checking port availability..."
    if netstat -tlnp | grep -q ":8000 "; then
        log_success "Port 8000 is in use"
        netstat -tlnp | grep ":8000 "
    else
        log_error "Port 8000 is NOT in use"
        log_info "Checking for Python processes:"
        ps aux | grep -E "(python|uvicorn)" | grep -v grep || echo "No Python processes found"
        return 1
    fi
    
    # Test backend connectivity
    log_info "Step 3: Testing backend connectivity..."
    if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/health 2>/dev/null | grep -q "200"; then
        log_success "Backend is responding"
    else
        log_error "Backend is NOT responding"
        log_info "Recent service logs:"
        journalctl -u $SERVICE_NAME -n 5 --no-pager
        return 1
    fi
    
    # Check Nginx configuration
    log_info "Step 4: Checking Nginx configuration..."
    if nginx -t 2>/dev/null; then
        log_success "Nginx configuration is valid"
    else
        log_error "Nginx configuration has errors"
        nginx -t
        return 1
    fi
    
    # Check file permissions
    log_info "Step 5: Checking file permissions..."
    if [[ -r "$APP_DIR/frontend/dist/index.html" ]]; then
        log_success "Frontend files are readable"
    else
        log_error "Frontend files are NOT readable"
        ls -la "$APP_DIR/frontend/dist/" 2>/dev/null || echo "Directory not found"
        return 1
    fi
    
    log_success "All diagnostic checks passed!"
    echo ""
}

# Fix Nginx configuration
fix_nginx_config() {
    log_header "Fixing Nginx Configuration"
    echo ""
    
    # Backup existing config
    if [[ -f "$NGINX_AVAILABLE/$APP_NAME" ]]; then
        cp "$NGINX_AVAILABLE/$APP_NAME" "$NGINX_AVAILABLE/$APP_NAME.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "Existing config backed up"
    fi
    
    # Create new Nginx configuration
    log_info "Creating new Nginx configuration..."
    cat > "$NGINX_AVAILABLE/$APP_NAME" << EOF
server {
    listen 80;
    server_name $WISHADAY_DOMAIN;

    client_max_body_size 10M;

    # API - proxy to backend (more specific paths first)
    location /api/ {
        proxy_pass http://127.0.0.1:$WISHADAY_PORT/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:$WISHADAY_PORT/health;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        access_log off;
    }

    # Media files - serve directly from filesystem for better performance
    location /media/ {
        alias $APP_DIR/app/uploads/;
        expires 30d;
        add_header Cache-Control "public, immutable";
        try_files \$uri \$uri/ =404;
    }

    # Frontend static files - catch-all (must be last)
    location / {
        root $APP_DIR/frontend/dist;
        try_files \$uri \$uri/ /index.html;
        expires 1d;
        add_header Cache-Control "public, immutable";
    }

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
}
EOF
    
    # Enable site
    if [[ ! -L "$NGINX_ENABLED/$APP_NAME" ]]; then
        ln -sf "$NGINX_AVAILABLE/$APP_NAME" "$NGINX_ENABLED/$APP_NAME"
        log_info "Site enabled"
    fi
    
    # Remove default site if it exists
    if [[ -f "$NGINX_ENABLED/default" ]]; then
        rm "$NGINX_ENABLED/default"
        log_info "Default site removed"
    fi
    
    # Test and reload
    if nginx -t; then
        log_success "Nginx configuration test passed"
        systemctl reload nginx
        log_success "Nginx reloaded"
    else
        log_error "Nginx configuration test failed"
        return 1
    fi
}

# Fix 502 errors
fix_502_errors() {
    log_header "Fixing 502 Bad Gateway Errors"
    echo ""
    
    # Stop service
    log_info "Stopping service..."
    systemctl stop $SERVICE_NAME || true
    sleep 2
    
    # Kill any remaining processes on port 8000
    if netstat -tlnp | grep -q ":8000 "; then
        log_warn "Port 8000 still in use, killing processes..."
        lsof -ti:8000 | xargs kill -9 2>/dev/null || true
        sleep 2
    fi
    
    # Update from git
    log_info "Updating from git..."
    cd $APP_DIR
    git pull || log_warn "Git pull failed, continuing..."
    
    # Install dependencies
    log_info "Installing/updating dependencies..."
    if [[ -f "pyproject.toml" ]]; then
        pip install -e . || log_warn "Pip install failed, continuing..."
    else
        pip install fastapi uvicorn sqlalchemy pydantic-settings pillow apscheduler || log_warn "Pip install failed"
    fi
    
    # Create service file if missing
    SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
    if [[ ! -f "$SERVICE_FILE" ]]; then
        log_info "Creating service file..."
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
        systemctl daemon-reload
        log_success "Service file created"
    fi
    
    # Fix permissions
    log_info "Fixing permissions..."
    chown -R www-data:www-data $APP_DIR
    chmod +x $APP_DIR
    
    # Test application startup
    log_info "Testing application startup..."
    cd $APP_DIR
    timeout 10s python3 -m uvicorn app.main:app --host 127.0.0.1 --port 8001 &
    TEST_PID=$!
    sleep 5
    
    if kill -0 $TEST_PID 2>/dev/null; then
        log_success "Application starts successfully"
        kill $TEST_PID 2>/dev/null || true
    else
        log_error "Application failed to start"
        python3 -c "from app.main import app; print('Import test successful')" || {
            log_error "Import failed, installing basic dependencies..."
            pip install fastapi uvicorn sqlalchemy pydantic-settings pillow apscheduler
        }
    fi
    
    # Start service
    log_info "Starting service..."
    systemctl daemon-reload
    systemctl enable $SERVICE_NAME
    systemctl start $SERVICE_NAME
    sleep 3
    
    if systemctl is-active --quiet $SERVICE_NAME; then
        log_success "Service started successfully"
    else
        log_error "Service failed to start"
        journalctl -u $SERVICE_NAME -n 10 --no-pager
        return 1
    fi
}

# Fix permissions
fix_permissions() {
    log_header "Fixing File Permissions"
    echo ""
    
    # Fix parent directory permissions
    log_info "Fixing parent directory permissions..."
    chmod 755 /opt
    chmod 755 /opt/wishaday
    chmod 755 /opt/wishaday/frontend
    
    if [[ -d "/opt/wishaday/frontend/dist" ]]; then
        chmod 755 /opt/wishaday/frontend/dist
    fi
    
    # Fix frontend permissions
    if [[ -d "$APP_DIR/frontend/dist" ]]; then
        log_info "Setting frontend ownership to www-data..."
        chown -R www-data:www-data "$APP_DIR/frontend/dist"
        find "$APP_DIR/frontend/dist" -type d -exec chmod 755 {} \;
        find "$APP_DIR/frontend/dist" -type f -exec chmod 644 {} \;
        log_success "Frontend permissions fixed"
    else
        log_warn "Frontend dist directory not found"
    fi
    
    # Fix uploads directory
    log_info "Setting uploads directory permissions..."
    mkdir -p "$APP_DIR/app/uploads"
    chown -R www-data:www-data "$APP_DIR/app/uploads"
    chmod 775 "$APP_DIR/app/uploads"
    log_success "Uploads permissions fixed"
    
    # Add www-data to wishaday group if needed
    usermod -a -G wishaday www-data 2>/dev/null || true
    
    # Show current permissions
    log_info "Current permissions:"
    if [[ -f "$APP_DIR/frontend/dist/index.html" ]]; then
        namei -l "$APP_DIR/frontend/dist/index.html" || ls -la "$APP_DIR/frontend/dist/index.html"
    else
        log_warn "index.html not found"
    fi
}

# Restart all services
restart_services() {
    log_header "Restarting Services"
    echo ""
    
    log_info "Restarting Wishaday service..."
    systemctl restart $SERVICE_NAME
    sleep 3
    
    log_info "Reloading Nginx..."
    nginx -t && systemctl reload nginx
    
    log_info "Waiting for services to start..."
    sleep 5
    
    if systemctl is-active --quiet $SERVICE_NAME; then
        log_success "Wishaday service is running"
    else
        log_error "Wishaday service failed to start"
        return 1
    fi
    
    if systemctl is-active --quiet nginx; then
        log_success "Nginx is running"
    else
        log_error "Nginx failed to start"
        return 1
    fi
}

# Full installation
full_install() {
    log_header "Full Server Installation"
    echo ""
    
    log_info "This will perform a complete server setup..."
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled"
        return 0
    fi
    
    # Update system
    log_info "Updating system packages..."
    apt update && apt upgrade -y
    
    # Install dependencies
    log_info "Installing system dependencies..."
    apt install -y python3 python3-pip nginx curl git lsof net-tools
    
    # Create app directory
    log_info "Setting up application directory..."
    mkdir -p $APP_DIR
    cd $APP_DIR
    
    # Clone or update repository
    if [[ -d ".git" ]]; then
        log_info "Updating existing repository..."
        git pull
    else
        log_info "Cloning repository..."
        # You'll need to replace this with your actual repository URL
        log_warn "Please clone your repository to $APP_DIR manually"
    fi
    
    # Install Python dependencies
    log_info "Installing Python dependencies..."
    pip install fastapi uvicorn sqlalchemy pydantic-settings pillow apscheduler
    
    # Build frontend
    if [[ -d "frontend" ]]; then
        log_info "Building frontend..."
        cd frontend
        if command -v npm &> /dev/null; then
            npm install && npm run build
        else
            log_warn "npm not found, please install Node.js and build frontend manually"
        fi
        cd ..
    fi
    
    # Run all fixes
    fix_nginx_config
    fix_502_errors
    fix_permissions
    
    log_success "Installation completed!"
    echo ""
    test_endpoints
}

# Main function
main() {
    case "${1:-help}" in
        "install")
            check_root
            full_install
            ;;
        "diagnose")
            check_root
            diagnose_issues
            ;;
        "fix-nginx")
            check_root
            fix_nginx_config
            ;;
        "fix-502")
            check_root
            fix_502_errors
            ;;
        "fix-perms")
            check_root
            fix_permissions
            ;;
        "restart")
            check_root
            restart_services
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs
            ;;
        "test")
            test_endpoints
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Print header
echo -e "${CYAN}${BOLD}"
echo "========================================="
echo "  Wishaday Server Management Script"
echo "========================================="
echo -e "${NC}"

# Run main function with all arguments
main "$@"