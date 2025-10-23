#!/bin/bash
# Setup script for Xray server deployment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }
echo_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

echo "╔════════════════════════════════════════════════════╗"
echo "║   Xray Server Setup - VLESS + REALITY + Vision    ║"
echo "║        with Statistical Obfuscation (DPI)         ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

# Step 1: Check if .env exists
if [ ! -f ".env" ]; then
    echo_warn ".env file not found. Creating from .env.example..."
    cp .env.example .env
    echo_info "Created .env file. Please edit it with your configuration:"
    echo "  nano .env"
    echo ""
    echo_error "Please configure .env file and run this script again."
    exit 1
fi

# Step 2: Load environment variables
echo_step "Loading configuration from .env..."
source .env

# Validate SERVER_ADDRESS is set
if [ -z "$SERVER_ADDRESS" ] || [[ "$SERVER_ADDRESS" == *"your-server"* ]]; then
    echo_error "SERVER_ADDRESS not set in .env file!"
    echo ""
    echo "Please edit .env and set your server's public IP or domain:"
    echo "  SERVER_ADDRESS=123.45.67.89"
    echo ""
    echo "Then run this script again."
    exit 1
fi

echo_info "Server address: $SERVER_ADDRESS"
echo ""

# Step 2.1: Auto-generate CLIENT_UUID if empty
if [ -z "$CLIENT_UUID" ]; then
    echo_step "Generating CLIENT_UUID..."
    CLIENT_UUID=$(docker run --rm ghcr.io/xtls/xray-core:latest uuid)
    echo_info "Generated UUID: $CLIENT_UUID"

    # Update .env file
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|^CLIENT_UUID=.*|CLIENT_UUID=$CLIENT_UUID|" .env
    else
        sed -i "s|^CLIENT_UUID=.*|CLIENT_UUID=$CLIENT_UUID|" .env
    fi
    echo_info "Updated .env with CLIENT_UUID"
    echo ""
fi

# Step 2.2: Auto-generate REALITY keys if empty
if [ -z "$REALITY_PRIVATE_KEY" ] || [ -z "$REALITY_PUBLIC_KEY" ]; then
    echo_step "Generating REALITY X25519 key pair..."

    # Generate keys using xray
    KEY_OUTPUT=$(docker run --rm ghcr.io/xtls/xray-core:latest x25519)
    REALITY_PRIVATE_KEY=$(echo "$KEY_OUTPUT" | grep "PrivateKey:" | awk '{print $2}')
    REALITY_PUBLIC_KEY=$(echo "$KEY_OUTPUT" | grep "Password:" | awk '{print $2}')

    echo_info "Generated Private Key: $REALITY_PRIVATE_KEY"
    echo_info "Generated Public Key: $REALITY_PUBLIC_KEY"

    # Update .env file
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|^REALITY_PRIVATE_KEY=.*|REALITY_PRIVATE_KEY=$REALITY_PRIVATE_KEY|" .env
        sed -i '' "s|^REALITY_PUBLIC_KEY=.*|REALITY_PUBLIC_KEY=$REALITY_PUBLIC_KEY|" .env
    else
        sed -i "s|^REALITY_PRIVATE_KEY=.*|REALITY_PRIVATE_KEY=$REALITY_PRIVATE_KEY|" .env
        sed -i "s|^REALITY_PUBLIC_KEY=.*|REALITY_PUBLIC_KEY=$REALITY_PUBLIC_KEY|" .env
    fi
    echo_info "Updated .env with REALITY keys"
    echo ""
fi

# Reload environment variables after updates
source .env

echo_info "Configuration loaded and auto-generated successfully"
echo ""

# Step 3: Generate config.json from template
echo_step "Generating config.json from template..."

if [ ! -f "config.template.json" ]; then
    echo_error "config.template.json not found!"
    exit 1
fi

# Parse arrays and convert to JSON (no jq needed!)
IFS=',' read -ra SERVER_NAMES_ARRAY <<< "$REALITY_SERVER_NAMES"
IFS=',' read -ra SHORT_IDS_ARRAY <<< "$REALITY_SHORT_IDS"

# Convert bash array to JSON array format
array_to_json() {
    local arr=("$@")
    local json="["
    for i in "${!arr[@]}"; do
        # Trim whitespace
        local item=$(echo "${arr[$i]}" | xargs)
        json+="\"$item\""
        if [ $i -lt $((${#arr[@]} - 1)) ]; then
            json+=","
        fi
    done
    json+="]"
    echo "$json"
}

SERVER_NAMES_JSON=$(array_to_json "${SERVER_NAMES_ARRAY[@]}")
SHORT_IDS_JSON=$(array_to_json "${SHORT_IDS_ARRAY[@]}")

# Replace placeholders in template
sed "s|CLIENT_UUID_PLACEHOLDER|$CLIENT_UUID|g" config.template.json | \
sed "s|REALITY_DEST_PLACEHOLDER|$REALITY_DEST|g" | \
sed "s|REALITY_PRIVATE_KEY_PLACEHOLDER|$REALITY_PRIVATE_KEY|g" | \
sed "s|\"REALITY_SERVER_NAMES_PLACEHOLDER\"|$SERVER_NAMES_JSON|g" | \
sed "s|\"REALITY_SHORT_IDS_PLACEHOLDER\"|$SHORT_IDS_JSON|g" > config.json

echo_info "config.json generated successfully"
echo ""

# Step 4: Display configuration summary
echo_step "Configuration Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Port:          ${XRAY_PORT:-443}"
echo "Client UUID:   $CLIENT_UUID"
echo "REALITY Dest:  $REALITY_DEST"
echo "Server Names:  $REALITY_SERVER_NAMES"
echo "Private Key:   ${REALITY_PRIVATE_KEY:0:20}..."
echo "Public Key:    ${REALITY_PUBLIC_KEY:0:20}... (for clients)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 5: Validate config
echo_step "Validating configuration..."
docker run --rm -v "$(pwd)/config.json:/etc/xray/config.json:ro" \
    ghcr.io/xtls/xray-core:latest run -test -c /etc/xray/config.json

if [ $? -eq 0 ]; then
    echo_info "✓ Configuration is valid!"
else
    echo_error "✗ Configuration validation failed!"
    exit 1
fi
echo ""

# Step 6: Generate VLESS URL
echo_step "Generating VLESS connection URL..."
./generate-vless-url.sh

echo ""
echo_info "Setup complete! Next steps:"
echo ""
echo "  1. Start the server:"
echo "     docker-compose up -d"
echo ""
echo "  2. Check logs:"
echo "     docker-compose logs -f"
echo ""
echo "  3. View VLESS URL again:"
echo "     ./generate-vless-url.sh"
echo ""
echo "  4. Test connectivity from client"
echo ""
