#!/bin/bash
# Traffic capture script for DPI simulator

CAPTURE_DIR="/captures"
DURATION="${1:-60}"  # Default 60 seconds
INTERFACE="${2:-eth0}"

echo "=== Xray Traffic Capture ==="
echo "Duration: ${DURATION} seconds"
echo "Interface: ${INTERFACE}"
echo "Output: ${CAPTURE_DIR}"
echo "=========================="

# Capture traffic between client and server
tcpdump -i "${INTERFACE}" -w "${CAPTURE_DIR}/capture_$(date +%Y%m%d_%H%M%S).pcap" \
    -s 0 \
    'host 172.25.0.10 or host 172.25.0.20' &

TCPDUMP_PID=$!

echo "Capturing traffic (PID: ${TCPDUMP_PID})..."
echo "Press Ctrl+C to stop, or wait ${DURATION} seconds"

# Wait for specified duration
sleep "${DURATION}"

# Stop tcpdump
kill -INT "${TCPDUMP_PID}" 2>/dev/null
wait "${TCPDUMP_PID}" 2>/dev/null

echo "Capture complete!"
echo "Files saved in: ${CAPTURE_DIR}"
ls -lh "${CAPTURE_DIR}"
