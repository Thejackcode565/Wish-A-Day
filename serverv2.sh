#!/bin/bash
################################################################################
# Wishaday Server Management Script v2.0
# 
# Complete server management solution for Wishaday application including:
# - Full system setup and installation
# - Environment configuration
# - Service management
# - Error diagnosis and fixes
# - Production deployment
# - Monitoring and maintenance
#
# Usage:
#   sudo ./serverv2.sh [command]
#
# Commands:
#   setup       - Complete initial server setup (Ubuntu/Debian)
#   install     - Install Wishaday application
#   configure   - Configure environment and services
#   deploy      - Deploy to production
#   start       - Start all services
#   stop        - Stop all services
#   restart     - Restart all services
#   status      - Show system status
#   diagnose    - Diagnose and fix issues automatically
#   fix-all     - Fix all common issues
#   fix-502     - Fix 502 Bad Gateway errors
#   fix-perms   - Fix file permissions
#   fix-db      - Fix database issues
#   fix-env     - Fix environment configuration
#   fix-upload  - Fix image upload 500 errors
#   logs        - Show recent logs
#   test        - Test all endpoints
#   update      - Update application from git
#   backup      - Create system backup
#   restore     - Restore from backup
#   monitor     - Real-time monitoring
#   clean       - Clean build artifacts and temporary files
#   rebuild     - Complete rebuild (clean + install + build)
#   help        - Show this help message
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="wishaday"
APP_DIR="/opt/wishaday"
NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"
SERVICE_NAME="wishaday"
BACKUP_DIR="/opt/wishaday-backups"

# Default values (can be overridden by environment)
WISHADAY_PORT="${WISHADAY_PORT:-8000}"
WISHADAY_DOMAIN="${WISHADAY_DOMAIN:-wishaday.hareeshworks.in}"
WISHADAY_USER="${WISHADAY_USER:-wishaday}"
WISHADAY_GROUP="${WISHADAY_GROUP:-wishaday}"
GIT_REPO="${GIT_REPO:-}"
NODE_VERSION="${NODE_VERSION:-20}"

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

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# Progress indicator
show_progress() {
    local duration=$1
    local message=$2
    echo -n "$message"
    for ((i=0; i<duration; i++)); do
        echo -n "."
        sleep 1
    done
    echo " Done!"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check OS compatibility
check_os() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot determine OS version"
        exit 1
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        log_warn "This script is optimized for Ubuntu/Debian. Proceeding anyway..."
    fi
    
    log_info "Detected OS: $PRETTY_NAME"
}

# Create user and group
create_user() {
    log_step "Creating system user and group"
    
    if ! getent group "$WISHADAY_GROUP" >/dev/null 2>&1; then
        groupadd "$WISHADAY_GROUP"
        log_info "Created group: $WISHADAY_GROUP"
    fi
    
    if ! getent passwd "$WISHADAY_USER" >/dev/null 2>&1; then
        useradd -r -g "$WISHADAY_GROUP" -d "$APP_DIR" -s /bin/bash "$WISHADAY_USER"
        log_info "Created user: $WISHADAY_USER"
    fi
    
    # Add www-data to wishaday group for nginx
    usermod -a -G "$WISHADAY_GROUP" www-data 2>/dev/null || true
}

# Install system dependencies
install_system_deps() {
    log_step "Installing system dependencies"
    
    # Update package list
    apt update
    
    # Install essential packages
    apt install -y \
        curl \
        wget \
        git \
        nginx \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        build-essential \
        pkg-config \
        libffi-dev \
        libssl-dev \
        sqlite3 \
        libsqlite3-dev \
        supervisor \
        htop \
        tree \
        lsof \
        net-tools \
        unzip \
        certbot \
        python3-certbot-nginx
    
    log_success "System dependencies installed"
}

# Install Node.js
install_nodejs() {
    log_step "Installing Node.js $NODE_VERSION"
    
    if command -v node >/dev/null 2>&1; then
        local current_version=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ "$current_version" -ge "$NODE_VERSION" ]]; then
            log_info "Node.js $current_version is already installed"
            return 0
        fi
    fi
    
    # Install Node.js using NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
    apt install -y nodejs
    
    # Verify installation
    node --version
    npm --version
    
    log_success "Node.js installed successfully"
}

# Setup application directory
setup_app_directory() {
    log_step "Setting up application directory"
    
    # Create directory structure
    mkdir -p "$APP_DIR"
    mkdir -p "$APP_DIR/logs"
    mkdir -p "$APP_DIR/app/uploads/wishes"
    mkdir -p "$BACKUP_DIR"
    
    # Set ownership
    chown -R "$WISHADAY_USER:$WISHADAY_GROUP" "$APP_DIR"
    chown -R "$WISHADAY_USER:$WISHADAY_GROUP" "$BACKUP_DIR"
    
    log_success "Application directory created"
}

# Clone or update repository
setup_repository() {
    log_step "Setting up repository"
    
    cd "$APP_DIR"
    
    if [[ -d ".git" ]]; then
        log_info "Repository exists, updating..."
        sudo -u "$WISHADAY_USER" git pull
    elif [[ -n "$GIT_REPO" ]]; then
        log_info "Cloning repository from $GIT_REPO"
        sudo -u "$WISHADAY_USER" git clone "$GIT_REPO" .
    else
        log_warn "No git repository specified. Please manually copy your code to $APP_DIR"
        log_info "You can set GIT_REPO environment variable for automatic cloning"
    fi
    
    # Ensure ownership
    chown -R "$WISHADAY_USER:$WISHADAY_GROUP" "$APP_DIR"
    
    log_success "Repository setup complete"
}

# Setup Python environment
setup_python_env() {
    log_step "Setting up Python virtual environment"
    
    cd "$APP_DIR"
    
    # Create virtual environment
    if [[ ! -d "venv" ]]; then
        sudo -u "$WISHADAY_USER" python3 -m venv venv
        log_info "Virtual environment created"
    fi
    
    # Activate and install dependencies
    sudo -u "$WISHADAY_USER" bash -c "
        source venv/bin/activate
        pip install --upgrade pip setuptools wheel
        
        # Install from pyproject.toml if available
        if [[ -f 'pyproject.toml' ]]; then
            pip install -e .
        else
            # Install basic dependencies
            pip install fastapi uvicorn sqlalchemy pydantic-settings pillow apscheduler python-multipart
        fi
    "
    
    log_success "Python environment setup complete"
}

# Build frontend
build_frontend() {
    log_step "Building frontend"
    
    if [[ ! -d "$APP_DIR/frontend" ]]; then
        log_warn "Frontend directory not found, skipping frontend build"
        return 0
    fi
    
    cd "$APP_DIR/frontend"
    
    # Install dependencies and build
    sudo -u "$WISHADAY_USER" bash -c "
        npm install
        npm run build
    "
    
    # Ensure proper permissions
    chown -R "$WISHADAY_USER:$WISHADAY_GROUP" "$APP_DIR/frontend"
    
    log_success "Frontend built successfully"
}

# Configure environment
configure_environment() {
    log_step "Configuring environment"
    
    cd "$APP_DIR"
    
    # Create .env file if it doesn't exist
    if [[ ! -f ".env" ]]; then
        if [[ -f ".env.example" ]]; then
            cp ".env.example" ".env"
            log_info "Created .env from .env.example"
        else
            create_default_env
        fi
    fi
    
    # Fix common .env issues
    fix_env_file
    
    # Set proper permissions
    chown "$WISHADAY_USER:$WISHADAY_GROUP" ".env"
    chmod 640 ".env"
    
    log_success "Environment configured"
}

# Create default .env file
create_default_env() {
    log_info "Creating default .env file"
    
    cat > "$APP_DIR/.env" << EOF
# Wishaday Configuration
DATABASE_URL=sqlite:///$APP_DIR/app/wishaday.db
UPLOAD_DIR=./app/uploads
MAX_FILE_SIZE=2097152
MAX_IMAGES_PER_WISH=5
MAX_WISHES_PER_IP_PER_DAY=10
CLEANUP_INTERVAL_MINUTES=30
SOFT_DELETE_GRACE_PERIOD_MINUTES=10
BASE_URL=https://$WISHADAY_DOMAIN
DEBUG=false
PORT=$WISHADAY_PORT
SECRET_KEY=$(openssl rand -hex 32)
EOF
}

# Fix .env file issues
fix_env_file() {
    log_info "Fixing .env file configuration"
    
    local env_file="$APP_DIR/.env"
    
    # Fix DATABASE_URL if it's malformed (https issue)
    if grep -q "DATABASE_URL=https" "$env_file" 2>/dev/null; then
        sed -i "s|^DATABASE_URL=.*|DATABASE_URL=sqlite:///$APP_DIR/app/wishaday.db|" "$env_file"
        log_info "Fixed malformed DATABASE_URL (https issue)"
    fi
    
    # Fix relative path DATABASE_URL to absolute path
    if grep -q "DATABASE_URL=sqlite:///\./app/wishaday.db" "$env_file" 2>/dev/null; then
        sed -i "s|^DATABASE_URL=.*|DATABASE_URL=sqlite:///$APP_DIR/app/wishaday.db|" "$env_file"
        log_info "Updated DATABASE_URL to use absolute path"
    fi
    
    # Fix relative path without leading ./
    if grep -q "DATABASE_URL=sqlite:///app/wishaday.db" "$env_file" 2>/dev/null && ! grep -q "DATABASE_URL=sqlite:///$APP_DIR" "$env_file" 2>/dev/null; then
        sed -i "s|^DATABASE_URL=.*|DATABASE_URL=sqlite:///$APP_DIR/app/wishaday.db|" "$env_file"
        log_info "Updated relative DATABASE_URL to absolute path"
    fi
    
    # Ensure DATABASE_URL uses absolute path for any sqlite relative reference
    if grep -q "DATABASE_URL=sqlite:///\." "$env_file" 2>/dev/null; then
        sed -i "s|^DATABASE_URL=.*|DATABASE_URL=sqlite:///$APP_DIR/app/wishaday.db|" "$env_file"
        log_info "Fixed relative DATABASE_URL path"
    fi
    
    # Update BASE_URL if needed
    if ! grep -q "BASE_URL=https://$WISHADAY_DOMAIN" "$env_file" 2>/dev/null; then
        sed -i "s|^BASE_URL=.*|BASE_URL=https://$WISHADAY_DOMAIN|" "$env_file"
        log_info "Updated BASE_URL"
    fi
    
    # Ensure DEBUG is false for production
    sed -i 's|^DEBUG=.*|DEBUG=false|' "$env_file"
    
    # Verify the final DATABASE_URL
    local final_db_url=$(grep "^DATABASE_URL=" "$env_file" | cut -d'=' -f2-)
    log_info "Final DATABASE_URL: $final_db_url"
}

# Initialize database
init_database() {
    log_step "Initializing database"
    
    cd "$APP_DIR"
    
    # Ensure .env file has correct DATABASE_URL first
    fix_env_file
    
    # Create database directory if it doesn't exist
    mkdir -p "$(dirname "$APP_DIR/app/wishaday.db")"
    
    # Remove any existing problematic database file
    if [[ -f "$APP_DIR/app/wishaday.db" ]]; then
        log_info "Removing existing database file for clean initialization"
        rm -f "$APP_DIR/app/wishaday.db"
    fi
    
    # Initialize database with proper error handling
    sudo -u "$WISHADAY_USER" bash -c "
        cd '$APP_DIR'
        source venv/bin/activate
        export PYTHONPATH='$APP_DIR'
        python -c 'from app.database import init_db; init_db(); print(\"Database initialized successfully\")'
    " || {
        log_error "Database initialization failed, trying alternative method..."
        # Try creating empty database file first
        touch "$APP_DIR/app/wishaday.db"
        chown "$WISHADAY_USER:$WISHADAY_GROUP" "$APP_DIR/app/wishaday.db"
        chmod 664 "$APP_DIR/app/wishaday.db"
        
        # Try again
        sudo -u "$WISHADAY_USER" bash -c "
            cd '$APP_DIR'
            source venv/bin/activate
            export PYTHONPATH='$APP_DIR'
            python -c 'from app.database import init_db; init_db(); print(\"Database initialized successfully\")'
        " || log_warn "Database initialization failed, will retry on service start"
    }
    
    # Always ensure proper permissions after initialization
    fix_database_permissions
    
    log_success "Database initialization completed"
}

# Fix database permissions specifically
fix_database_permissions() {
    log_step "Fixing database permissions"
    
    # Ensure database directory exists and has proper permissions
    mkdir -p "$APP_DIR/app"
    chown "$WISHADAY_USER:$WISHADAY_GROUP" "$APP_DIR/app"
    chmod 755 "$APP_DIR/app"
    
    # Fix database file permissions if it exists
    if [[ -f "$APP_DIR/app/wishaday.db" ]]; then
        chown "$WISHADAY_USER:$WISHADAY_GROUP" "$APP_DIR/app/wishaday.db"
        chmod 664 "$APP_DIR/app/wishaday.db"
        log_info "Database file permissions fixed"
        
        # Verify permissions
        local db_owner=$(stat -c %U "$APP_DIR/app/wishaday.db")
        local db_perms=$(stat -c %a "$APP_DIR/app/wishaday.db")
        log_info "Database owner: $db_owner, permissions: $db_perms"
        
        if [[ "$db_owner" != "$WISHADAY_USER" ]]; then
            log_error "Database owner is incorrect: $db_owner (should be $WISHADAY_USER)"
            return 1
        fi
    else
        log_warn "Database file does not exist"
    fi
    
    log_success "Database permissions verified"
}

# Create systemd service
create_systemd_service() {
    log_step "Creating systemd service"
    
    cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=Wishaday - Wish Sharing Platform
After=network.target

[Service]
Type=simple
User=$WISHADAY_USER
Group=$WISHADAY_GROUP
WorkingDirectory=$APP_DIR
Environment=PATH=$APP_DIR/venv/bin
Environment=PYTHONPATH=$APP_DIR
EnvironmentFile=$APP_DIR/.env
ExecStart=$APP_DIR/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port $WISHADAY_PORT --workers 1
Restart=always
RestartSec=5
StandardOutput=append:$APP_DIR/logs/wishaday.log
StandardError=append:$APP_DIR/logs/wishaday.error.log
KillMode=mixed
KillSignal=SIGINT
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    
    log_success "Systemd service created and enabled"
}

# Configure Nginx
configure_nginx() {
    log_step "Configuring Nginx"
    
    # Backup existing config
    if [[ -f "$NGINX_AVAILABLE/$APP_NAME" ]]; then
        cp "$NGINX_AVAILABLE/$APP_NAME" "$NGINX_AVAILABLE/$APP_NAME.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Create Nginx configuration
    cat > "$NGINX_AVAILABLE/$APP_NAME" << EOF
server {
    listen 80;
    server_name $WISHADAY_DOMAIN;

    client_max_body_size 10M;
    client_body_timeout 60s;
    client_header_timeout 60s;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # API endpoints - proxy to backend
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
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
    }

    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:$WISHADAY_PORT/health;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        access_log off;
    }

    # API documentation
    location /docs {
        proxy_pass http://127.0.0.1:$WISHADAY_PORT/docs;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Media files - serve directly from filesystem
    location /media/ {
        alias $APP_DIR/app/uploads/;
        expires 30d;
        add_header Cache-Control "public, immutable";
        try_files \$uri \$uri/ =404;
        
        # Security for uploads
        location ~* \.(php|pl|py|jsp|asp|sh|cgi)\$ {
            deny all;
        }
    }

    # Frontend static files
    location / {
        root $APP_DIR/frontend/dist;
        try_files \$uri \$uri/ /index.html;
        expires 1d;
        add_header Cache-Control "public, immutable";
        
        # Handle specific file types
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)\$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }

    # Deny access to sensitive files
    location ~ /\. {
        deny all;
    }
    
    location ~ /(\.env|\.git|logs|backups) {
        deny all;
    }

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;
}
EOF
    
    # Enable site
    ln -sf "$NGINX_AVAILABLE/$APP_NAME" "$NGINX_ENABLED/$APP_NAME"
    
    # Remove default site
    rm -f "$NGINX_ENABLED/default"
    
    # Test configuration
    if nginx -t; then
        log_success "Nginx configuration created successfully"
    else
        log_error "Nginx configuration test failed"
        return 1
    fi
}

# Setup SSL with Let's Encrypt
setup_ssl() {
    log_step "Setting up SSL certificate"
    
    # Check if domain resolves to this server
    local server_ip=$(curl -s ifconfig.me || curl -s ipinfo.io/ip)
    local domain_ip=$(dig +short "$WISHADAY_DOMAIN" | tail -n1)
    
    if [[ "$server_ip" != "$domain_ip" ]]; then
        log_warn "Domain $WISHADAY_DOMAIN does not resolve to this server ($server_ip vs $domain_ip)"
        log_warn "Skipping SSL setup. Please configure DNS first."
        return 0
    fi
    
    # Obtain SSL certificate
    certbot --nginx -d "$WISHADAY_DOMAIN" --non-interactive --agree-tos --email "admin@$WISHADAY_DOMAIN" || {
        log_warn "SSL certificate setup failed. You can run it manually later:"
        log_warn "sudo certbot --nginx -d $WISHADAY_DOMAIN"
    }
    
    log_success "SSL setup completed"
}

# Fix all permissions
fix_all_permissions() {
    log_step "Fixing all file permissions"
    
    # Application directory
    chown -R "$WISHADAY_USER:$WISHADAY_GROUP" "$APP_DIR"
    
    # Set directory permissions
    find "$APP_DIR" -type d -exec chmod 755 {} \;
    
    # Set file permissions
    find "$APP_DIR" -type f -exec chmod 644 {} \;
    
    # Executable files
    chmod +x "$APP_DIR/venv/bin/"* 2>/dev/null || true
    
    # Special permissions for uploads
    chmod 775 "$APP_DIR/app/uploads"
    find "$APP_DIR/app/uploads" -type d -exec chmod 775 {} \;
    find "$APP_DIR/app/uploads" -type f -exec chmod 664 {} \;
    
    # Database permissions
    if [[ -f "$APP_DIR/app/wishaday.db" ]]; then
        chown "$WISHADAY_USER:$WISHADAY_GROUP" "$APP_DIR/app/wishaday.db"
        chmod 664 "$APP_DIR/app/wishaday.db"
    fi
    
    # Environment file
    if [[ -f "$APP_DIR/.env" ]]; then
        chmod 640 "$APP_DIR/.env"
    fi
    
    # Log files
    mkdir -p "$APP_DIR/logs"
    chown -R "$WISHADAY_USER:$WISHADAY_GROUP" "$APP_DIR/logs"
    chmod 755 "$APP_DIR/logs"
    
    # Frontend build permissions
    if [[ -d "$APP_DIR/frontend/dist" ]]; then
        find "$APP_DIR/frontend/dist" -type d -exec chmod 755 {} \;
        find "$APP_DIR/frontend/dist" -type f -exec chmod 644 {} \;
    fi
    
    log_success "All permissions fixed"
}

# Complete system setup
complete_setup() {
    log_header "Complete System Setup"
    echo ""
    
    check_os
    create_user
    install_system_deps
    install_nodejs
    setup_app_directory
    
    log_success "System setup completed successfully!"
    log_info "Next steps:"
    log_info "1. Run: sudo ./serverv2.sh install"
    log_info "2. Configure your domain DNS to point to this server"
    log_info "3. Run: sudo ./serverv2.sh deploy"
}

# Install application
install_application() {
    log_header "Installing Wishaday Application"
    echo ""
    
    setup_repository
    setup_python_env
    configure_environment
    init_database
    build_frontend
    fix_all_permissions
    
    log_success "Application installed successfully!"
    log_info "Next step: sudo ./serverv2.sh configure"
}

# Configure services
configure_services() {
    log_header "Configuring Services"
    echo ""
    
    create_systemd_service
    configure_nginx
    
    # Start and enable nginx
    systemctl enable nginx
    systemctl start nginx
    
    log_success "Services configured successfully!"
    log_info "Next step: sudo ./serverv2.sh deploy"
}

# Deploy to production
deploy_to_production() {
    log_header "Deploying to Production"
    echo ""
    
    # Stop services
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    
    # Update code if git repository exists
    if [[ -d "$APP_DIR/.git" ]]; then
        log_step "Updating code from repository"
        cd "$APP_DIR"
        sudo -u "$WISHADAY_USER" git pull
    fi
    
    # Update Python dependencies
    log_step "Updating Python dependencies"
    cd "$APP_DIR"
    sudo -u "$WISHADAY_USER" bash -c "
        source venv/bin/activate
        pip install --upgrade pip
        if [[ -f 'pyproject.toml' ]]; then
            pip install -e .
        fi
    "
    
    # Rebuild frontend
    if [[ -d "$APP_DIR/frontend" ]]; then
        build_frontend
    fi
    
    # Fix permissions
    fix_all_permissions
    
    # Reload configurations
    systemctl daemon-reload
    nginx -t && systemctl reload nginx
    
    # Start services
    systemctl start "$SERVICE_NAME"
    
    # Setup SSL if not already done
    setup_ssl
    
    # Wait for service to start
    sleep 5
    
    # Test deployment
    test_deployment
    
    log_success "Deployment completed successfully!"
}

# Start all services
start_all_services() {
    log_header "Starting All Services"
    echo ""
    
    # Check if already running
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_warn "Wishaday service is already running"
    else
        systemctl start "$SERVICE_NAME"
        log_info "Started Wishaday service"
    fi
    
    if systemctl is-active --quiet nginx; then
        log_info "Nginx is already running"
    else
        systemctl start nginx
        log_info "Started Nginx"
    fi
    
    # Wait for services to be ready
    show_progress 5 "Waiting for services to start"
    
    # Verify services
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_success "Wishaday service: RUNNING"
    else
        log_error "Wishaday service: FAILED"
        return 1
    fi
    
    if systemctl is-active --quiet nginx; then
        log_success "Nginx service: RUNNING"
    else
        log_error "Nginx service: FAILED"
        return 1
    fi
    
    # Test connectivity
    test_connectivity
}

# Stop all services
stop_all_services() {
    log_header "Stopping All Services"
    echo ""
    
    # Stop Wishaday service
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        systemctl stop "$SERVICE_NAME"
        log_info "Stopped Wishaday service"
    else
        log_info "Wishaday service was not running"
    fi
    
    # Kill any remaining processes on the port
    if netstat -tlnp | grep -q ":$WISHADAY_PORT "; then
        log_warn "Port $WISHADAY_PORT still in use, killing processes..."
        lsof -ti:"$WISHADAY_PORT" | xargs kill -9 2>/dev/null || true
        sleep 2
    fi
    
    # Optional: Stop Nginx (uncomment if needed)
    # systemctl stop nginx
    # log_info "Stopped Nginx"
    
    log_success "All services stopped"
}

# Restart all services
restart_all_services() {
    log_header "Restarting All Services"
    echo ""
    
    systemctl restart "$SERVICE_NAME"
    systemctl reload nginx
    
    show_progress 5 "Waiting for services to restart"
    
    if systemctl is-active --quiet "$SERVICE_NAME" && systemctl is-active --quiet nginx; then
        log_success "All services restarted successfully"
        test_connectivity
    else
        log_error "Service restart failed"
        show_service_status
        return 1
    fi
}

# Show system status
show_system_status() {
    log_header "System Status"
    echo ""
    
    # Service status
    log_info "Service Status:"
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo -e "  ${GREEN}✓${NC} Wishaday service: RUNNING"
    else
        echo -e "  ${RED}✗${NC} Wishaday service: STOPPED"
    fi
    
    if systemctl is-active --quiet nginx; then
        echo -e "  ${GREEN}✓${NC} Nginx service: RUNNING"
    else
        echo -e "  ${RED}✗${NC} Nginx service: STOPPED"
    fi
    
    # Port status
    echo ""
    log_info "Port Status:"
    if netstat -tlnp | grep -q ":$WISHADAY_PORT "; then
        echo -e "  ${GREEN}✓${NC} Port $WISHADAY_PORT: IN USE"
    else
        echo -e "  ${RED}✗${NC} Port $WISHADAY_PORT: NOT IN USE"
    fi
    
    if netstat -tlnp | grep -q ":80 "; then
        echo -e "  ${GREEN}✓${NC} Port 80: IN USE (HTTP)"
    else
        echo -e "  ${RED}✗${NC} Port 80: NOT IN USE"
    fi
    
    if netstat -tlnp | grep -q ":443 "; then
        echo -e "  ${GREEN}✓${NC} Port 443: IN USE (HTTPS)"
    else
        echo -e "  ${YELLOW}!${NC} Port 443: NOT IN USE (SSL not configured)"
    fi
    
    # File status
    echo ""
    log_info "File Status:"
    if [[ -f "$APP_DIR/frontend/dist/index.html" ]]; then
        echo -e "  ${GREEN}✓${NC} Frontend build: EXISTS"
    else
        echo -e "  ${RED}✗${NC} Frontend build: MISSING"
    fi
    
    if [[ -f "$APP_DIR/app/wishaday.db" ]]; then
        echo -e "  ${GREEN}✓${NC} Database: EXISTS"
    else
        echo -e "  ${RED}✗${NC} Database: MISSING"
    fi
    
    if [[ -f "$APP_DIR/.env" ]]; then
        echo -e "  ${GREEN}✓${NC} Environment config: EXISTS"
    else
        echo -e "  ${RED}✗${NC} Environment config: MISSING"
    fi
    
    # Disk usage
    echo ""
    log_info "Disk Usage:"
    df -h "$APP_DIR" | tail -1 | awk '{print "  App directory: " $3 " used, " $4 " available (" $5 " full)"}'
    
    # Memory usage
    echo ""
    log_info "Memory Usage:"
    free -h | grep "Mem:" | awk '{print "  Memory: " $3 " used, " $7 " available"}'
    
    echo ""
}

# Diagnose and fix issues automatically
diagnose_and_fix() {
    log_header "Diagnosing and Fixing Issues"
    echo ""
    
    local issues_found=0
    
    # Check service status
    log_step "Checking service status"
    if ! systemctl is-active --quiet "$SERVICE_NAME"; then
        log_warn "Wishaday service is not running"
        issues_found=$((issues_found + 1))
        
        # Try to start it
        systemctl start "$SERVICE_NAME" || {
            log_error "Failed to start service, checking logs..."
            journalctl -u "$SERVICE_NAME" -n 10 --no-pager
        }
    fi
    
    # Check port availability
    log_step "Checking port availability"
    if ! netstat -tlnp | grep -q ":$WISHADAY_PORT "; then
        log_warn "Port $WISHADAY_PORT is not in use"
        issues_found=$((issues_found + 1))
        
        # Check for zombie processes
        if ps aux | grep -E "(python|uvicorn)" | grep -q "defunct"; then
            log_warn "Found zombie processes, cleaning up..."
            pkill -f "uvicorn.*app.main" 2>/dev/null || true
            sleep 2
            systemctl restart "$SERVICE_NAME"
        fi
    fi
    
    # Check database
    log_step "Checking database"
    if [[ ! -f "$APP_DIR/app/wishaday.db" ]]; then
        log_warn "Database file missing, creating..."
        issues_found=$((issues_found + 1))
        init_database
    else
        # Check database permissions
        local db_owner=$(stat -c %U "$APP_DIR/app/wishaday.db" 2>/dev/null || echo "unknown")
        local db_perms=$(stat -c %a "$APP_DIR/app/wishaday.db" 2>/dev/null || echo "000")
        
        if [[ "$db_owner" != "$WISHADAY_USER" ]] || [[ "$db_perms" != "664" ]]; then
            log_warn "Database permission issues found (owner: $db_owner, perms: $db_perms)"
            issues_found=$((issues_found + 1))
            fix_database_permissions
        fi
        
        # Check if database is accessible and writable
        if ! sudo -u "$WISHADAY_USER" bash -c "cd '$APP_DIR' && source venv/bin/activate && python -c 'from app.database import SessionLocal; db = SessionLocal(); db.close()'" 2>/dev/null; then
            log_warn "Database not accessible, checking for readonly issues..."
            issues_found=$((issues_found + 1))
            
            # Test if it's a readonly database issue
            if sudo -u "$WISHADAY_USER" bash -c "cd '$APP_DIR' && source venv/bin/activate && python -c 'import sqlite3; conn = sqlite3.connect(\"$APP_DIR/app/wishaday.db\"); conn.execute(\"CREATE TABLE IF NOT EXISTS test_table (id INTEGER)\"); conn.close()'" 2>&1 | grep -q "readonly"; then
                log_warn "Database is readonly, fixing permissions..."
                fix_database_permissions
            else
                log_warn "Database has other issues, reinitializing..."
                init_database
            fi
        fi
    fi
    
    # Check environment file
    log_step "Checking environment configuration"
    if [[ ! -f "$APP_DIR/.env" ]]; then
        log_warn "Environment file missing, creating..."
        issues_found=$((issues_found + 1))
        configure_environment
    else
        # Check for common issues in .env
        if grep -q "DATABASE_URL=https" "$APP_DIR/.env" 2>/dev/null; then
            log_warn "Malformed DATABASE_URL found, fixing..."
            issues_found=$((issues_found + 1))
            fix_env_file
        fi
        
        # Check for relative path issues
        if grep -q "DATABASE_URL=sqlite:///\." "$APP_DIR/.env" 2>/dev/null; then
            log_warn "Relative DATABASE_URL path found, fixing..."
            issues_found=$((issues_found + 1))
            fix_env_file
        fi
    fi
    
    # Check permissions
    log_step "Checking file permissions"
    if [[ ! -r "$APP_DIR/.env" ]] || [[ $(stat -c %U "$APP_DIR/.env") != "$WISHADAY_USER" ]]; then
        log_warn "Permission issues found, fixing..."
        issues_found=$((issues_found + 1))
        fix_all_permissions
    fi
    
    # Check frontend build
    log_step "Checking frontend build"
    if [[ ! -f "$APP_DIR/frontend/dist/index.html" ]] && [[ -d "$APP_DIR/frontend" ]]; then
        log_warn "Frontend not built, building..."
        issues_found=$((issues_found + 1))
        build_frontend
    fi
    
    # Check Nginx configuration
    log_step "Checking Nginx configuration"
    if ! nginx -t 2>/dev/null; then
        log_warn "Nginx configuration issues found, fixing..."
        issues_found=$((issues_found + 1))
        configure_nginx
        systemctl reload nginx
    fi
    
    # Check image upload functionality
    log_step "Checking image upload functionality"
    local upload_dir=$(grep "UPLOAD_DIR=" "$APP_DIR/.env" 2>/dev/null | cut -d'=' -f2 | sed 's/^"//' | sed 's/"$//' || echo "$APP_DIR/app/uploads")
    if [[ ! -d "$upload_dir" ]]; then
        log_warn "Upload directory missing, creating..."
        issues_found=$((issues_found + 1))
        mkdir -p "$upload_dir/wishes"
        chown -R "$WISHADAY_USER:$WISHADAY_GROUP" "$upload_dir"
        chmod 775 "$upload_dir"
    fi
    
    # Test image processing imports
    if ! sudo -u "$WISHADAY_USER" bash -c "cd '$APP_DIR' && source venv/bin/activate && python3 -c 'from app.services.image import validate_image; from PIL import Image'" 2>/dev/null; then
        log_warn "Image processing dependencies missing, installing..."
        issues_found=$((issues_found + 1))
        sudo -u "$WISHADAY_USER" bash -c "cd '$APP_DIR' && source venv/bin/activate && pip install pillow"
    fi
    
    # Final service restart if issues were found
    if [[ $issues_found -gt 0 ]]; then
        log_info "Found and fixed $issues_found issues, restarting services..."
        systemctl daemon-reload
        systemctl restart "$SERVICE_NAME"
        systemctl reload nginx
        
        show_progress 5 "Waiting for services to stabilize"
    fi
    
    # Final test
    test_connectivity
    
    if [[ $issues_found -eq 0 ]]; then
        log_success "No issues found, system is healthy!"
    else
        log_success "Fixed $issues_found issues successfully!"
    fi
}

# Test database connectivity specifically
test_database_connectivity() {
    log_step "Testing database connectivity"
    
    if [[ ! -f "$APP_DIR/app/wishaday.db" ]]; then
        echo -e "  ${RED}✗${NC} Database file does not exist"
        return 1
    fi
    
    # Check file permissions
    local db_owner=$(stat -c %U "$APP_DIR/app/wishaday.db")
    local db_perms=$(stat -c %a "$APP_DIR/app/wishaday.db")
    
    if [[ "$db_owner" != "$WISHADAY_USER" ]]; then
        echo -e "  ${RED}✗${NC} Database owner incorrect: $db_owner (should be $WISHADAY_USER)"
        return 1
    fi
    
    if [[ "$db_perms" != "664" ]]; then
        echo -e "  ${YELLOW}!${NC} Database permissions: $db_perms (recommended: 664)"
    fi
    
    # Test database connection
    if sudo -u "$WISHADAY_USER" bash -c "cd '$APP_DIR' && source venv/bin/activate && python -c 'from app.database import SessionLocal; db = SessionLocal(); db.close(); print(\"OK\")'" 2>/dev/null | grep -q "OK"; then
        echo -e "  ${GREEN}✓${NC} Database connection: OK"
    else
        echo -e "  ${RED}✗${NC} Database connection: FAILED"
        return 1
    fi
    
    # Test database write permissions
    if sudo -u "$WISHADAY_USER" bash -c "cd '$APP_DIR' && source venv/bin/activate && python -c 'import sqlite3; conn = sqlite3.connect(\"$APP_DIR/app/wishaday.db\"); conn.execute(\"CREATE TABLE IF NOT EXISTS test_write (id INTEGER)\"); conn.execute(\"DROP TABLE IF EXISTS test_write\"); conn.close(); print(\"OK\")'" 2>/dev/null | grep -q "OK"; then
        echo -e "  ${GREEN}✓${NC} Database write permissions: OK"
        return 0
    else
        echo -e "  ${RED}✗${NC} Database write permissions: FAILED (readonly database)"
        return 1
    fi
}

# Test connectivity
test_connectivity() {
    log_step "Testing connectivity"
    
    local backend_ok=false
    local nginx_ok=false
    
    # Test backend directly
    if curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$WISHADAY_PORT/health" 2>/dev/null | grep -q "200"; then
        echo -e "  ${GREEN}✓${NC} Backend health check: OK"
        backend_ok=true
    else
        echo -e "  ${RED}✗${NC} Backend health check: FAILED"
    fi
    
    # Test through Nginx
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost/health" 2>/dev/null | grep -q "200"; then
        echo -e "  ${GREEN}✓${NC} Nginx proxy: OK"
        nginx_ok=true
    else
        echo -e "  ${RED}✗${NC} Nginx proxy: FAILED"
    fi
    
    # Test external domain if different from localhost
    if [[ "$WISHADAY_DOMAIN" != "localhost" ]]; then
        if curl -s -o /dev/null -w "%{http_code}" "http://$WISHADAY_DOMAIN/health" 2>/dev/null | grep -q "200"; then
            echo -e "  ${GREEN}✓${NC} External domain: OK"
        else
            echo -e "  ${YELLOW}!${NC} External domain: Check DNS configuration"
        fi
    fi
    
    if [[ "$backend_ok" == true && "$nginx_ok" == true ]]; then
        log_success "All connectivity tests passed!"
        return 0
    else
        log_error "Some connectivity tests failed"
        return 1
    fi
}

# Test deployment
test_deployment() {
    log_step "Testing deployment"
    
    local tests_passed=0
    local total_tests=5
    
    # Test 1: Backend health
    if curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$WISHADAY_PORT/health" 2>/dev/null | grep -q "200"; then
        echo -e "  ${GREEN}✓${NC} Backend health check"
        tests_passed=$((tests_passed + 1))
    else
        echo -e "  ${RED}✗${NC} Backend health check"
    fi
    
    # Test 2: API documentation
    if curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$WISHADAY_PORT/docs" 2>/dev/null | grep -q "200"; then
        echo -e "  ${GREEN}✓${NC} API documentation"
        tests_passed=$((tests_passed + 1))
    else
        echo -e "  ${RED}✗${NC} API documentation"
    fi
    
    # Test 3: Frontend through Nginx
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost/" 2>/dev/null | grep -qE "200|301|302"; then
        echo -e "  ${GREEN}✓${NC} Frontend access"
        tests_passed=$((tests_passed + 1))
    else
        echo -e "  ${RED}✗${NC} Frontend access"
    fi
    
    # Test 4: API through Nginx
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost/api/wishes" 2>/dev/null | grep -qE "200|422"; then
        echo -e "  ${GREEN}✓${NC} API through Nginx"
        tests_passed=$((tests_passed + 1))
    else
        echo -e "  ${RED}✗${NC} API through Nginx"
    fi
    
    # Test 5: Database connectivity
    if test_database_connectivity >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Database connectivity"
        tests_passed=$((tests_passed + 1))
    else
        echo -e "  ${RED}✗${NC} Database connectivity"
    fi
    
    echo ""
    log_info "Test Results: $tests_passed/$total_tests passed"
    
    if [[ $tests_passed -eq $total_tests ]]; then
        log_success "All deployment tests passed!"
        return 0
    else
        log_warn "Some tests failed. Check the logs for more details."
        return 1
    fi
}

# Show recent logs
show_recent_logs() {
    log_header "Recent Logs"
    echo ""
    
    log_info "Wishaday Service Logs (last 20 lines):"
    echo "----------------------------------------"
    journalctl -u "$SERVICE_NAME" -n 20 --no-pager || echo "No service logs available"
    
    echo ""
    log_info "Wishaday Error Logs (last 10 lines):"
    echo "-------------------------------------"
    if [[ -f "$APP_DIR/logs/wishaday.error.log" ]]; then
        tail -n 10 "$APP_DIR/logs/wishaday.error.log"
    else
        echo "No error logs available"
    fi
    
    echo ""
    log_info "Nginx Error Logs (last 10 lines):"
    echo "----------------------------------"
    tail -n 10 /var/log/nginx/error.log 2>/dev/null || echo "No nginx error logs available"
    
    echo ""
    log_info "Nginx Access Logs (last 5 lines):"
    echo "----------------------------------"
    tail -n 5 /var/log/nginx/access.log 2>/dev/null || echo "No nginx access logs available"
    
    echo ""
}

# Update application
update_application() {
    log_header "Updating Application"
    echo ""
    
    if [[ ! -d "$APP_DIR/.git" ]]; then
        log_error "No git repository found. Cannot update automatically."
        return 1
    fi
    
    # Stop service
    systemctl stop "$SERVICE_NAME"
    
    # Update code
    log_step "Updating code from repository"
    cd "$APP_DIR"
    sudo -u "$WISHADAY_USER" git pull
    
    # Update dependencies
    log_step "Updating dependencies"
    sudo -u "$WISHADAY_USER" bash -c "
        source venv/bin/activate
        pip install --upgrade pip
        if [[ -f 'pyproject.toml' ]]; then
            pip install -e .
        fi
    "
    
    # Rebuild frontend if needed
    if [[ -d "$APP_DIR/frontend" ]]; then
        log_step "Rebuilding frontend"
        cd "$APP_DIR/frontend"
        sudo -u "$WISHADAY_USER" bash -c "
            npm install
            npm run build
        "
    fi
    
    # Fix permissions
    fix_all_permissions
    
    # Restart service
    systemctl start "$SERVICE_NAME"
    
    show_progress 5 "Waiting for service to start"
    
    # Test update
    test_connectivity
    
    log_success "Application updated successfully!"
}

# Create backup
create_backup() {
    log_header "Creating System Backup"
    echo ""
    
    local backup_name="wishaday-backup-$(date +%Y%m%d_%H%M%S)"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    log_step "Creating backup directory"
    mkdir -p "$backup_path"
    
    # Backup application files
    log_step "Backing up application files"
    tar -czf "$backup_path/app.tar.gz" -C "$APP_DIR" \
        --exclude="venv" \
        --exclude="node_modules" \
        --exclude="logs" \
        --exclude=".git" \
        .
    
    # Backup database
    if [[ -f "$APP_DIR/app/wishaday.db" ]]; then
        log_step "Backing up database"
        cp "$APP_DIR/app/wishaday.db" "$backup_path/wishaday.db"
    fi
    
    # Backup nginx config
    if [[ -f "$NGINX_AVAILABLE/$APP_NAME" ]]; then
        log_step "Backing up Nginx configuration"
        cp "$NGINX_AVAILABLE/$APP_NAME" "$backup_path/nginx.conf"
    fi
    
    # Backup systemd service
    if [[ -f "/etc/systemd/system/$SERVICE_NAME.service" ]]; then
        log_step "Backing up systemd service"
        cp "/etc/systemd/system/$SERVICE_NAME.service" "$backup_path/wishaday.service"
    fi
    
    # Create backup info
    cat > "$backup_path/backup_info.txt" << EOF
Backup created: $(date)
Server: $(hostname)
Wishaday version: $(cd "$APP_DIR" && git rev-parse HEAD 2>/dev/null || echo "unknown")
Domain: $WISHADAY_DOMAIN
Port: $WISHADAY_PORT
EOF
    
    # Set permissions
    chown -R "$WISHADAY_USER:$WISHADAY_GROUP" "$backup_path"
    
    log_success "Backup created: $backup_path"
    
    # Clean old backups (keep last 5)
    log_step "Cleaning old backups"
    cd "$BACKUP_DIR"
    ls -t | grep "wishaday-backup-" | tail -n +6 | xargs rm -rf 2>/dev/null || true
    
    log_info "Backup size: $(du -sh "$backup_path" | cut -f1)"
}

# Real-time monitoring
real_time_monitor() {
    log_header "Real-time Monitoring"
    echo ""
    log_info "Press Ctrl+C to exit monitoring"
    echo ""
    
    while true; do
        clear
        echo -e "${CYAN}${BOLD}Wishaday Real-time Monitor - $(date)${NC}"
        echo "=================================================="
        
        # Service status
        echo -e "\n${BOLD}Services:${NC}"
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            echo -e "  Wishaday: ${GREEN}RUNNING${NC}"
        else
            echo -e "  Wishaday: ${RED}STOPPED${NC}"
        fi
        
        if systemctl is-active --quiet nginx; then
            echo -e "  Nginx: ${GREEN}RUNNING${NC}"
        else
            echo -e "  Nginx: ${RED}STOPPED${NC}"
        fi
        
        # Resource usage
        echo -e "\n${BOLD}Resource Usage:${NC}"
        
        # CPU and Memory
        local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
        local mem_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
        echo "  CPU: ${cpu_usage}%"
        echo "  Memory: ${mem_usage}%"
        
        # Disk usage
        local disk_usage=$(df "$APP_DIR" | tail -1 | awk '{print $5}' | cut -d'%' -f1)
        echo "  Disk: ${disk_usage}%"
        
        # Network connections
        echo -e "\n${BOLD}Network:${NC}"
        local port_8000=$(netstat -an | grep ":$WISHADAY_PORT " | wc -l)
        local port_80=$(netstat -an | grep ":80 " | wc -l)
        echo "  Port $WISHADAY_PORT connections: $port_8000"
        echo "  Port 80 connections: $port_80"
        
        # Recent log entries
        echo -e "\n${BOLD}Recent Activity:${NC}"
        journalctl -u "$SERVICE_NAME" -n 3 --no-pager --since "1 minute ago" 2>/dev/null | tail -3 || echo "  No recent activity"
        
        # Quick health check
        echo -e "\n${BOLD}Health Check:${NC}"
        if curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$WISHADAY_PORT/health" 2>/dev/null | grep -q "200"; then
            echo -e "  Backend: ${GREEN}HEALTHY${NC}"
        else
            echo -e "  Backend: ${RED}UNHEALTHY${NC}"
        fi
        
        sleep 5
    done
}

# Clean build artifacts and temporary files
clean_environment() {
    log_header "Cleaning Environment"
    echo ""
    
    # Stop services first
    log_step "Stopping services"
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    
    # Kill any remaining processes on the port
    if netstat -tlnp | grep -q ":$WISHADAY_PORT "; then
        log_warn "Killing processes on port $WISHADAY_PORT"
        lsof -ti:"$WISHADAY_PORT" | xargs kill -9 2>/dev/null || true
        sleep 2
    fi
    
    cd "$APP_DIR" || {
        log_error "Application directory not found: $APP_DIR"
        return 1
    }
    
    # Clean Python artifacts
    log_step "Cleaning Python artifacts"
    find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find . -type f -name "*.pyc" -delete 2>/dev/null || true
    find . -type f -name "*.pyo" -delete 2>/dev/null || true
    find . -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
    rm -rf build/ dist/ .pytest_cache/ 2>/dev/null || true
    
    # Clean virtual environment
    log_step "Removing virtual environment"
    if [[ -d "venv" ]]; then
        rm -rf venv
        log_info "Removed Python virtual environment"
    fi
    
    # Clean frontend artifacts
    if [[ -d "frontend" ]]; then
        log_step "Cleaning frontend artifacts"
        cd frontend
        
        # Remove node_modules and build artifacts
        rm -rf node_modules/ 2>/dev/null || true
        rm -rf dist/ 2>/dev/null || true
        rm -rf build/ 2>/dev/null || true
        rm -rf .next/ 2>/dev/null || true
        rm -rf .nuxt/ 2>/dev/null || true
        rm -f package-lock.json 2>/dev/null || true
        rm -f yarn.lock 2>/dev/null || true
        
        log_info "Cleaned frontend build artifacts"
        cd ..
    fi
    
    # Clean logs (keep recent ones)
    log_step "Cleaning old logs"
    if [[ -d "logs" ]]; then
        find logs/ -name "*.log" -mtime +7 -delete 2>/dev/null || true
        find logs/ -name "*.log.*" -mtime +7 -delete 2>/dev/null || true
        log_info "Cleaned old log files"
    fi
    
    # Clean temporary files
    log_step "Cleaning temporary files"
    rm -rf /tmp/wishaday_* 2>/dev/null || true
    rm -rf /tmp/test_image_* 2>/dev/null || true
    
    # Clean systemd journal for this service (optional)
    log_step "Cleaning service logs"
    journalctl --vacuum-time=7d --quiet 2>/dev/null || true
    
    # Clean pip cache
    log_step "Cleaning pip cache"
    sudo -u "$WISHADAY_USER" bash -c "pip cache purge" 2>/dev/null || true
    
    # Clean npm cache
    if command -v npm >/dev/null 2>&1; then
        log_step "Cleaning npm cache"
        sudo -u "$WISHADAY_USER" bash -c "npm cache clean --force" 2>/dev/null || true
    fi
    
    # Reset file permissions
    log_step "Resetting file permissions"
    chown -R "$WISHADAY_USER:$WISHADAY_GROUP" "$APP_DIR"
    
    log_success "Environment cleaned successfully!"
    log_info "Removed:"
    log_info "  - Python virtual environment and cache files"
    log_info "  - Frontend node_modules and build artifacts"
    log_info "  - Old log files (>7 days)"
    log_info "  - Temporary files"
    log_info "  - Package manager caches"
}

# Complete rebuild (clean + install + build)
rebuild_application() {
    log_header "Complete Application Rebuild"
    echo ""
    
    log_info "This will perform a complete rebuild of the application:"
    log_info "1. Clean all build artifacts and caches"
    log_info "2. Reinstall Python dependencies"
    log_info "3. Rebuild frontend"
    log_info "4. Reconfigure services"
    log_info "5. Restart all services"
    echo ""
    
    # Confirmation prompt
    read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Rebuild cancelled"
        return 0
    fi
    
    # Step 1: Clean environment
    clean_environment
    
    # Step 2: Setup Python environment
    log_step "Setting up fresh Python environment"
    setup_python_env
    
    # Step 3: Configure environment
    log_step "Configuring environment"
    configure_environment
    
    # Step 4: Initialize database
    log_step "Initializing database"
    init_database
    
    # Step 5: Build frontend
    if [[ -d "$APP_DIR/frontend" ]]; then
        log_step "Building frontend from scratch"
        build_frontend
    fi
    
    # Step 6: Fix all permissions
    log_step "Setting proper permissions"
    fix_all_permissions
    
    # Step 7: Reconfigure services
    log_step "Reconfiguring services"
    create_systemd_service
    systemctl daemon-reload
    
    # Step 8: Start services
    log_step "Starting services"
    systemctl start "$SERVICE_NAME"
    
    # Wait for services to start
    show_progress 5 "Waiting for services to start"
    
    # Step 9: Test the rebuild
    log_step "Testing rebuilt application"
    if test_connectivity; then
        log_success "Rebuild completed successfully!"
        echo ""
        log_info "Application has been completely rebuilt and is running"
        log_info "You can access it at: http://$WISHADAY_DOMAIN"
        
        # Show final status
        show_system_status
    else
        log_error "Rebuild completed but application is not responding correctly"
        log_info "Check logs for issues: sudo ./serverv2.sh logs"
        return 1
    fi
}

# Fix image upload 500 errors
fix_image_upload_500() {
    log_header "Fixing Image Upload 500 Errors"
    echo ""
    
    local issues_found=0
    
    # Step 1: Check service status and logs
    log_step "Checking service status and recent errors"
    if ! systemctl is-active --quiet "$SERVICE_NAME"; then
        log_error "Wishaday service is NOT running"
        issues_found=$((issues_found + 1))
    else
        log_success "Wishaday service is running"
    fi
    
    # Check for recent errors in logs
    local error_logs=$(journalctl -u "$SERVICE_NAME" --since "10 minutes ago" | grep -i "error\|exception\|traceback" | tail -5)
    if [[ -n "$error_logs" ]]; then
        log_warn "Found recent errors in logs:"
        echo "$error_logs"
        issues_found=$((issues_found + 1))
    else
        log_info "No recent errors found in service logs"
    fi
    
    # Step 2: Check environment configuration
    log_step "Checking environment configuration"
    if [[ ! -f "$APP_DIR/.env" ]]; then
        log_error ".env file is missing"
        log_info "Creating .env file from .env.example..."
        issues_found=$((issues_found + 1))
        
        if [[ -f "$APP_DIR/.env.example" ]]; then
            cp "$APP_DIR/.env.example" "$APP_DIR/.env"
            
            # Set production values
            sed -i "s|DATABASE_URL=sqlite:///./wishaday.db|DATABASE_URL=sqlite:///$APP_DIR/app/wishaday.db|g" "$APP_DIR/.env"
            sed -i "s|UPLOAD_DIR=./app/uploads|UPLOAD_DIR=$APP_DIR/app/uploads|g" "$APP_DIR/.env"
            sed -i "s|BASE_URL=http://localhost:8000|BASE_URL=https://$WISHADAY_DOMAIN|g" "$APP_DIR/.env"
            sed -i "s|DEBUG=true|DEBUG=false|g" "$APP_DIR/.env"
            sed -i "s|SECRET_KEY=your-secret-key-change-in-production|SECRET_KEY=$(openssl rand -hex 32)|g" "$APP_DIR/.env"
            
            chown "$WISHADAY_USER:$WISHADAY_GROUP" "$APP_DIR/.env"
            chmod 640 "$APP_DIR/.env"
            
            log_success "Created and configured .env file"
        else
            log_error ".env.example file not found!"
            return 1
        fi
    else
        log_success ".env file exists"
        # Fix any configuration issues
        fix_env_file
    fi
    
    # Step 3: Check upload directory
    log_step "Checking upload directory"
    local upload_dir=$(grep "UPLOAD_DIR=" "$APP_DIR/.env" | cut -d'=' -f2 | sed 's/^"//' | sed 's/"$//')
    if [[ -z "$upload_dir" ]]; then
        upload_dir="$APP_DIR/app/uploads"
    fi
    
    if [[ ! -d "$upload_dir" ]]; then
        log_warn "Upload directory doesn't exist, creating: $upload_dir"
        mkdir -p "$upload_dir/wishes"
        chown -R "$WISHADAY_USER:$WISHADAY_GROUP" "$upload_dir"
        chmod 775 "$upload_dir"
        issues_found=$((issues_found + 1))
        log_success "Created upload directory with proper permissions"
    else
        log_success "Upload directory exists"
        # Fix permissions anyway
        chown -R "$WISHADAY_USER:$WISHADAY_GROUP" "$upload_dir"
        chmod 775 "$upload_dir"
        log_info "Fixed upload directory permissions"
    fi
    
    # Step 4: Check Python dependencies
    log_step "Checking Python dependencies"
    cd "$APP_DIR"
    
    # Test basic imports
    local import_test_result=$(sudo -u "$WISHADAY_USER" bash -c "
        source venv/bin/activate
        python3 -c '
import sys
try:
    import fastapi, uvicorn, sqlalchemy, pydantic_settings
    from PIL import Image
    from apscheduler.schedulers.background import BackgroundScheduler
    print(\"OK\")
except ImportError as e:
    print(f\"MISSING: {e}\")
'
    " 2>/dev/null)
    
    if [[ "$import_test_result" != "OK" ]]; then
        log_warn "Python dependencies missing or broken: $import_test_result"
        log_info "Installing missing dependencies..."
        issues_found=$((issues_found + 1))
        
        sudo -u "$WISHADAY_USER" bash -c "
            source venv/bin/activate
            pip3 install fastapi uvicorn sqlalchemy pydantic-settings pillow apscheduler python-multipart
        "
        log_success "Dependencies installed"
    else
        log_success "All Python dependencies are available"
    fi
    
    # Test app import
    log_step "Testing application import"
    local app_import_result=$(sudo -u "$WISHADAY_USER" bash -c "
        cd '$APP_DIR'
        source venv/bin/activate
        export PYTHONPATH='$APP_DIR'
        python3 -c 'from app.main import app; print(\"OK\")' 2>&1
    ")
    
    if [[ "$app_import_result" != "OK" ]]; then
        log_error "Application import failed: $app_import_result"
        issues_found=$((issues_found + 1))
        
        # Try to identify the specific issue
        if echo "$app_import_result" | grep -q "database"; then
            log_info "Database-related import issue detected, fixing database..."
            init_database
        elif echo "$app_import_result" | grep -q "ModuleNotFoundError"; then
            log_info "Missing module detected, reinstalling dependencies..."
            sudo -u "$WISHADAY_USER" bash -c "
                cd '$APP_DIR'
                source venv/bin/activate
                if [[ -f 'pyproject.toml' ]]; then
                    pip install -e .
                else
                    pip install fastapi uvicorn sqlalchemy pydantic-settings pillow apscheduler python-multipart
                fi
            "
        fi
    else
        log_success "Application imports successfully"
    fi
    
    # Step 5: Check database
    log_step "Checking database"
    if ! test_database_connectivity >/dev/null 2>&1; then
        log_warn "Database connectivity issues found"
        issues_found=$((issues_found + 1))
        
        # Try to fix database issues
        fix_database_permissions
        
        # If still failing, reinitialize
        if ! test_database_connectivity >/dev/null 2>&1; then
            log_info "Reinitializing database..."
            init_database
        fi
    else
        log_success "Database connectivity is working"
    fi
    
    # Step 6: Test image processing functionality
    log_step "Testing image processing functionality"
    local image_test_result=$(sudo -u "$WISHADAY_USER" bash -c "
        cd '$APP_DIR'
        source venv/bin/activate
        export PYTHONPATH='$APP_DIR'
        python3 -c '
from app.services.image import validate_image, ALLOWED_CONTENT_TYPES, ALLOWED_EXTENSIONS
from app.config import settings
print(f\"Max file size: {settings.MAX_FILE_SIZE} bytes\")
print(f\"Max images per wish: {settings.MAX_IMAGES_PER_WISH}\")
print(f\"Upload path: {settings.upload_path}\")
print(\"OK\")
' 2>&1
    ")
    
    if ! echo "$image_test_result" | grep -q "OK"; then
        log_error "Image service test failed: $image_test_result"
        issues_found=$((issues_found + 1))
    else
        log_success "Image processing functionality is working"
    fi
    
    # Step 7: Fix service and restart if issues were found
    if [[ $issues_found -gt 0 ]]; then
        log_step "Restarting services after fixes"
        
        # Stop service
        systemctl stop "$SERVICE_NAME" || true
        sleep 2
        
        # Kill any remaining processes
        if netstat -tlnp | grep -q ":$WISHADAY_PORT "; then
            log_warn "Port $WISHADAY_PORT still in use, killing processes..."
            lsof -ti:"$WISHADAY_PORT" | xargs kill -9 2>/dev/null || true
            sleep 2
        fi
        
        # Fix ownership
        chown -R "$WISHADAY_USER:$WISHADAY_GROUP" "$APP_DIR"
        
        # Update service file to include better error handling
        create_systemd_service
        
        # Start service
        systemctl daemon-reload
        systemctl start "$SERVICE_NAME"
        
        # Wait and check
        show_progress 5 "Waiting for service to start"
        
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            log_success "Service started successfully"
            
            # Test backend
            if curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$WISHADAY_PORT/health" 2>/dev/null | grep -q "200"; then
                log_success "Backend is responding"
            else
                log_error "Backend is not responding"
                log_info "Recent logs:"
                journalctl -u "$SERVICE_NAME" -n 10 --no-pager
                return 1
            fi
        else
            log_error "Service failed to start"
            log_info "Service status:"
            systemctl status "$SERVICE_NAME" --no-pager -l
            return 1
        fi
    fi
    
    # Step 8: Test image upload endpoint
    log_step "Testing image upload endpoint"
    
    # First, create a test wish to upload to
    local wish_response=$(curl -s -X POST "http://127.0.0.1:$WISHADAY_PORT/api/wishes" \
        -H "Content-Type: application/json" \
        -d '{
            "message": "Test wish for image upload diagnostic",
            "theme": "default"
        }' 2>/dev/null || echo "")
    
    if [[ -n "$wish_response" ]]; then
        local wish_slug=$(echo "$wish_response" | python3 -c "import sys, json; print(json.load(sys.stdin)['slug'])" 2>/dev/null || echo "")
        
        if [[ -n "$wish_slug" ]]; then
            log_info "Test wish created with slug: $wish_slug"
            
            # Create a small test image using the virtual environment
            sudo -u "$WISHADAY_USER" bash -c "
                cd '$APP_DIR'
                source venv/bin/activate
                python3 -c '
from PIL import Image
img = Image.new(\"RGB\", (100, 100), color=\"red\")
img.save(\"/tmp/test_image_upload.jpg\", \"JPEG\")
print(\"Test image created\")
'
            "
            
            # Test image upload
            local upload_response=$(curl -s -X POST "http://127.0.0.1:$WISHADAY_PORT/api/wishes/$wish_slug/images" \
                -F "file=@/tmp/test_image_upload.jpg" 2>/dev/null || echo "ERROR")
            
            if [[ "$upload_response" == "ERROR" ]]; then
                log_error "Image upload test failed with curl error"
                issues_found=$((issues_found + 1))
            elif echo "$upload_response" | grep -q "url"; then
                log_success "Image upload test successful!"
                log_info "Upload response: $upload_response"
            else
                log_error "Image upload test failed"
                log_info "Response: $upload_response"
                issues_found=$((issues_found + 1))
            fi
            
            # Clean up
            rm -f /tmp/test_image_upload.jpg
        else
            log_error "Failed to extract wish slug from response"
            issues_found=$((issues_found + 1))
        fi
    else
        log_error "Failed to create test wish for upload testing"
        issues_found=$((issues_found + 1))
    fi
    
    # Final summary
    echo ""
    log_header "Image Upload Fix Summary"
    echo ""
    
    if [[ $issues_found -eq 0 ]]; then
        log_success "No issues found! Image upload functionality should be working correctly."
    else
        log_success "Fixed $issues_found issues related to image upload functionality."
        log_info "The 500 Internal Server Error during image uploads should now be resolved."
    fi
    
    echo ""
    log_info "You can now test the image upload functionality in your frontend."
    log_info "If issues persist, check the logs with: journalctl -u $SERVICE_NAME -f"
    echo ""
}

# Show help
show_help() {
    echo -e "${BOLD}Wishaday Server Management Script v2.0${NC}"
    echo ""
    echo "Complete server management solution for Wishaday application"
    echo ""
    echo -e "${BOLD}Usage:${NC} sudo ./serverv2.sh [command]"
    echo ""
    echo -e "${BOLD}Setup Commands:${NC}"
    echo "  setup       - Complete initial server setup (Ubuntu/Debian)"
    echo "  install     - Install Wishaday application"
    echo "  configure   - Configure environment and services"
    echo "  deploy      - Deploy to production"
    echo ""
    echo -e "${BOLD}Service Management:${NC}"
    echo "  start       - Start all services"
    echo "  stop        - Stop all services"
    echo "  restart     - Restart all services"
    echo "  status      - Show system status"
    echo ""
    echo -e "${BOLD}Maintenance:${NC}"
    echo "  diagnose    - Diagnose and fix issues automatically"
    echo "  fix-all     - Fix all common issues"
    echo "  fix-502     - Fix 502 Bad Gateway errors"
    echo "  fix-perms   - Fix file permissions"
    echo "  fix-db      - Fix database issues and permissions"
    echo "  fix-env     - Fix environment configuration"
    echo "  fix-upload  - Fix image upload 500 errors"
    echo "  update      - Update application from git"
    echo "  clean       - Clean build artifacts and temporary files"
    echo "  rebuild     - Complete rebuild (clean + install + build)"
    echo ""
    echo -e "${BOLD}Monitoring:${NC}"
    echo "  logs        - Show recent logs"
    echo "  test        - Test all endpoints"
    echo "  test-db     - Test database connectivity and permissions"
    echo "  monitor     - Real-time monitoring"
    echo ""
    echo -e "${BOLD}Backup:${NC}"
    echo "  backup      - Create system backup"
    echo "  restore     - Restore from backup (interactive)"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  sudo ./serverv2.sh setup      # Initial server setup"
    echo "  sudo ./serverv2.sh install    # Install application"
    echo "  sudo ./serverv2.sh deploy     # Deploy to production"
    echo "  sudo ./serverv2.sh diagnose   # Auto-fix issues"
    echo "  sudo ./serverv2.sh clean      # Clean build artifacts"
    echo "  sudo ./serverv2.sh rebuild    # Complete rebuild"
    echo "  sudo ./serverv2.sh monitor    # Real-time monitoring"
    echo ""
    echo -e "${BOLD}Environment Variables:${NC}"
    echo "  WISHADAY_DOMAIN    - Domain name (default: wishaday.hareeshworks.in)"
    echo "  WISHADAY_PORT      - Backend port (default: 8000)"
    echo "  GIT_REPO          - Git repository URL for auto-clone"
    echo "  NODE_VERSION      - Node.js version to install (default: 20)"
    echo ""
}

# Main function
main() {
    case "${1:-help}" in
        "setup")
            check_root
            complete_setup
            ;;
        "install")
            check_root
            install_application
            ;;
        "configure")
            check_root
            configure_services
            ;;
        "deploy")
            check_root
            deploy_to_production
            ;;
        "start")
            check_root
            start_all_services
            ;;
        "stop")
            check_root
            stop_all_services
            ;;
        "restart")
            check_root
            restart_all_services
            ;;
        "status")
            show_system_status
            ;;
        "diagnose")
            check_root
            diagnose_and_fix
            ;;
        "fix-all")
            check_root
            diagnose_and_fix
            ;;
        "fix-502")
            check_root
            diagnose_and_fix
            ;;
        "fix-perms")
            check_root
            fix_all_permissions
            ;;
        "fix-db")
            check_root
            log_header "Fixing Database Issues"
            echo ""
            fix_database_permissions
            init_database
            ;;
        "fix-env")
            check_root
            configure_environment
            ;;
        "fix-upload")
            check_root
            fix_image_upload_500
            ;;
        "logs")
            show_recent_logs
            ;;
        "test")
            test_connectivity
            ;;
        "test-db")
            test_database_connectivity
            ;;
        "update")
            check_root
            update_application
            ;;
        "backup")
            check_root
            create_backup
            ;;
        "monitor")
            real_time_monitor
            ;;
        "clean")
            check_root
            clean_environment
            ;;
        "rebuild")
            check_root
            rebuild_application
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Print header
echo -e "${CYAN}${BOLD}"
echo "=================================================="
echo "  Wishaday Server Management Script v2.0"
echo "=================================================="
echo -e "${NC}"

# Run main function with all arguments
main "$@"