#!/bin/bash
# Generate VLESS URL for easy client configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if .env exists
if [ ! -f ".env" ]; then
    echo "Error: .env file not found!"
    echo "Run ./setup.sh first"
    exit 1
fi

# Load configuration
source .env

# Validate required variables
if [ -z "$CLIENT_UUID" ] || [ -z "$REALITY_PUBLIC_KEY" ] || [ -z "$SERVER_ADDRESS" ]; then
    echo "Error: Missing required configuration in .env"
    echo "Required: CLIENT_UUID, REALITY_PUBLIC_KEY, SERVER_ADDRESS"
    exit 1
fi

# Parse configuration
PORT="${XRAY_PORT:-443}"
SERVER_NAME=$(echo "$REALITY_SERVER_NAMES" | cut -d',' -f1 | xargs)
SHORT_ID=$(echo "$REALITY_SHORT_IDS" | cut -d',' -f2 | xargs)
[ -z "$SHORT_ID" ] && SHORT_ID=$(echo "$REALITY_SHORT_IDS" | cut -d',' -f1 | xargs)

# URL encode function
urlencode() {
    local string="$1"
    local strlen=${#string}
    local encoded=""
    local pos c o

    for (( pos=0 ; pos<strlen ; pos++ )); do
        c=${string:$pos:1}
        case "$c" in
            [-_.~a-zA-Z0-9] ) o="${c}" ;;
            * ) printf -v o '%%%02x' "'$c"
        esac
        encoded+="${o}"
    done
    echo "${encoded}"
}

# Build VLESS URL
# Format: vless://uuid@server:port?params#remark
PARAMS="encryption=none"
PARAMS="${PARAMS}&flow=xtls-rprx-vision"
PARAMS="${PARAMS}&security=reality"
PARAMS="${PARAMS}&sni=${SERVER_NAME}"
PARAMS="${PARAMS}&fp=chrome"
PARAMS="${PARAMS}&pbk=${REALITY_PUBLIC_KEY}"
PARAMS="${PARAMS}&sid=${SHORT_ID}"
PARAMS="${PARAMS}&type=tcp"
PARAMS="${PARAMS}&headerType=none"

REMARK=$(urlencode "Xray-REALITY-Vision")
VLESS_URL="vless://${CLIENT_UUID}@${SERVER_ADDRESS}:${PORT}?${PARAMS}#${REMARK}"

# Generate QR code ASCII (optional)
QR_CODE=""
if command -v qrencode &> /dev/null; then
    QR_CODE=$(qrencode -t ANSIUTF8 "$VLESS_URL")
fi

# Display results
echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║          Xray VLESS Connection Details            ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""
echo "Server Information:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Address:      $SERVER_ADDRESS"
echo "Port:         $PORT"
echo "UUID:         $CLIENT_UUID"
echo "Flow:         xtls-rprx-vision"
echo "Protocol:     VLESS"
echo "Transport:    TCP"
echo "Security:     REALITY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "REALITY Settings:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SNI:          $SERVER_NAME"
echo "Public Key:   $REALITY_PUBLIC_KEY"
echo "Short ID:     $SHORT_ID"
echo "Fingerprint:  chrome"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "VLESS URL (copy this to your client):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$VLESS_URL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Save to file
echo "$VLESS_URL" > vless_url.txt
echo "✓ VLESS URL saved to: vless_url.txt"
echo ""

# Display QR code if available
if [ -n "$QR_CODE" ]; then
    echo "QR Code (scan with mobile client):"
    echo "$QR_CODE"
    echo ""
fi

echo "Compatible Clients:"
echo "  • v2rayN (Windows)"
echo "  • V2RayNG (Android)"
echo "  • Shadowrocket (iOS)"
echo "  • Qv2ray (Linux/macOS/Windows)"
echo "  • Hiddify (iOS/Android)"
echo "  • Nekoray (Windows/Linux)"
echo ""

echo "Import Instructions:"
echo "  1. Copy the VLESS URL above"
echo "  2. Open your client app"
echo "  3. Click 'Import from Clipboard' or 'Add Server'"
echo "  4. Paste the URL"
echo "  5. Connect!"
echo ""

# Generate client config JSON
echo "Generating client config JSON..."
cat > client-config.json <<EOF
{
  "remarks": "Xray REALITY Vision",
  "server": "$SERVER_ADDRESS",
  "port": $PORT,
  "uuid": "$CLIENT_UUID",
  "flow": "xtls-rprx-vision",
  "encryption": "none",
  "network": "tcp",
  "type": "none",
  "security": "reality",
  "reality": {
    "publicKey": "$REALITY_PUBLIC_KEY",
    "shortId": "$SHORT_ID",
    "serverName": "$SERVER_NAME",
    "fingerprint": "chrome",
    "spiderX": "/"
  }
}
EOF

echo "✓ Client config saved to: client-config.json"
echo ""
echo "Full Xray client config:"
echo "  See: ../client/ directory for complete client setup"
echo ""
