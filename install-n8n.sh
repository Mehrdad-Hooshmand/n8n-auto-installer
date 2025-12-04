#!/bin/bash

# ============================================
# n8n Auto Installer with Docker & SSL
# Author: Your Name
# GitHub: https://github.com/yourusername/n8n-installer
# ============================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root. Use: sudo bash install-n8n.sh"
        exit 1
    fi
}

# Function to check system requirements
check_requirements() {
    print_message "Checking system requirements..."
    
    # Check if Ubuntu
    if ! grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
        print_warning "This script is optimized for Ubuntu. Other distributions may work but are not tested."
    fi
    
    # Check memory
    total_mem=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$total_mem" -lt 1024 ]; then
        print_warning "System has less than 1GB RAM. n8n may run slowly."
    fi
}

# Banner
show_banner() {
    echo -e "${BLUE}"
    cat << "EOF"
    ╔═══════════════════════════════════════════════╗
    ║                                               ║
    ║        n8n Automated Installer v1.0           ║
    ║        Docker + Nginx + SSL                   ║
    ║                                               ║
    ╚═══════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Main installation function
main() {
    clear
    show_banner
    check_root
    check_requirements
    
    # Ask for domain
    echo ""
    print_message "Enter your domain name (e.g., n8n.example.com):"
    read -p "Domain: " DOMAIN < /dev/tty
    
    if [ -z "$DOMAIN" ]; then
        print_error "Domain cannot be empty!"
        exit 1
    fi
    
    # Validate domain format
    if ! [[ "$DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        print_error "Invalid domain format!"
        exit 1
    fi
    
    echo ""
    print_warning "IMPORTANT: Before continuing, make sure:"
    echo "  1. DNS A/AAAA record for '$DOMAIN' points to this server"
    echo "  2. Cloudflare Proxy is DISABLED (DNS only mode)"
    echo "  3. Ports 80 and 443 are not in use"
    echo ""
    
    # Ask for confirmation
    read -p "Have you configured DNS correctly? (yes/no): " DNS_CONFIRM < /dev/tty
    
    if [[ ! "$DNS_CONFIRM" =~ ^[Yy][Ee][Ss]$ ]]; then
        print_error "Please configure DNS first and run the script again."
        exit 1
    fi
    
    # Ask for email
    echo ""
    read -p "Enter your email for SSL certificate notifications: " EMAIL < /dev/tty
    
    if [ -z "$EMAIL" ]; then
        print_error "Email cannot be empty!"
        exit 1
    fi
    
    echo ""
    print_message "Starting installation with the following settings:"
    echo "  Domain: $DOMAIN"
    echo "  Email: $EMAIL"
    echo ""
    read -p "Press Enter to continue or Ctrl+C to cancel..." < /dev/tty
    
    # Start installation
    echo ""
    print_message "=== Step 1/7: Updating system packages ==="
    apt update -qq && apt upgrade -y -qq
    print_success "System updated successfully"
    
    echo ""
    print_message "=== Step 2/7: Installing Docker ==="
    
    # Remove old Docker versions
    apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Install dependencies
    apt install -y ca-certificates curl gnupg lsb-release
    
    # Add Docker GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    apt update -qq
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    print_success "Docker installed: $(docker --version)"
    
    echo ""
    print_message "=== Step 3/7: Creating n8n directory ==="
    mkdir -p /opt/n8n
    cd /opt/n8n
    print_success "Directory created: /opt/n8n"
    
    echo ""
    print_message "=== Step 4/7: Generating configuration files ==="
    
    # Create docker-compose.yml
    cat > /opt/n8n/docker-compose.yml << EOF
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    environment:
      - N8N_HOST=${DOMAIN}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://${DOMAIN}/
      - GENERIC_TIMEZONE=UTC
    volumes:
      - n8n_data:/home/node/.n8n
    networks:
      - n8n-network

  nginx:
    image: nginx:alpine
    container_name: n8n-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - /opt/n8n/certbot_certs:/etc/letsencrypt:ro
    depends_on:
      - n8n
    networks:
      - n8n-network

  certbot:
    image: certbot/certbot
    container_name: n8n-certbot
    volumes:
      - /opt/n8n/certbot_certs:/etc/letsencrypt
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait \$\${!}; done;'"

volumes:
  n8n_data:

networks:
  n8n-network:
    driver: bridge
EOF
    
    # Create nginx.conf
    cat > /opt/n8n/nginx.conf << EOF
events {
    worker_connections 1024;
}

http {
    # HTTP Server - Redirect to HTTPS
    server {
        listen 80;
        server_name ${DOMAIN};

        location / {
            return 301 https://\$host\$request_uri;
        }
    }

    # HTTPS Server
    server {
        listen 443 ssl http2;
        server_name ${DOMAIN};

        # SSL Configuration
        ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_prefer_server_ciphers on;
        ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;

        # Security Headers
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;

        # Client Max Body Size
        client_max_body_size 50M;

        # Proxy to n8n
        location / {
            proxy_pass http://n8n:5678;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;

            # WebSocket Support
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";

            # Timeouts
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }
    }
}
EOF
    
    print_success "Configuration files created"
    
    echo ""
    print_message "=== Step 5/7: Obtaining SSL certificate ==="
    print_message "This may take a few moments..."
    
    # Stop any service using port 80
    systemctl stop nginx 2>/dev/null || true
    docker stop n8n-nginx 2>/dev/null || true
    
    # Obtain SSL certificate
    if docker run --rm -p 80:80 -v /opt/n8n/certbot_certs:/etc/letsencrypt certbot/certbot certonly \
        --standalone \
        -d ${DOMAIN} \
        --email ${EMAIL} \
        --agree-tos \
        --no-eff-email \
        --non-interactive; then
        print_success "SSL certificate obtained successfully"
    else
        print_error "Failed to obtain SSL certificate. Please check:"
        echo "  1. DNS is correctly configured"
        echo "  2. Port 80 is accessible from internet"
        echo "  3. Domain points to this server"
        exit 1
    fi
    
    echo ""
    print_message "=== Step 6/7: Starting n8n services ==="
    cd /opt/n8n
    docker compose up -d
    
    # Wait for services to start
    sleep 5
    
    # Check if containers are running
    if docker ps | grep -q "n8n"; then
        print_success "n8n is running"
    else
        print_error "n8n failed to start. Check logs with: docker compose logs n8n"
        exit 1
    fi
    
    if docker ps | grep -q "n8n-nginx"; then
        print_success "Nginx is running"
    else
        print_error "Nginx failed to start. Check logs with: docker compose logs nginx"
        exit 1
    fi
    
    echo ""
    print_message "=== Step 7/7: Configuring firewall ==="
    
    if command -v ufw &> /dev/null; then
        ufw --force enable
        ufw allow 22/tcp
        ufw allow 80/tcp
        ufw allow 443/tcp
        print_success "Firewall configured"
    else
        print_warning "UFW not found. Please configure firewall manually."
    fi
    
    # Final success message
    echo ""
    echo -e "${GREEN}"
    cat << "EOF"
    ╔═══════════════════════════════════════════════╗
    ║                                               ║
    ║     ✓ Installation Completed Successfully!    ║
    ║                                               ║
    ╚═══════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo ""
    print_success "n8n is now accessible at: https://${DOMAIN}"
    echo ""
    print_message "Next steps:"
    echo "  1. Visit https://${DOMAIN} in your browser"
    echo "  2. Create your admin account"
    echo "  3. Enable Cloudflare Proxy (orange cloud) in DNS settings"
    echo "  4. Set Cloudflare SSL/TLS mode to 'Full (strict)'"
    echo ""
    print_message "Useful commands:"
    echo "  • View logs: cd /opt/n8n && docker compose logs -f"
    echo "  • Restart: cd /opt/n8n && docker compose restart"
    echo "  • Stop: cd /opt/n8n && docker compose down"
    echo "  • Update: cd /opt/n8n && docker compose pull && docker compose up -d"
    echo ""
    print_message "Installation directory: /opt/n8n"
    print_message "SSL certificates: /opt/n8n/certbot_certs"
    echo ""
}

# Run main function
main
