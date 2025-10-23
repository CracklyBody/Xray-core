#!/bin/bash
# Generate REALITY key pair for Xray

set -e

echo "=== Xray REALITY Key Generator ==="
echo ""

# Check if xray is available
if ! command -v xray &> /dev/null; then
    echo "Error: xray binary not found!"
    echo "Please install xray first or use Docker:"
    echo "  docker run --rm ghcr.io/xtls/xray-core:latest x25519"
    exit 1
fi

# Generate key pair
echo "Generating X25519 key pair..."
OUTPUT=$(xray x25519)

# Parse output
PRIVATE_KEY=$(echo "$OUTPUT" | grep "Private key:" | awk '{print $3}')
PUBLIC_KEY=$(echo "$OUTPUT" | grep "Public key:" | awk '{print $3}')

echo ""
echo "✓ Keys generated successfully!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Private Key (for server): $PRIVATE_KEY"
echo "Public Key (for client):  $PUBLIC_KEY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Update .env if it exists
if [ -f ".env" ]; then
    echo "Do you want to update .env file with these keys? (y/N)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        # Backup existing .env
        cp .env .env.backup

        # Update keys
        sed -i.bak "s|^REALITY_PRIVATE_KEY=.*|REALITY_PRIVATE_KEY=$PRIVATE_KEY|" .env
        sed -i.bak "s|^REALITY_PUBLIC_KEY=.*|REALITY_PUBLIC_KEY=$PUBLIC_KEY|" .env
        rm .env.bak

        echo "✓ .env file updated (backup saved as .env.backup)"
    fi
fi

echo ""
echo "Next steps:"
echo "1. Copy the Private Key to your server config.json"
echo "2. Copy the Public Key to your client config or share with users"
echo "3. Run: ./setup.sh to generate the full configuration"
echo ""
