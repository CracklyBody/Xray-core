#!/bin/bash
# Setup script for Xray client deployment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }
echo_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

echo "╔════════════════════════════════════════════════════╗"
echo "║           Xray Client Setup (VLESS)               ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

# Check for VLESS URL import
if [ -n "$1" ] && [[ "$1" == vless://* ]]; then
    echo_step "Importing from VLESS URL..."
    VLESS_URL="$1"

    # Parse VLESS URL (basic parsing)
    # Format: vless://uuid@server:port?params#remark
    URL_PART="${VLESS_URL#vless://}"
    UUID="${URL_PART%%@*}"
    REST="${URL_PART#*@}"
    SERVER="${REST%%:*}"
    REST="${REST#*:}"
    PORT="${REST%%\?*}"
    PARAMS="${REST#*\?}"
    PARAMS="${PARAMS%%#*}"

    # Parse query parameters
    PUBLIC_KEY=$(echo "$PARAMS" | grep -oP 'pbk=\K[^&]+' || echo "")
    SERVER_NAME=$(echo "$PARAMS" | grep -oP 'sni=\K[^&]+' || echo "")
    SHORT_ID=$(echo "$PARAMS" | grep -oP 'sid=\K[^&]+' || echo "")

    # Create .env from parsed values
    cat > .env <<EOF
SOCKS_PORT=10808
HTTP_PORT=10809
TIMEZONE=UTC
SERVER_ADDRESS=$SERVER
SERVER_PORT=$PORT
CLIENT_UUID=$UUID
REALITY_PUBLIC_KEY=$PUBLIC_KEY
REALITY_SERVER_NAME=$SERVER_NAME
REALITY_SHORT_ID=$SHORT_ID
EOF

    echo_info "Imported configuration from VLESS URL"
    echo ""
fi

# Step 1: Check if .env exists
if [ ! -f ".env" ]; then
    echo_warn ".env file not found. Creating from .env.example..."
    cp .env.example .env
    echo_info "Created .env file. Please edit it with connection details from your server:"
    echo "  nano .env"
    echo ""
    echo "Or run this script with VLESS URL:"
    echo "  ./setup.sh 'vless://...'"
    echo ""
    echo_error "Please configure .env file and run this script again."
    exit 1
fi

# Step 2: Load environment variables
echo_step "Loading configuration from .env..."
source .env

# Validate required variables
REQUIRED_VARS=("SERVER_ADDRESS" "SERVER_PORT" "CLIENT_UUID" "REALITY_PUBLIC_KEY" "REALITY_SERVER_NAME")
MISSING_VARS=()

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ] || [[ "${!var}" == *"YourPublicKeyHere"* ]] || [[ "${!var}" == *"your-server"* ]]; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo_error "Missing or invalid configuration:"
    for var in "${MISSING_VARS[@]}"; do
        echo "  - $var"
    done
    echo ""
    echo "Please get these values from your server administrator or VLESS URL"
    exit 1
fi

echo_info "Configuration loaded successfully"
echo ""

# Step 3: Generate config.json from template
echo_step "Generating config.json from template..."

if [ ! -f "config.template.json" ]; then
    echo_error "config.template.json not found!"
    exit 1
fi

# Replace placeholders
sed "s|SERVER_ADDRESS_PLACEHOLDER|$SERVER_ADDRESS|g" config.template.json | \
sed "s|SERVER_PORT_PLACEHOLDER|$SERVER_PORT|g" | \
sed "s|CLIENT_UUID_PLACEHOLDER|$CLIENT_UUID|g" | \
sed "s|REALITY_PUBLIC_KEY_PLACEHOLDER|$REALITY_PUBLIC_KEY|g" | \
sed "s|REALITY_SERVER_NAME_PLACEHOLDER|$REALITY_SERVER_NAME|g" | \
sed "s|REALITY_SHORT_ID_PLACEHOLDER|${REALITY_SHORT_ID:-}|g" > config.json

echo_info "config.json generated successfully"
echo ""

# Step 4: Display configuration summary
echo_step "Configuration Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Server:        $SERVER_ADDRESS:$SERVER_PORT"
echo "UUID:          $CLIENT_UUID"
echo "REALITY SNI:   $REALITY_SERVER_NAME"
echo "Public Key:    ${REALITY_PUBLIC_KEY:0:20}..."
echo "SOCKS Proxy:   0.0.0.0:${SOCKS_PORT:-10808}"
echo "HTTP Proxy:    0.0.0.0:${HTTP_PORT:-10809}"
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

echo_info "Setup complete! Next steps:"
echo ""
echo "  1. Start the client:"
echo "     docker-compose up -d"
echo ""
echo "  2. Check logs:"
echo "     docker-compose logs -f"
echo ""
echo "  3. Configure your applications to use:"
echo "     SOCKS5: 127.0.0.1:${SOCKS_PORT:-10808}"
echo "     HTTP:   127.0.0.1:${HTTP_PORT:-10809}"
echo ""
echo "  4. Test connectivity:"
echo "     curl -x socks5://127.0.0.1:${SOCKS_PORT:-10808} https://www.google.com"
echo ""
