#!/bin/bash
################################################################################
# Wishaday Ubuntu Server All-in-One Installation and Setup Script
# 
# This script performs a complete installation of Wishaday on Ubuntu:
#   - Updates system packages
#   - Installs Python 3.11+ and pip
#   - Installs Node.js and npm (for frontend)
#   - Sets up the application directory
#   - Creates virtual environment
#   - Installs Python dependencies
#   - Builds the frontend
#   - Configures systemd service for auto-start
#   - Sets up Nginx as reverse proxy with Let's Encrypt SSL
#   - Uses SQLite for database (both local and production)
#
# Usage:
#   chmod +x ubuntuserverinstallandsetup.sh
#   sudo ./ubuntuserverinstallandsetup.sh
#
# Or run directly with curl:
#   curl -fsSL <script-url> | sudo bash
################################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="wishaday"
APP_USER="wishaday"
APP_DIR="/opt/wishaday"
SERVICE_NAME="wishaday"
NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"

# Default values (can be overridden with environment variables)
WISHADAY_PORT="${WISHADAY_PORT:-8000}"
WISHADAY_DOMAIN="${WISHADAY_DOMAIN:-localhost}"
WISHADAY_BASE_URL="${WISHADAY_BASE_URL:-http://localhost:8000}"
ENABLE_SSL="${ENABLE_SSL:-true}"
SSL_EMAIL="${SSL_EMAIL:-}"

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
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Detect Ubuntu version
detect_ubuntu() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        if [[ "$ID" != "ubuntu" ]]; then
            log_warn "This script is designed for Ubuntu. Detected: $ID"
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
        log_info "Detected Ubuntu version: $VERSION_ID"
    else
        log_error "Cannot detect OS version"
        exit 1
    fi
}

# Update system packages
update_system() {
    log_info "Updating system packages..."
    apt-get update
    apt-get upgrade -y
    log_success "System packages updated"
}

# Install required system packages
install_dependencies() {
    log_info "Installing required system packages..."
    
    apt-get install -y \
        software-properties-common \
        curl \
        wget \
        git \
        build-essential \
        libssl-dev \
        zlib1g-dev \
        libbz2-dev \
        libreadline-dev \
        libsqlite3-dev \
        llvm \
        libncurses5-dev \
        libncursesw5-dev \
        xz-utils \
        tk-dev \
        libffi-dev \
        liblzma-dev \
        python3-openssl \
        nginx \
        sqlite3 \
        certbot \
        python3-certbot-nginx
    
    log_success "System dependencies installed"
}

# Install Python 3.11 if not present
install_python() {
    log_info "Checking Python installation..."
    
    if command -v python3.11 &> /dev/null; then
        log_success "Python 3.11 is already installed"
    else
        log_info "Installing Python 3.11..."
        add-apt-repository ppa:deadsnakes/ppa -y
        apt-get update
        apt-get install -y python3.11 python3.11-venv python3.11-dev python3-pip
        log_success "Python 3.11 installed"
    fi
    
    # Set python3.11 as default python3 for this script
    PYTHON_CMD="python3.11"
    PIP_CMD="pip3"
    
    log_info "Python version: $($PYTHON_CMD --version)"
}

# Install Node.js and npm
install_nodejs() {
    log_info "Checking Node.js installation..."
    
    if command -v node &> /dev/null && [[ "$(node --version | cut -d'v' -f2 | cut -d'.' -f1)" -ge 18 ]]; then
        log_success "Node.js is already installed: $(node --version)"
    else
        log_info "Installing Node.js 20.x..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
        apt-get install -y nodejs
        log_success "Node.js installed: $(node --version)"
    fi
    
    log_info "npm version: $(npm --version)"
}

# Create application user
create_app_user() {
    log_info "Creating application user..."
    
    if id "$APP_USER" &>/dev/null; then
        log_warn "User $APP_USER already exists"
    else
        useradd -r -s /bin/false -d "$APP_DIR" -m "$APP_USER"
        log_success "Created user: $APP_USER"
    fi
}

# Setup application directory
setup_app_directory() {
    log_info "Setting up application directory..."
    
    # Create directory structure
    mkdir -p "$APP_DIR"
    mkdir -p "$APP_DIR/logs"
    mkdir -p "$APP_DIR/data"
    
    # Check if we're running from the project directory
    if [[ -f "pyproject.toml" ]]; then
        log_info "Copying application files..."
        cp -r . "$APP_DIR/"
    else
        log_info "Please ensure the application files are in $APP_DIR"
        log_info "You can clone the repository with:"
        log_info "  git clone <repository-url> $APP_DIR"
        read -p "Press Enter to continue after placing files in $APP_DIR..."
    fi
    
    # Set ownership
    chown -R "$APP_USER:$APP_USER" "$APP_DIR"
    
    log_success "Application directory setup complete"
}

# Setup Python virtual environment and install dependencies
setup_python_env() {
    log_info "Setting up Python virtual environment..."
    
    cd "$APP_DIR"
    
    # Create virtual environment
    $PYTHON_CMD -m venv venv
    source venv/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install production dependencies
    pip install -e "."
    
    # Deactivate
    deactivate
    
    # Set ownership
    chown -R "$APP_USER:$APP_USER" "$APP_DIR/venv"
    
    log_success "Python environment setup complete"
}

# Build frontend
build_frontend() {
    log_info "Building frontend..."
    
    cd "$APP_DIR/frontend"
    
    # Install npm dependencies
    npm install
    
    # Build for production
    npm run build
    
    # Set ownership
    chown -R "$APP_USER:$APP_USER" "$APP_DIR/frontend"
    
    log_success "Frontend built successfully"
}

# Create environment file
create_env_file() {
    log_info "Creating environment configuration..."
    
    cd "$APP_DIR"
    
    # Generate a secure secret key
    SECRET_KEY=$(openssl rand -hex 32)
    
    cat > .env << EOF
# Wishaday Production Configuration
# SQLite is used for both local and production (as per requirements)

# Database Configuration - SQLite
DATABASE_URL=sqlite:///$APP_DIR/data/wishaday.db

# Upload Configuration
UPLOAD_DIR=$APP_DIR/app/uploads
MAX_FILE_SIZE=2097152
MAX_IMAGES_PER_WISH=5

# Rate Limiting
MAX_WISHES_PER_IP_PER_DAY=10

# Cleanup Configuration
CLEANUP_INTERVAL_MINUTES=30
SOFT_DELETE_GRACE_PERIOD_MINUTES=10

# Server Configuration - Production
BASE_URL=$WISHADAY_BASE_URL
DEBUG=false
PORT=$WISHADAY_PORT

# Security
SECRET_KEY=$SECRET_KEY
EOF
    
    # Set ownership
    chown "$APP_USER:$APP_USER" .env
    chmod 600 .env
    
    log_success "Environment file created"
}

# Initialize database
init_database() {
    log_info "Initializing database..."
    
    cd "$APP_DIR"
    source venv/bin/activate
    
    # Initialize database
    $PYTHON_CMD scripts/init_db.py
    
    # Set ownership of database and uploads
    chown -R "$APP_USER:$APP_USER" "$APP_DIR/data"
    mkdir -p "$APP_DIR/app/uploads/wishes"
    chown -R "$APP_USER:$APP_USER" "$APP_DIR/app/uploads"
    
    deactivate
    
    log_success "Database initialized"
}

# Create systemd service
create_systemd_service() {
    log_info "Creating systemd service..."
    
    cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=Wishaday - Wish Sharing Platform
After=network.target

[Service]
Type=simple
User=$APP_USER
Group=$APP_USER
WorkingDirectory=$APP_DIR
Environment=PATH=$APP_DIR/venv/bin
Environment=PYTHONPATH=$APP_DIR
EnvironmentFile=$APP_DIR/.env
ExecStart=$APP_DIR/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port $WISHADAY_PORT --workers 4
Restart=always
RestartSec=5
StandardOutput=append:$APP_DIR/logs/wishaday.log
StandardError=append:$APP_DIR/logs/wishaday.error.log

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd
    systemctl daemon-reload
    
    # Enable service
    systemctl enable "$SERVICE_NAME"
    
    log_success "Systemd service created and enabled"
}

# Configure Nginx with HTTP (before SSL)
configure_nginx_http() {
    log_info "Configuring Nginx (HTTP)..."
    
    # Remove default site if it exists
    if [[ -f "$NGINX_ENABLED/default" ]]; then
        rm "$NGINX_ENABLED/default"
    fi
    
    # Create Nginx HTTP configuration
    cat > "$NGINX_AVAILABLE/$APP_NAME" << EOF
server {
    listen 80;
    server_name $WISHADAY_DOMAIN;

    client_max_body_size 10M;

    # Frontend static files
    location / {
        root $APP_DIR/frontend/dist;
        try_files \$uri \$uri/ /index.html;
        expires 1d;
        add_header Cache-Control "public, immutable";
    }

    # API and media
    location /api/ {
        proxy_pass http://127.0.0.1:$WISHADAY_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    location /media/ {
        proxy_pass http://127.0.0.1:$WISHADAY_PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        expires 7d;
        add_header Cache-Control "public, immutable";
    }

    location /health {
        proxy_pass http://127.0.0.1:$WISHADAY_PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        access_log off;
    }

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
}
EOF
    
    # Enable site
    ln -sf "$NGINX_AVAILABLE/$APP_NAME" "$NGINX_ENABLED/$APP_NAME"
    
    # Test Nginx configuration
    nginx -t
    
    # Reload Nginx
    systemctl reload nginx
    
    log_success "Nginx HTTP configured"
}

# Configure SSL with Let's Encrypt
configure_ssl() {
    log_info "Configuring SSL with Let's Encrypt..."
    
    # Check if domain is not localhost
    if [[ "$WISHADAY_DOMAIN" == "localhost" ]] || [[ "$WISHADAY_DOMAIN" == "127.0.0.1" ]]; then
        log_warn "Cannot configure SSL for localhost. Skipping SSL setup."
        return 0
    fi
    
    # Ask for email for SSL certificate
    if [[ -z "$SSL_EMAIL" ]]; then
        read -p "Enter your email for Let's Encrypt SSL certificate (for renewal notices): " input_email
        SSL_EMAIL="$input_email"
    fi
    
    if [[ -z "$SSL_EMAIL" ]]; then
        log_warn "No email provided. Skipping SSL setup."
        return 0
    fi
    
    # Stop Nginx temporarily to free up port 80
    systemctl stop nginx
    
    # Obtain SSL certificate
    log_info "Obtaining SSL certificate for $WISHADAY_DOMAIN..."
    certbot certonly --standalone -d "$WISHADAY_DOMAIN" --email "$SSL_EMAIL" --agree-tos --non-interactive
    
    if [[ $? -ne 0 ]]; then
        log_error "Failed to obtain SSL certificate"
        systemctl start nginx
        return 1
    fi
    
    # Start Nginx again
    systemctl start nginx
    
    # Update Nginx configuration for HTTPS
    log_info "Updating Nginx configuration for HTTPS..."
    
    cat > "$NGINX_AVAILABLE/$APP_NAME" << EOF
# HTTP server - redirect to HTTPS
server {
    listen 80;
    server_name $WISHADAY_DOMAIN;

    # Redirect all HTTP traffic to HTTPS
    return 301 https://\$server_name\$request_uri;
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name $WISHADAY_DOMAIN;

    # SSL certificate configuration
    ssl_certificate /etc/letsencrypt/live/$WISHADAY_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$WISHADAY_DOMAIN/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    client_max_body_size 10M;

    # Frontend static files
    location / {
        root $APP_DIR/frontend/dist;
        try_files \$uri \$uri/ /index.html;
        expires 1d;
        add_header Cache-Control "public, immutable";
    }

    # API and media
    location /api/ {
        proxy_pass http://127.0.0.1:$WISHADAY_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_cache_bypass \$http_upgrade;
    }

    location /media/ {
        proxy_pass http://127.0.0.1:$WISHADAY_PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        expires 7d;
        add_header Cache-Control "public, immutable";
    }

    location /health {
        proxy_pass http://127.0.0.1:$WISHADAY_PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        access_log off;
    }

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
}
EOF
    
    # Test Nginx configuration
    nginx -t
    
    # Reload Nginx
    systemctl reload nginx
    
    # Setup auto-renewal
    log_info "Setting up SSL certificate auto-renewal..."
    
    # Add certbot renewal cron job
    cat > /etc/cron.d/certbot-renewal << EOF
# Renew SSL certificates twice daily
0 */12 * * * root certbot renew --quiet --post-hook "systemctl reload nginx"
EOF
    
    log_success "SSL configured with Let's Encrypt"
    log_success "Auto-renewal configured (certificates will be renewed twice daily)"
    
    # Update BASE_URL to use HTTPS
    WISHADAY_BASE_URL="https://$WISHADAY_DOMAIN"
    
    # Update .env file with HTTPS URL
    sed -i "s|BASE_URL=.*|BASE_URL=$WISHADAY_BASE_URL|g" "$APP_DIR/.env"
    
    log_success "Updated BASE_URL to: $WISHADAY_BASE_URL"
}

# Setup log rotation
setup_logrotate() {
    log_info "Setting up log rotation..."
    
    cat > "/etc/logrotate.d/$APP_NAME" << EOF
$APP_DIR/logs/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 0644 $APP_USER $APP_USER
    sharedscripts
    postrotate
        systemctl reload $SERVICE_NAME
    endscript
}
EOF
    
    log_success "Log rotation configured"
}

# Setup firewall
setup_firewall() {
    log_info "Configuring firewall..."
    
    # Check if ufw is installed
    if command -v ufw &> /dev/null; then
        ufw allow 'Nginx Full'
        ufw allow OpenSSH
        
        # Enable firewall if not already enabled
        if ! ufw status | grep -q "Status: active"; then
            log_warn "Enabling UFW firewall..."
            echo "y" | ufw enable
        fi
        
        log_success "Firewall configured"
    else
        log_warn "UFW not installed, skipping firewall configuration"
    fi
}

# Start services
start_services() {
    log_info "Starting services..."
    
    # Start the application
    systemctl start "$SERVICE_NAME"
    
    # Check status
    sleep 2
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_success "Wishaday service is running"
    else
        log_error "Wishaday service failed to start"
        systemctl status "$SERVICE_NAME"
        exit 1
    fi
    
    log_success "All services started"
}

# Print final information
print_completion_info() {
    echo
    echo "========================================="
    echo "  Wishaday Installation Complete!"
    echo "========================================="
    echo
    echo "Application Information:"
    echo "  - Installation Directory: $APP_DIR"
    echo "  - Service Name: $SERVICE_NAME"
    echo "  - Application User: $APP_USER"
    echo "  - Database: SQLite ($APP_DIR/data/wishaday.db)"
    echo "  - Port: $WISHADAY_PORT"
    echo "  - Domain: $WISHADAY_DOMAIN"
    echo
    echo "Access URLs:"
    if [[ "$WISHADAY_DOMAIN" != "localhost" ]] && [[ -f "/etc/letsencrypt/live/$WISHADAY_DOMAIN/fullchain.pem" ]]; then
        echo "  - Public (HTTPS): https://$WISHADAY_DOMAIN"
        echo "  - API Docs: https://$WISHADAY_DOMAIN/api/docs"
        echo "  - Health Check: https://$WISHADAY_DOMAIN/health"
    else
        echo "  - Local: http://localhost:$WISHADAY_PORT"
        if [[ "$WISHADAY_DOMAIN" != "localhost" ]]; then
            echo "  - Public (HTTP): http://$WISHADAY_DOMAIN"
        fi
        echo "  - API Docs: http://$WISHADAY_DOMAIN/api/docs"
        echo "  - Health Check: http://$WISHADAY_DOMAIN/health"
    fi
    echo
    echo "Useful Commands:"
    echo "  - View logs: sudo journalctl -u $SERVICE_NAME -f"
    echo "  - View app logs: sudo tail -f $APP_DIR/logs/wishaday.log"
    echo "  - Restart service: sudo systemctl restart $SERVICE_NAME"
    echo "  - Stop service: sudo systemctl stop $SERVICE_NAME"
    echo "  - Service status: sudo systemctl status $SERVICE_NAME"
    if [[ "$WISHADAY_DOMAIN" != "localhost" ]] && [[ -f "/etc/letsencrypt/live/$WISHADAY_DOMAIN/fullchain.pem" ]]; then
        echo "  - Renew SSL: sudo certbot renew"
        echo "  - Check SSL status: sudo certbot certificates"
    fi
    echo
    echo "File Locations:"
    echo "  - Application: $APP_DIR"
    echo "  - Logs: $APP_DIR/logs/"
    echo "  - Database: $APP_DIR/data/wishaday.db"
    echo "  - Uploads: $APP_DIR/app/uploads/"
    echo "  - Config: $APP_DIR/.env"
    echo "  - Nginx Config: $NGINX_AVAILABLE/$APP_NAME"
    echo
    echo "========================================="
}

# Main installation function
main() {
    echo "========================================="
    echo "  Wishaday Ubuntu Server Installer"
    echo "========================================="
    echo
    
    # Check prerequisites
    check_root
    detect_ubuntu
    
    # Get user input for configuration
    echo "Domain Configuration:"
    echo "  Enter your domain name (e.g., example.com)"
    echo "  This is required for Nginx and Let's Encrypt SSL setup"
    echo
    read -p "Enter your domain name (required): " input_domain
    WISHADAY_DOMAIN="${input_domain:-$WISHADAY_DOMAIN}"
    
    if [[ "$WISHADAY_DOMAIN" == "localhost" ]]; then
        log_warn "Using localhost - SSL will not be configured"
        WISHADAY_BASE_URL="http://localhost:$WISHADAY_PORT"
        ENABLE_SSL="false"
    else
        WISHADAY_BASE_URL="http://$WISHADAY_DOMAIN"
        read -p "Enable SSL with Let's Encrypt? (Y/n): " input_ssl
        if [[ "$input_ssl" =~ ^[Nn]$ ]]; then
            ENABLE_SSL="false"
        else
            ENABLE_SSL="true"
        fi
    fi
    
    read -p "Enter port number (default: 8000): " input_port
    WISHADAY_PORT="${input_port:-$WISHADAY_PORT}"
    
    echo
    log_info "Starting installation with:"
    log_info "  Domain: $WISHADAY_DOMAIN"
    log_info "  Port: $WISHADAY_PORT"
    log_info "  Base URL: $WISHADAY_BASE_URL"
    log_info "  SSL: $ENABLE_SSL"
    echo
    
    # Run installation steps
    update_system
    install_dependencies
    install_python
    install_nodejs
    create_app_user
    setup_app_directory
    setup_python_env
    build_frontend
    create_env_file
    init_database
    create_systemd_service
    configure_nginx_http
    start_services
    
    # Configure SSL if enabled and domain is not localhost
    if [[ "$ENABLE_SSL" == "true" ]]; then
        configure_ssl
    fi
    
    # Setup log rotation and firewall
    setup_logrotate
    setup_firewall
    
    # Print completion information
    print_completion_info
}

# Run main function
main "$@"
