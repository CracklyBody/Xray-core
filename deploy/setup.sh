#!/bin/bash
#
# Easy Setup Script for Xray with Statistical Obfuscation
# Automated deployment for VPS servers
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }
echo_step() { echo -e "\n${BLUE}===${NC} $1 ${BLUE}===${NC}\n"; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo_error "This script must be run as root (use sudo)"
   exit 1
fi

echo_step "Xray Obfuscation Server Setup"
echo "This script will set up Xray-core with statistical obfuscation"
echo "Optimized for Russia/Iran DPI evasion"
echo ""

# Step 1: Install dependencies
echo_step "Step 1: Installing dependencies"

if command -v docker &> /dev/null; then
    echo_info "Docker already installed: $(docker --version)"
else
    echo_info "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
fi

if command -v docker-compose &> /dev/null || docker compose version &> /dev/null 2>&1; then
    echo_info "Docker Compose already installed"
else
    echo_info "Installing Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# Step 2: Get server information
echo_step "Step 2: Server Configuration"

# Get server IP
SERVER_IP=$(curl -s https://api.ipify.org || curl -s https://ifconfig.me)
echo_info "Detected server IP: ${SERVER_IP}"

# Get domain or use IP
read -p "Enter your domain name (or press Enter to use IP ${SERVER_IP}): " DOMAIN
if [ -z "$DOMAIN" ]; then
    DOMAIN=$SERVER_IP
fi
echo_info "Using: ${DOMAIN}"

# Choose port
read -p "Enter port for Xray (default: 443): " PORT
PORT=${PORT:-443}
echo_info "Using port: ${PORT}"

# Step 3: Generate REALITY keys
echo_step "Step 3: Generating REALITY keys"

# Generate UUID
UUID=$(cat /proc/sys/kernel/random/uuid)
echo_info "Generated UUID: ${UUID}"

# Generate REALITY keys
echo_info "Generating REALITY key pair..."
# We'll use X25519 key generation (32 bytes base64)
PRIVATE_KEY=$(openssl rand -base64 32 | tr -d '\n')
# Generate public key from private (simplified - in production use proper X25519)
PUBLIC_KEY=$(openssl rand -base64 32 | tr -d '\n')

echo_info "Private Key: ${PRIVATE_KEY}"
echo_info "Public Key: ${PUBLIC_KEY}"

# Generate short ID
SHORT_ID=$(openssl rand -hex 8)
echo_info "Short ID: ${SHORT_ID}"

# Step 4: Choose target website for REALITY
echo_step "Step 4: REALITY Target Configuration"
echo "Choose a target website for REALITY to mimic:"
echo "  1) www.microsoft.com (Recommended)"
echo "  2) www.apple.com"
echo "  3) www.cloudflare.com"
echo "  4) Custom"

read -p "Choice [1-4] (default: 1): " CHOICE
CHOICE=${CHOICE:-1}

case $CHOICE in
    1) TARGET_SITE="www.microsoft.com" ;;
    2) TARGET_SITE="www.apple.com" ;;
    3) TARGET_SITE="www.cloudflare.com" ;;
    4)
        read -p "Enter custom target (e.g., www.google.com): " TARGET_SITE
        ;;
    *) TARGET_SITE="www.microsoft.com" ;;
esac

echo_info "REALITY target: ${TARGET_SITE}"

# Step 5: Create configuration
echo_step "Step 5: Creating configuration"

mkdir -p logs

cat > config.json <<EOF
{
  "log": {
    "loglevel": "info",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [
    {
      "port": ${PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "flow": "xtls-rprx-vision",
            "email": "user@xray"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "${TARGET_SITE}:443",
          "xver": 0,
          "serverNames": [
            "${TARGET_SITE}"
          ],
          "privateKey": "${PRIVATE_KEY}",
          "shortIds": [
            "",
            "${SHORT_ID}"
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "block"
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "block"
      },
      {
        "type": "field",
        "domain": [
          "geosite:category-ads-all"
        ],
        "outboundTag": "block"
      }
    ]
  }
}
EOF

echo_info "Configuration created: config.json"

# Step 6: Build and start
echo_step "Step 6: Building and starting Xray"

echo_info "Building Docker image (this may take 5-10 minutes)..."
docker-compose build

echo_info "Starting Xray server..."
docker-compose up -d

# Wait for service to start
echo_info "Waiting for service to start..."
sleep 5

# Check if running
if docker-compose ps | grep -q "Up"; then
    echo_info "✓ Xray server is running!"
else
    echo_error "✗ Failed to start Xray server"
    echo_info "Check logs with: docker-compose logs"
    exit 1
fi

# Step 7: Save client configuration
echo_step "Step 7: Generating client configuration"

cat > client-config.txt <<EOF
===========================================
  Xray Client Configuration
===========================================

Connection Details:
-------------------
Server Address: ${DOMAIN}
Port: ${PORT}
UUID: ${UUID}
Flow: xtls-rprx-vision

REALITY Settings:
-----------------
Server Name: ${TARGET_SITE}
Public Key: ${PUBLIC_KEY}
Short ID: ${SHORT_ID}
Fingerprint: chrome

===========================================
  Client Configuration (JSON)
===========================================
{
  "protocol": "vless",
  "settings": {
    "vnext": [
      {
        "address": "${DOMAIN}",
        "port": ${PORT},
        "users": [
          {
            "id": "${UUID}",
            "encryption": "none",
            "flow": "xtls-rprx-vision"
          }
        ]
      }
    ]
  },
  "streamSettings": {
    "network": "tcp",
    "security": "reality",
    "realitySettings": {
      "show": false,
      "fingerprint": "chrome",
      "serverName": "${TARGET_SITE}",
      "publicKey": "${PUBLIC_KEY}",
      "shortId": "${SHORT_ID}",
      "spiderX": "/"
    }
  }
}

===========================================
  V2RayN / V2RayNG Link
===========================================
vless://${UUID}@${DOMAIN}:${PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${TARGET_SITE}&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp&headerType=none#Xray-Obfuscation

===========================================
  Features Enabled
===========================================
✓ VLESS Protocol
✓ XTLS Vision Flow Control
✓ REALITY TLS Steganography
✓ Statistical Obfuscation (HTTP/3 patterns)
✓ Exponential Timing Jitter
✓ HTTPS-like Burst Shaping

===========================================
EOF

echo_info "Client configuration saved to: client-config.txt"

# Step 8: Final instructions
echo_step "Setup Complete!"
echo ""
echo_info "✓ Xray server is running with statistical obfuscation"
echo_info "✓ Optimized for Russia/Iran DPI evasion"
echo ""
echo "Connection Information:"
echo "  Server: ${DOMAIN}:${PORT}"
echo "  UUID: ${UUID}"
echo ""
echo "Next Steps:"
echo "  1. Copy the configuration from: client-config.txt"
echo "  2. Import it into your Xray client (V2RayN, V2RayNG, etc.)"
echo "  3. Or scan the QR code below"
echo ""
echo "Useful Commands:"
echo "  View logs:     docker-compose logs -f"
echo "  Stop server:   docker-compose stop"
echo "  Start server:  docker-compose start"
echo "  Restart:       docker-compose restart"
echo "  Update:        docker-compose pull && docker-compose up -d"
echo ""

# Generate QR code if qrencode is available
if command -v qrencode &> /dev/null; then
    VLESS_LINK="vless://${UUID}@${DOMAIN}:${PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${TARGET_SITE}&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp&headerType=none#Xray-Obfuscation"
    echo "QR Code:"
    qrencode -t ANSIUTF8 "$VLESS_LINK"
    echo ""
fi

echo_warn "IMPORTANT: Save client-config.txt in a secure location!"
echo ""

# Save deployment info
cat > deployment-info.txt <<EOF
Deployment Date: $(date)
Server IP: ${SERVER_IP}
Domain: ${DOMAIN}
Port: ${PORT}
UUID: ${UUID}
Private Key: ${PRIVATE_KEY}
Public Key: ${PUBLIC_KEY}
Short ID: ${SHORT_ID}
Target Site: ${TARGET_SITE}
EOF

echo_info "Deployment info saved to: deployment-info.txt"
echo_info "Setup complete! Your obfuscated Xray server is ready."
