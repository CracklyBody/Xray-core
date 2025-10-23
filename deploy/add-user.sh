#!/bin/bash
#
# Add User Script - Generate additional client configurations
#

set -e

# Colors
GREEN='\033[0;32m'
NC='\033[0m'

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }

# Check if deployment-info.txt exists
if [ ! -f "deployment-info.txt" ]; then
    echo "Error: deployment-info.txt not found. Run setup.sh first."
    exit 1
fi

# Read deployment info
source <(grep -v '^#' deployment-info.txt | sed 's/: /=/g')

# Get user email
read -p "Enter user email/name (e.g., user@example.com): " USER_EMAIL

# Generate new UUID
NEW_UUID=$(cat /proc/sys/kernel/random/uuid)

echo_info "Generated UUID for ${USER_EMAIL}: ${NEW_UUID}"

# Create user config
cat > "user-${USER_EMAIL}-config.txt" <<EOF
===========================================
  Client Configuration for ${USER_EMAIL}
===========================================

Connection Details:
-------------------
Server: ${Domain}
Port: ${Port}
UUID: ${NEW_UUID}
Flow: xtls-rprx-vision

REALITY Settings:
-----------------
Server Name: ${Target Site}
Public Key: ${Public Key}
Short ID: ${Short ID}
Fingerprint: chrome

===========================================
  V2RayN / V2RayNG Link
===========================================
vless://${NEW_UUID}@${Domain}:${Port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${Target Site}&fp=chrome&pbk=${Public Key}&sid=${Short ID}&type=tcp&headerType=none#${USER_EMAIL}

===========================================
  JSON Configuration
===========================================
{
  "protocol": "vless",
  "settings": {
    "vnext": [
      {
        "address": "${Domain}",
        "port": ${Port},
        "users": [
          {
            "id": "${NEW_UUID}",
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
      "serverName": "${Target Site}",
      "publicKey": "${Public Key}",
      "shortId": "${Short ID}",
      "spiderX": "/"
    }
  }
}
EOF

echo_info "Client configuration saved to: user-${USER_EMAIL}-config.txt"
echo ""
echo "Next steps:"
echo "  1. Add this user to config.json in the 'clients' array:"
echo ""
echo "     {"
echo "       \"id\": \"${NEW_UUID}\","
echo "       \"flow\": \"xtls-rprx-vision\","
echo "       \"email\": \"${USER_EMAIL}\""
echo "     }"
echo ""
echo "  2. Restart Xray: docker-compose restart"
echo "  3. Share user-${USER_EMAIL}-config.txt with the user"
