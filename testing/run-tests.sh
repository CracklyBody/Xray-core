#!/bin/bash
# Comprehensive test runner for Xray with Statistical Obfuscation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Step 1: Setup
echo_info "=== Step 1: Setting up test environment ==="

# Create necessary directories
mkdir -p captures configs certs scripts dpi-rules target-site

# Generate REALITY key pair if not exists
if [ ! -f "configs/reality_keys.txt" ]; then
    echo_info "Generating REALITY key pair..."
    # Use xray to generate keys (we'll do this in the container)
    echo "Keys will be generated in container"
fi

# Create simple test website
cat > target-site/index.html <<EOF
<!DOCTYPE html>
<html>
<head><title>Test Target</title></head>
<body><h1>Test Target Website</h1></body>
</html>
EOF

# Make scripts executable
chmod +x scripts/*.sh scripts/*.py 2>/dev/null || true

# Step 2: Build and start containers
echo_info "=== Step 2: Building and starting containers ==="
docker-compose down -v 2>/dev/null || true
docker-compose build --no-cache
docker-compose up -d

# Wait for services to be ready
echo_info "Waiting for services to start..."
sleep 10

# Step 3: Verify connectivity
echo_info "=== Step 3: Verifying basic connectivity ==="

# Check if server is running
if ! docker-compose ps | grep -q "xray-server.*Up"; then
    echo_error "Xray server failed to start"
    docker-compose logs xray-server
    exit 1
fi

# Check if client is running
if ! docker-compose ps | grep -q "xray-client.*Up"; then
    echo_error "Xray client failed to start"
    docker-compose logs xray-client
    exit 1
fi

echo_info "All containers are running"

# Step 4: Test connectivity through proxy
echo_info "=== Step 4: Testing connectivity through proxy ==="

# Test HTTP request through SOCKS proxy
echo_info "Testing HTTP request through proxy..."
if docker-compose exec -T xray-client curl -x socks5://127.0.0.1:10808 \
    --connect-timeout 10 \
    --max-time 30 \
    http://172.25.0.40/ > /dev/null 2>&1; then
    echo_info "✓ Connectivity test PASSED"
else
    echo_error "✗ Connectivity test FAILED"
    echo_info "Server logs:"
    docker-compose logs --tail=20 xray-server
    echo_info "Client logs:"
    docker-compose logs --tail=20 xray-client
    exit 1
fi

# Step 5: Capture traffic
echo_info "=== Step 5: Capturing traffic for analysis ==="

# Start packet capture
docker-compose exec -T dpi-simulator bash -c "
    nohup tcpdump -i eth0 -w /captures/test_capture.pcap \
        -s 0 'host 172.25.0.10 or host 172.25.0.20' \
        > /dev/null 2>&1 &
    echo \$! > /tmp/tcpdump.pid
"

sleep 2
echo_info "Packet capture started"

# Generate test traffic
echo_info "Generating test traffic..."
for i in {1..20}; do
    docker-compose exec -T xray-client curl -x socks5://127.0.0.1:10808 \
        --connect-timeout 5 \
        --max-time 10 \
        http://172.25.0.40/ > /dev/null 2>&1 || true
    sleep 0.5
done

sleep 2

# Stop packet capture
docker-compose exec -T dpi-simulator bash -c "
    if [ -f /tmp/tcpdump.pid ]; then
        kill \$(cat /tmp/tcpdump.pid) 2>/dev/null || true
        rm /tmp/tcpdump.pid
    fi
"

echo_info "Packet capture stopped"
sleep 2

# Step 6: Analyze captured traffic
echo_info "=== Step 6: Analyzing captured traffic ==="

# Check if capture file exists
if [ ! -f "captures/test_capture.pcap" ]; then
    echo_error "Capture file not found"
    exit 1
fi

# Run traffic analysis
echo_info "Running traffic analysis..."
if command -v python3 &> /dev/null; then
    python3 scripts/analyze_traffic.py captures/test_capture.pcap
else
    echo_warn "Python3 not found, skipping automated analysis"
    echo_info "You can analyze manually with: python3 scripts/analyze_traffic.py captures/test_capture.pcap"
fi

# Step 7: Display logs and summary
echo_info "=== Step 7: Summary ==="
echo_info "Test completed successfully!"
echo ""
echo_info "Server logs (last 30 lines):"
docker-compose logs --tail=30 xray-server
echo ""
echo_info "Client logs (last 30 lines):"
docker-compose logs --tail=30 xray-client
echo ""
echo_info "Capture files saved in: ${SCRIPT_DIR}/captures/"
echo_info "To analyze manually: python3 scripts/analyze_traffic.py captures/test_capture.pcap"
echo_info "To view with Wireshark: wireshark captures/test_capture.pcap"
echo ""
echo_info "To stop containers: docker-compose down"
echo_info "To view live logs: docker-compose logs -f"
