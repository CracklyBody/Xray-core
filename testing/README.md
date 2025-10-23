# Xray Statistical Obfuscation - Testing Framework

This directory contains a complete testing environment for the Xray-core statistical obfuscation module designed to evade DPI systems used in Russia and Iran.

## Architecture

The obfuscation wrapper sits between VLESS and Vision, adding three layers of statistical obfuscation:

```
Client → VLESS → [Obfuscation Wrapper] → Vision → REALITY → Transport → Server
                          ↓
                   ┌──────────────┐
                   │ Padding Engine│ - HTTP/3 packet size distribution
                   │ Timing Jitter │ - Exponential IAT randomization
                   │ Burst Shaping │ - HTTPS-like burst patterns
                   └──────────────┘
```

## Prerequisites

- Docker and Docker Compose
- Python 3.7+ (for traffic analysis)
- tshark/Wireshark (optional, for packet analysis)
- 4GB RAM minimum

## Quick Start

```bash
cd testing/
chmod +x run-tests.sh
./run-tests.sh
```

This will:
1. Build Xray with the obfuscation module
2. Start server, client, and DPI simulator containers
3. Test connectivity through the obfuscated proxy
4. Capture and analyze traffic patterns
5. Generate a detection resistance report

## Components

### 1. Xray Server (`xray-server`)
- IP: `172.25.0.10`
- Port: `443` (REALITY)
- Configuration: `configs/server.json`
- Features: VLESS + REALITY + Vision + Statistical Obfuscation

### 2. Xray Client (`xray-client`)
- IP: `172.25.0.20`
- SOCKS5 Proxy: `10808`
- HTTP Proxy: `10809`
- Configuration: `configs/client.json`

### 3. DPI Simulator (`dpi-simulator`)
- IP: `172.25.0.30`
- Purpose: Packet capture and traffic analysis
- Tools: tcpdump, tshark, Python analysis scripts

### 4. Test Target (`test-target`)
- IP: `172.25.0.40`
- Simple nginx server for testing

## Obfuscation Configuration

The obfuscation module uses the following default configuration (optimized for Russia/Iran):

- **Padding Mode**: `http3` - Mimics HTTP/3 QUIC packet size distribution
- **Timing Mode**: `exponential` - Exponential inter-arrival time jitter
- **Burst Pattern**: `https` - HTTPS-like burst patterns
- **Delay Range**: 0-50ms

Configuration is in `proxy/obfuscation/config.go`:

```go
obfConfig := obfuscation.DefaultConfig()
// Customize if needed:
// obfConfig.PaddingMode = "https"
// obfConfig.TimingMode = "normal"
// obfConfig.MaxDelayMs = 100
```

## Manual Testing

### Start Environment
```bash
docker-compose up -d
```

### Test Connectivity
```bash
# Via SOCKS5
docker-compose exec xray-client curl -x socks5://127.0.0.1:10808 http://172.25.0.40/

# Via HTTP proxy
docker-compose exec xray-client curl -x http://127.0.0.1:10809 http://172.25.0.40/
```

### Capture Traffic
```bash
# Start capture
docker-compose exec dpi-simulator tcpdump -i eth0 -w /captures/manual_capture.pcap \
    'host 172.25.0.10 or host 172.25.0.20'

# In another terminal, generate traffic
docker-compose exec xray-client curl -x socks5://127.0.0.1:10808 http://172.25.0.40/

# Stop capture with Ctrl+C
```

### Analyze Traffic
```bash
python3 scripts/analyze_traffic.py captures/manual_capture.pcap
```

## Traffic Analysis

The `analyze_traffic.py` script performs the following analyses:

### 1. Packet Size Analysis
- Distribution of packet sizes
- 3-gram pattern detection
- Comparison against HTTPS baseline

### 2. Timing Analysis
- Inter-arrival time (IAT) distribution
- Exponential vs uniform distribution detection
- Jitter analysis

### 3. Burst Pattern Analysis
- Burst size and frequency
- RTT round detection
- Comparison against normal HTTPS (1 RTT) vs TLS-in-TLS (2-3 RTT)

### 4. TLS-in-TLS Detection
Based on USENIX Security 2024 research:
- **Normal HTTPS**: ~200-300 byte initial burst, 1 RTT
- **TLS-in-TLS**: ~500-700 byte initial burst, 2-3 RTT
- **Detection Score**: 0-1.0 (>0.5 = likely TLS-in-TLS detected)

### Success Criteria

✓ **Good obfuscation** (target):
- Detection score < 0.3
- Average handshake burst: 200-350 bytes
- Total bursts in first 10 packets: ≤ 2
- Entropy: 7.9-8.0 bits/byte

✗ **Poor obfuscation** (needs improvement):
- Detection score > 0.5
- Average handshake burst: 500-900 bytes
- Total bursts in first 10 packets: > 3
- Clear TLS-in-TLS signature visible

## Viewing Logs

```bash
# All logs
docker-compose logs -f

# Server only
docker-compose logs -f xray-server

# Client only
docker-compose logs -f xray-client
```

## Troubleshooting

### Build Failures
```bash
# Clean rebuild
docker-compose down -v
docker-compose build --no-cache
```

### Connection Failures
```bash
# Check server logs
docker-compose logs xray-server | grep -i error

# Check client logs
docker-compose logs xray-client | grep -i error

# Test without proxy
docker-compose exec xray-client curl http://172.25.0.40/
```

### Capture Issues
```bash
# Verify network
docker network inspect testing_test-network

# Check DPI simulator
docker-compose exec dpi-simulator ip addr
```

## Advanced Testing

### Performance Benchmarking
```bash
# Throughput test
docker-compose exec xray-client sh -c "
    dd if=/dev/zero bs=1M count=100 2>/dev/null | \
    curl -x socks5://127.0.0.1:10808 \
         --upload-file - \
         http://172.25.0.40/upload \
         -o /dev/null \
         -w 'Speed: %{speed_upload} bytes/sec\n'
"
```

### Entropy Testing
```bash
# Extract payload and check entropy
tshark -r captures/test_capture.pcap -T fields -e data | \
    xxd -r -p | \
    ent
# Target: Entropy = 7.9-8.0 bits per byte
```

### Long-Duration Testing
```bash
# 24-hour stability test
docker-compose up -d
for i in {1..86400}; do
    docker-compose exec -T xray-client curl -x socks5://127.0.0.1:10808 \
        http://172.25.0.40/ > /dev/null 2>&1 || true
    sleep 1
done
```

## Files Structure

```
testing/
├── README.md                     # This file
├── docker-compose.yml            # Container orchestration
├── Dockerfile.server             # Xray server image
├── Dockerfile.client             # Xray client image
├── run-tests.sh                  # Automated test runner
├── configs/
│   ├── server.json               # Server configuration
│   └── client.json               # Client configuration
├── scripts/
│   ├── capture-traffic.sh        # Traffic capture script
│   └── analyze_traffic.py        # Traffic analysis script
├── captures/                     # Packet captures (generated)
└── target-site/                  # Test website files
```

## Research Background

This obfuscation module is based on the following research:

1. **USENIX Security 2024**: "Fingerprinting Obfuscated Proxy Traffic with Encapsulated TLS Handshakes"
   - TLS-in-TLS detection via statistical analysis
   - Chi-squared test on packet size 3-grams
   - Burst pattern analysis

2. **ACM CCS 2019**: "Geneva: Evolving Censorship Evasion Strategies"
   - Automated evasion strategy discovery
   - Genetic algorithms for packet manipulation

3. **NDSS 2024**: "obfs4: The Pluggable Transport"
   - Polymorphic protocol techniques
   - Timing obfuscation strategies

## Next Steps

1. **Real-world Testing**: Deploy to a VPS and test against actual DPI
2. **Parameter Tuning**: Adjust padding/timing based on test results
3. **Security Audit**: Professional cryptographic review
4. **Performance Optimization**: Reduce latency overhead
5. **CI/CD Integration**: Automated testing on commits

## Contact

For issues or questions about the obfuscation module, see:
- Main README: `/README.md`
- Research document: `/research_vpn.md`
- Module code: `/proxy/obfuscation/`
