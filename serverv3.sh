#!/bin/bash
################################################################################
# Wishaday Easy Deployment Script v4.0
#
# Optimized for simplicity and efficiency with smart pull & update workflow
#
# Quick Commands:
#   sudo ./wishaday-deploy.sh quick-start    # First-time setup (one command!)
#   sudo ./wishaday-deploy.sh pull           # Pull latest code and auto-update
#   sudo ./wishaday-deploy.sh update         # Quick update without downtime
#   sudo ./wishaday-deploy.sh restart        # Restart services
#   sudo ./wishaday-deploy.sh status         # Check health
################################################################################

set -euo pipefail

# ==================== Configuration ====================

readonly APP_NAME="wishaday"
readonly APP_DIR="/opt/wishaday"
readonly BACKUP_DIR="/opt/wishaday-backups"
readonly SERVICE_NAME="wishaday"

# Environment variables with defaults
export WISHADAY_PORT="${WISHADAY_PORT:-8000}"
export WISHADAY_DOMAIN="${WISHADAY_DOMAIN:-wishaday.hareeshworks.in}"
export WISHADAY_USER="${WISHADAY_USER:-wishaday}"
export WISHADAY_GROUP="${WISHADAY_GROUP:-wishaday}"
export GIT_REPO="${GIT_REPO:-https://github.com/hareesh08/Wish-A-Day.git}"
export GIT_BRANCH="${GIT_BRANCH:-main}"
export NODE_VERSION="${NODE_VERSION:-20}"

# ==================== Colors ====================

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# ==================== Logging ====================

log() { echo -e "${BLUE}ℹ${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; exit 1; }
header() { echo -e "\n${CYAN}${BOLD}━━━ $1 ━━━${NC}\n"; }
step() { echo -e "${MAGENTA}▶${NC} $1"; }

spinner() {
    local pid=$1
    local message=$2
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    echo -n "$message "
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf "[%c]" "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep 0.1
        printf "\b\b\b"
    done
    wait "$pid"
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
        return $exit_code
    fi
}

# ==================== Validation ====================

check_root() {
    [[ $EUID -eq 0 ]] || error "This script must be run as root (use sudo)"
}

check_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        log "OS: $PRETTY_NAME"
    else
        warn "Cannot determine OS version, proceeding anyway..."
    fi
}

# ==================== System Setup ====================

setup_user() {
    step "Setting up system user"

    if ! getent group "$WISHADAY_GROUP" >/dev/null 2>&1; then
        groupadd "$WISHADAY_GROUP"
        log "Created group: $WISHADAY_GROUP"
    fi

    if ! getent passwd "$WISHADAY_USER" >/dev/null 2>&1; then
        useradd -r -g "$WISHADAY_GROUP" -d "$APP_DIR" -s /bin/bash "$WISHADAY_USER"
        log "Created user: $WISHADAY_USER"
    fi

    usermod -a -G "$WISHADAY_GROUP" www-data 2>/dev/null || true
    success "User setup complete"
}

install_dependencies() {
    step "Installing system dependencies"

    export DEBIAN_FRONTEND=noninteractive
    apt update -qq > /dev/null 2>&1 &
    spinner $! "Updating package list"

    apt install -y -qq \
        curl wget git nginx \
        python3 python3-pip python3-venv python3-dev \
        build-essential pkg-config libffi-dev libssl-dev \
        sqlite3 libsqlite3-dev supervisor \
        certbot python3-certbot-nginx \
        htop tree lsof net-tools unzip > /dev/null 2>&1 &
    spinner $! "Installing dependencies"

    success "Dependencies installed"
}

install_nodejs() {
    step "Installing Node.js $NODE_VERSION"

    if command -v node >/dev/null 2>&1; then
        local current_version=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ "$current_version" -ge "$NODE_VERSION" ]]; then
            log "Node.js $current_version already installed"
            return 0
        fi
    fi

    curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | bash - > /dev/null 2>&1
    apt install -y -qq nodejs > /dev/null 2>&1 &
    spinner $! "Installing Node.js"

    success "Node.js $(node --version) installed"
}

setup_directories() {
    step "Creating directories"

    mkdir -p "$APP_DIR"/{logs,app/uploads/wishes}
    mkdir -p "$BACKUP_DIR"

    chown -R "$WISHADAY_USER:$WISHADAY_GROUP" "$APP_DIR" "$BACKUP_DIR"

    success "Directories created"
}

# ==================== Git Operations ====================

clone_repository() {
    step "Cloning repository"

    if [[ -d "$APP_DIR/.git" ]]; then
        log "Repository already exists"
        return 0
    fi

    if [[ -z "$GIT_REPO" ]]; then
        warn "No git repository specified. Set GIT_REPO environment variable"
        return 0
    fi

    cd "$APP_DIR"
    sudo -u "$WISHADAY_USER" git clone "$GIT_REPO" . > /dev/null 2>&1 &
    spinner $! "Cloning from $GIT_REPO"

    success "Repository cloned"
}

pull_latest() {
    step "Pulling latest changes"

    if [[ ! -d "$APP_DIR/.git" ]]; then
        warn "Not a git repository. Run 'setup' first or set GIT_REPO"
        return 0
    fi

    cd "$APP_DIR"

    # Stash any local changes
    sudo -u "$WISHADAY_USER" git stash > /dev/null 2>&1 || true

    # Fetch and check for changes
    local before_hash=$(sudo -u "$WISHADAY_USER" git rev-parse HEAD)
    sudo -u "$WISHADAY_USER" git fetch origin "$GIT_BRANCH" > /dev/null 2>&1 &
    spinner $! "Fetching changes"

    local after_hash=$(sudo -u "$WISHADAY_USER" git rev-parse "origin/$GIT_BRANCH")

    if [[ "$before_hash" == "$after_hash" ]]; then
        success "Already up to date"
        return 1  # Return 1 to indicate no changes
    fi

    # Pull changes
    sudo -u "$WISHADAY_USER" git pull origin "$GIT_BRANCH" > /dev/null 2>&1 &
    spinner $! "Pulling changes"

    # Show what changed
    log "Changes:"
    git log --oneline "$before_hash".."$after_hash" | head -5 | while read line; do
        echo "  • $line"
    done

    success "Code updated"
    return 0  # Return 0 to indicate changes were made
}

# ==================== Application Setup ====================

setup_python_env() {
    step "Setting up Python environment"

    cd "$APP_DIR"

    if [[ ! -d "venv" ]]; then
        sudo -u "$WISHADAY_USER" python3 -m venv venv > /dev/null 2>&1 &
        spinner $! "Creating virtual environment"
    fi

    sudo -u "$WISHADAY_USER" bash -c "
        source venv/bin/activate
        pip install --upgrade pip setuptools wheel -q > /dev/null 2>&1

        if [[ -f 'pyproject.toml' ]]; then
            pip install -e . -q > /dev/null 2>&1
        elif [[ -f 'requirements.txt' ]]; then
            pip install -r requirements.txt -q > /dev/null 2>&1
        else
            pip install -q fastapi uvicorn sqlalchemy pydantic-settings pillow apscheduler python-multipart > /dev/null 2>&1
        fi
    " &
    spinner $! "Installing Python packages"

    success "Python environment ready"
}

build_frontend() {
    step "Building frontend"

    if [[ ! -d "$APP_DIR/frontend" ]]; then
        log "No frontend directory found, skipping"
        return 0
    fi

    cd "$APP_DIR/frontend"

    # Install dependencies if needed
    if [[ ! -d "node_modules" || package.json -nt node_modules ]]; then
        sudo -u "$WISHADAY_USER" npm install --silent > /dev/null 2>&1 &
        spinner $! "Installing npm packages"
    fi

    # Build
    sudo -u "$WISHADAY_USER" npm run build > /dev/null 2>&1 &
    spinner $! "Building frontend"

    chown -R "$WISHADAY_USER:$WISHADAY_GROUP" "$APP_DIR/frontend"

    success "Frontend built"
}

setup_environment() {
    step "Configuring environment"

    cd "$APP_DIR"

    if [[ ! -f ".env" ]]; then
        if [[ -f ".env.example" ]]; then
            cp ".env.example" ".env"
            log "Created .env from template"
        else
            create_env_file
        fi
    fi

    # Update critical settings
    sed -i \
        -e "s|DATABASE_URL=.*|DATABASE_URL=sqlite:///$APP_DIR/app/wishaday.db|g" \
        -e "s|BASE_URL=.*|BASE_URL=https://$WISHADAY_DOMAIN|g" \
        -e "s|DEBUG=.*|DEBUG=false|g" \
        -e "s|PORT=.*|PORT=$WISHADAY_PORT|g" \
        "$APP_DIR/.env" 2>/dev/null || true

    chown "$WISHADAY_USER:$WISHADAY_GROUP" ".env"
    chmod 640 ".env"

    success "Environment configured"
}

create_env_file() {
    cat > "$APP_DIR/.env" << EOF
# Database
DATABASE_URL=sqlite:///$APP_DIR/app/wishaday.db

# Upload settings
UPLOAD_DIR=$APP_DIR/app/uploads
MAX_FILE_SIZE=2097152
MAX_IMAGES_PER_WISH=5
MAX_WISHES_PER_IP_PER_DAY=10

# Cleanup
CLEANUP_INTERVAL_MINUTES=30
SOFT_DELETE_GRACE_PERIOD_MINUTES=10

# Server
BASE_URL=https://$WISHADAY_DOMAIN
DEBUG=false
PORT=$WISHADAY_PORT
SECRET_KEY=$(openssl rand -hex 32)
EOF
    log "Created default .env file"
}

setup_database() {
    step "Initializing database"

    mkdir -p "$APP_DIR/app"

    sudo -u "$WISHADAY_USER" bash -c "
        cd '$APP_DIR'
        source venv/bin/activate
        export PYTHONPATH='$APP_DIR'
        python -c 'from app.database import init_db; init_db()' 2>/dev/null || \
        python -c 'import sqlite3; conn = sqlite3.connect(\"$APP_DIR/app/wishaday.db\"); conn.close()'
    " > /dev/null 2>&1 &
    spinner $! "Creating database"

    if [[ -f "$APP_DIR/app/wishaday.db" ]]; then
        chown "$WISHADAY_USER:$WISHADAY_GROUP" "$APP_DIR/app/wishaday.db"
        chmod 664 "$APP_DIR/app/wishaday.db"
    fi

    success "Database ready"
}

# ==================== Service Configuration ====================

setup_systemd_service() {
    step "Configuring systemd service"

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
ExecStart=$APP_DIR/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port $WISHADAY_PORT
Restart=always
RestartSec=3
StandardOutput=append:$APP_DIR/logs/wishaday.log
StandardError=append:$APP_DIR/logs/wishaday.error.log

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME" > /dev/null 2>&1

    success "Service configured"
}

setup_nginx_config() {
    step "Configuring nginx"

    cat > "/etc/nginx/sites-available/$APP_NAME" << 'EOF'
server {
    listen 80;
    server_name DOMAIN_PLACEHOLDER;
    client_max_body_size 10M;

    # API proxy
    location /api/ {
        proxy_pass http://127.0.0.1:PORT_PLACEHOLDER/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffering off;
    }

    # Health check
    location /health {
        proxy_pass http://127.0.0.1:PORT_PLACEHOLDER/health;
        access_log off;
    }

    # Media files
    location /media/ {
        alias APP_DIR_PLACEHOLDER/app/uploads/;
        expires 30d;
        add_header Cache-Control "public, immutable";
        try_files $uri =404;
    }

    # Frontend
    location / {
        root APP_DIR_PLACEHOLDER/frontend/dist;
        try_files $uri $uri/ /index.html;
        expires 1h;
        add_header Cache-Control "public, must-revalidate";
    }
}
EOF

    # Replace placeholders
    sed -i \
        -e "s|DOMAIN_PLACEHOLDER|$WISHADAY_DOMAIN|g" \
        -e "s|PORT_PLACEHOLDER|$WISHADAY_PORT|g" \
        -e "s|APP_DIR_PLACEHOLDER|$APP_DIR|g" \
        "/etc/nginx/sites-available/$APP_NAME"

    ln -sf "/etc/nginx/sites-available/$APP_NAME" "/etc/nginx/sites-enabled/$APP_NAME"
    rm -f "/etc/nginx/sites-enabled/default"

    nginx -t > /dev/null 2>&1 &
    spinner $! "Testing nginx configuration"

    success "Nginx configured"
}

setup_ssl() {
    step "Setting up SSL certificate"

    if certbot certificates 2>/dev/null | grep -q "$WISHADAY_DOMAIN"; then
        log "SSL certificate already exists"
        return 0
    fi

    certbot --nginx -d "$WISHADAY_DOMAIN" \
        --non-interactive --agree-tos \
        --email "admin@$WISHADAY_DOMAIN" \
        --redirect > /dev/null 2>&1 &

    if spinner $! "Obtaining SSL certificate"; then
        success "SSL certificate installed"
    else
        warn "SSL setup failed. Run manually: certbot --nginx -d $WISHADAY_DOMAIN"
    fi
}

# ==================== Permissions ====================

fix_permissions() {
    step "Fixing permissions"

    chown -R "$WISHADAY_USER:$WISHADAY_GROUP" "$APP_DIR"

    find "$APP_DIR" -type d -exec chmod 755 {} \; 2>/dev/null
    find "$APP_DIR" -type f -exec chmod 644 {} \; 2>/dev/null

    chmod -R 775 "$APP_DIR/app/uploads" 2>/dev/null || true
    chmod 664 "$APP_DIR/app/wishaday.db" 2>/dev/null || true
    chmod 640 "$APP_DIR/.env" 2>/dev/null || true

    success "Permissions fixed"
}

# ==================== Service Management ====================

start_services() {
    step "Starting services"

    systemctl start nginx 2>/dev/null || true
    systemctl start "$SERVICE_NAME"

    sleep 2

    if systemctl is-active --quiet "$SERVICE_NAME"; then
        success "Services started"
    else
        error "Failed to start services"
    fi
}

stop_services() {
    step "Stopping services"

    systemctl stop "$SERVICE_NAME" 2>/dev/null || true

    success "Services stopped"
}

restart_services() {
    step "Restarting services"

    systemctl restart "$SERVICE_NAME"
    systemctl reload nginx

    sleep 2

    if systemctl is-active --quiet "$SERVICE_NAME"; then
        success "Services restarted"
    else
        error "Failed to restart services"
    fi
}

# ==================== Status & Diagnostics ====================

show_status() {
    header "System Status"

    # Services
    echo -e "${BOLD}Services:${NC}"
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo -e "  ${GREEN}✓${NC} Wishaday (running)"
    else
        echo -e "  ${RED}✗${NC} Wishaday (stopped)"
    fi

    if systemctl is-active --quiet nginx; then
        echo -e "  ${GREEN}✓${NC} Nginx (running)"
    else
        echo -e "  ${RED}✗${NC} Nginx (stopped)"
    fi

    # Ports
    echo -e "\n${BOLD}Ports:${NC}"
    if netstat -tlnp 2>/dev/null | grep -q ":$WISHADAY_PORT "; then
        echo -e "  ${GREEN}✓${NC} Port $WISHADAY_PORT (backend)"
    else
        echo -e "  ${RED}✗${NC} Port $WISHADAY_PORT (backend)"
    fi

    if netstat -tlnp 2>/dev/null | grep -q ":80 "; then
        echo -e "  ${GREEN}✓${NC} Port 80 (http)"
    else
        echo -e "  ${RED}✗${NC} Port 80 (http)"
    fi

    if netstat -tlnp 2>/dev/null | grep -q ":443 "; then
        echo -e "  ${GREEN}✓${NC} Port 443 (https)"
    else
        echo -e "  ${YELLOW}○${NC} Port 443 (https) - SSL not configured"
    fi

    # Files
    echo -e "\n${BOLD}Files:${NC}"
    [[ -f "$APP_DIR/app/wishaday.db" ]] && \
        echo -e "  ${GREEN}✓${NC} Database exists" || \
        echo -e "  ${RED}✗${NC} Database missing"

    [[ -f "$APP_DIR/.env" ]] && \
        echo -e "  ${GREEN}✓${NC} Environment configured" || \
        echo -e "  ${RED}✗${NC} Environment missing"

    [[ -d "$APP_DIR/venv" ]] && \
        echo -e "  ${GREEN}✓${NC} Python venv exists" || \
        echo -e "  ${RED}✗${NC} Python venv missing"

    # Git status
    if [[ -d "$APP_DIR/.git" ]]; then
        echo -e "\n${BOLD}Repository:${NC}"
        cd "$APP_DIR"
        local current_branch=$(sudo -u "$WISHADAY_USER" git branch --show-current 2>/dev/null || echo "unknown")
        local commit_hash=$(sudo -u "$WISHADAY_USER" git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        echo -e "  Branch: ${CYAN}$current_branch${NC}"
        echo -e "  Commit: ${CYAN}$commit_hash${NC}"
    fi

    # Connectivity test
    echo -e "\n${BOLD}Connectivity:${NC}"
    if curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$WISHADAY_PORT/health" 2>/dev/null | grep -q "200"; then
        echo -e "  ${GREEN}✓${NC} Backend responding"
    else
        echo -e "  ${RED}✗${NC} Backend not responding"
    fi

    if curl -s -o /dev/null -w "%{http_code}" "http://localhost/health" 2>/dev/null | grep -q "200"; then
        echo -e "  ${GREEN}✓${NC} Nginx proxy working"
    else
        echo -e "  ${YELLOW}○${NC} Nginx proxy issue"
    fi

    echo ""
}

test_connectivity() {
    step "Testing connectivity"

    local backend_status=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$WISHADAY_PORT/health" 2>/dev/null)
    local nginx_status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/health" 2>/dev/null)

    if [[ "$backend_status" == "200" ]]; then
        echo -e "  ${GREEN}✓${NC} Backend: $backend_status"
    else
        echo -e "  ${RED}✗${NC} Backend: $backend_status"
    fi

    if [[ "$nginx_status" == "200" ]]; then
        echo -e "  ${GREEN}✓${NC} Nginx: $nginx_status"
    else
        echo -e "  ${RED}✗${NC} Nginx: $nginx_status"
    fi
}

show_logs() {
    header "Recent Logs"

    echo -e "${BOLD}Service Logs:${NC}"
    journalctl -u "$SERVICE_NAME" -n 20 --no-pager 2>/dev/null || echo "No service logs"

    echo -e "\n${BOLD}Error Logs:${NC}"
    tail -20 "$APP_DIR/logs/wishaday.error.log" 2>/dev/null || echo "No error logs"
}

diagnose() {
    header "Diagnosing System"

    local issues=0

    # Check service
    if ! systemctl is-active --quiet "$SERVICE_NAME"; then
        warn "Service is not running"
        issues=$((issues + 1))
        systemctl start "$SERVICE_NAME"
    fi

    # Check database
    if [[ ! -f "$APP_DIR/app/wishaday.db" ]]; then
        warn "Database missing"
        issues=$((issues + 1))
        setup_database
    fi

    # Check permissions
    if [[ $(stat -c %U "$APP_DIR/.env" 2>/dev/null) != "$WISHADAY_USER" ]]; then
        warn "Permission issues detected"
        issues=$((issues + 1))
        fix_permissions
    fi

    # Check nginx
    if ! nginx -t > /dev/null 2>&1; then
        warn "Nginx configuration error"
        issues=$((issues + 1))
        setup_nginx_config
        systemctl reload nginx
    fi

    # Test connectivity
    sleep 2
    test_connectivity

    if [[ $issues -eq 0 ]]; then
        success "System is healthy"
    else
        success "Fixed $issues issues"
    fi
}

# ==================== High-Level Operations ====================

quick_start() {
    header "Quick Start Installation"

    check_os
    setup_user
    install_dependencies
    install_nodejs
    setup_directories
    clone_repository
    setup_python_env
    setup_environment
    setup_database
    build_frontend
    fix_permissions
    setup_systemd_service
    setup_nginx_config
    systemctl enable --now nginx > /dev/null 2>&1
    start_services
    setup_ssl

    sleep 3
    show_status

    header "Installation Complete!"
    echo -e "🎉 Wishaday is now running at: ${GREEN}https://$WISHADAY_DOMAIN${NC}"
    echo ""
    echo "Next steps:"
    echo "  • Visit your site to verify it's working"
    echo "  • Check status: sudo $0 status"
    echo "  • View logs: sudo $0 logs"
    echo "  • Update code: sudo $0 pull"
    echo ""
}

pull_and_update() {
    header "Pull & Update"

    # Create backup first
    create_backup_quick

    # Pull changes
    if pull_latest; then
        # Changes detected, update what's needed
        log "Applying updates..."

        setup_python_env

        if [[ -d "$APP_DIR/frontend" ]]; then
            build_frontend
        fi

        fix_permissions
        restart_services

        sleep 2
        test_connectivity

        success "Update complete!"
    else
        log "No changes to apply"
    fi
}

quick_update() {
    header "Quick Update"

    stop_services
    setup_python_env

    if [[ -d "$APP_DIR/frontend" ]]; then
        build_frontend
    fi

    fix_permissions
    start_services

    sleep 2
    test_connectivity

    success "Update complete!"
}

create_backup_quick() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$BACKUP_DIR/backup-$timestamp"

    mkdir -p "$backup_path"

    # Backup database
    if [[ -f "$APP_DIR/app/wishaday.db" ]]; then
        cp "$APP_DIR/app/wishaday.db" "$backup_path/" > /dev/null 2>&1
    fi

    # Backup .env
    if [[ -f "$APP_DIR/.env" ]]; then
        cp "$APP_DIR/.env" "$backup_path/" > /dev/null 2>&1
    fi

    chown -R "$WISHADAY_USER:$WISHADAY_GROUP" "$backup_path"

    log "Backup created: $backup_path"
}

full_backup() {
    header "Creating Full Backup"

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$BACKUP_DIR/full-backup-$timestamp"

    mkdir -p "$backup_path"

    tar -czf "$backup_path/app.tar.gz" \
        -C "$APP_DIR" \
        --exclude="venv" \
        --exclude="node_modules" \
        --exclude="frontend/dist" \
        --exclude="__pycache__" \
        --exclude="*.pyc" \
        . > /dev/null 2>&1 &
    spinner $! "Creating backup archive"

    [[ -f "$APP_DIR/app/wishaday.db" ]] && \
        cp "$APP_DIR/app/wishaday.db" "$backup_path/"

    chown -R "$WISHADAY_USER:$WISHADAY_GROUP" "$backup_path"

    success "Backup created: $backup_path"

    # Keep only last 10 backups
    ls -t "$BACKUP_DIR" | tail -n +11 | xargs -I {} rm -rf "$BACKUP_DIR/{}" 2>/dev/null || true
}

clean_build() {
    header "Cleaning Build Artifacts"

    stop_services

    rm -rf "$APP_DIR/venv" "$APP_DIR/frontend/node_modules" "$APP_DIR/frontend/dist" 2>/dev/null
    find "$APP_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find "$APP_DIR" -name "*.pyc" -delete 2>/dev/null || true

    success "Build artifacts cleaned"
}

monitor_realtime() {
    header "Real-time Monitor (Ctrl+C to exit)"

    while true; do
        clear
        echo -e "${CYAN}${BOLD}Wishaday Monitor - $(date '+%Y-%m-%d %H:%M:%S')${NC}"
        echo "═══════════════════════════════════════════════════"
        echo ""

        # Service status
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            echo -e "Service: ${GREEN}RUNNING${NC}"
        else
            echo -e "Service: ${RED}STOPPED${NC}"
        fi

        # System resources
        echo -e "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')%"
        echo -e "Memory: $(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100}')"
        echo -e "Disk: $(df -h $APP_DIR | tail -1 | awk '{print $5}')"

        # Last 5 log lines
        echo ""
        echo -e "${BOLD}Recent Activity:${NC}"
        journalctl -u "$SERVICE_NAME" -n 5 --no-pager 2>/dev/null | tail -5

        sleep 5
    done
}

# ==================== Help ====================

show_help() {
    cat << EOF
${CYAN}${BOLD}Wishaday Easy Deployment Script v4.0${NC}

${BOLD}Quick Commands:${NC}
  ${GREEN}quick-start${NC}    Complete installation in one command
  ${GREEN}pull${NC}           Pull latest code and auto-update
  ${GREEN}status${NC}         Show system health and status
  ${GREEN}restart${NC}        Restart all services

${BOLD}Setup & Installation:${NC}
  quick-start     Complete first-time setup
  setup-system    Install system dependencies only
  setup-app       Install application only
  deploy          Full deployment workflow

${BOLD}Updates:${NC}
  pull            Pull from git and update (smart update)
  update          Update without pulling code

${BOLD}Service Management:${NC}
  start           Start services
  stop            Stop services
  restart         Restart services
  status          Show system status

${BOLD}Maintenance:${NC}
  diagnose        Auto-diagnose and fix issues
  logs            Show recent logs
  backup          Create full backup
  monitor         Real-time monitoring
  clean           Clean build artifacts
  fix-perms       Fix file permissions

${BOLD}Environment Variables:${NC}
  WISHADAY_DOMAIN      Domain name (default: wishaday.hareeshworks.in)
  WISHADAY_PORT        Backend port (default: 8000)
  GIT_REPO            Git repository URL
  GIT_BRANCH          Git branch (default: main)
  NODE_VERSION        Node.js version (default: 20)

${BOLD}Examples:${NC}
  # First time installation
  sudo ./wishaday-deploy.sh quick-start

  # Update from git
  sudo ./wishaday-deploy.sh pull

  # Just restart
  sudo ./wishaday-deploy.sh restart

  # Check health
  sudo ./wishaday-deploy.sh status

  # Custom domain
  WISHADAY_DOMAIN=mysite.com sudo ./wishaday-deploy.sh quick-start

${BOLD}Quick Workflow:${NC}
  1. First time: sudo ./wishaday-deploy.sh quick-start
  2. To update: sudo ./wishaday-deploy.sh pull
  3. Check status: sudo ./wishaday-deploy.sh status
  4. View logs: sudo ./wishaday-deploy.sh logs

EOF
}

# ==================== Main ====================

main() {
    check_root

    case "${1:-help}" in
        quick-start|quickstart)
            quick_start
            ;;
        setup-system)
            header "System Setup"
            check_os
            setup_user
            install_dependencies
            install_nodejs
            setup_directories
            success "System setup complete. Run: sudo $0 setup-app"
            ;;
        setup-app)
            header "Application Setup"
            clone_repository
            setup_python_env
            setup_environment
            setup_database
            build_frontend
            fix_permissions
            success "App setup complete. Run: sudo $0 deploy"
            ;;
        deploy)
            header "Full Deployment"
            clone_repository
            setup_python_env
            setup_environment
            setup_database
            build_frontend
            fix_permissions
            setup_systemd_service
            setup_nginx_config
            restart_services
            setup_ssl
            sleep 2
            show_status
            success "Deployment complete!"
            ;;
        pull)
            pull_and_update
            ;;
        update)
            quick_update
            ;;
        start)
            start_services
            test_connectivity
            ;;
        stop)
            stop_services
            ;;
        restart)
            restart_services
            test_connectivity
            ;;
        status)
            show_status
            ;;
        diagnose)
            diagnose
            ;;
        logs)
            show_logs
            ;;
        backup)
            full_backup
            ;;
        monitor)
            monitor_realtime
            ;;
        clean)
            clean_build
            ;;
        fix-perms)
            fix_permissions
            ;;
        test)
            test_connectivity
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            error "Unknown command: $1. Use 'help' to see available commands."
            ;;
    esac
}

# ==================== Execute ====================

echo -e "${CYAN}${BOLD}"
echo "╔════════════════════════════════════════════════╗"
echo "║   Wishaday Easy Deployment Script v4.0        ║"
echo "╚════════════════════════════════════════════════╝"
echo -e "${NC}"

main "$@"