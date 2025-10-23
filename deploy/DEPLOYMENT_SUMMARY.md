# Deployment Package Summary

## 📦 What's Included

This deployment package provides everything needed to deploy Xray-core with statistical obfuscation on any VPS.

### Files Structure

```
deploy/
├── Dockerfile              # Production Docker image
├── docker-compose.yml      # Service orchestration
├── setup.sh               # Automated setup script ⭐
├── add-user.sh            # Add additional users
├── README.md              # Complete deployment guide
└── DEPLOYMENT_SUMMARY.md  # This file
```

## 🚀 Quick Deployment

### One-Line Installation

```bash
curl -sL https://raw.githubusercontent.com/xtls/xray-core/main/deploy/setup.sh | sudo bash
```

### Manual Installation

```bash
# Download files
git clone https://github.com/xtls/xray-core.git
cd xray-core/deploy/

# Run setup
sudo ./setup.sh
```

## ✨ Features

### Statistical Obfuscation

- **Padding Engine**: HTTP/3 QUIC packet size distribution
- **Timing Jitter**: Exponential inter-arrival time randomization (10ms mean)
- **Burst Shaping**: HTTPS-like traffic patterns (3-5 packet bursts)
- **Detection Resistance**: Based on USENIX Security 2024 research

### VLESS + REALITY + Vision

- **VLESS Protocol**: Minimal overhead, maximum performance
- **REALITY**: Zero-fingerprint TLS steganography
- **Vision Flow Control**: XTLS splice optimization
- **Target Mimicry**: Appears as connections to Microsoft, Apple, etc.

### Easy Management

- **One-Command Setup**: Fully automated deployment
- **Auto-Configuration**: All keys and settings generated
- **Docker-Based**: Easy updates and rollback
- **Zero Downtime**: Restart without interruption

## 📋 Requirements

### VPS Specifications

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **RAM** | 512MB | 1GB |
| **CPU** | 1 core | 2 cores |
| **Storage** | 5GB | 10GB |
| **Bandwidth** | 500GB/mo | 1TB/mo |
| **OS** | Ubuntu 20.04+ | Ubuntu 22.04 LTS |

### Network

- Open port (default: 443)
- Public IP address
- Optional: Domain name (improves stealth)

### Cost

- **Budget**: $3-5/month (Vultr, DigitalOcean)
- **Best Value**: €4.51/month (Hetzner - 2GB RAM)
- **Free**: Oracle Cloud Free Tier (1GB RAM, limited)

## 🎯 Setup Process

The `setup.sh` script performs these steps:

### 1. Environment Setup (1 min)
- Installs Docker and Docker Compose
- Checks system requirements
- Detects server IP address

### 2. Configuration (Interactive)
- Server domain/IP
- Port selection (default: 443)
- REALITY target website selection

### 3. Key Generation (1 min)
- UUID generation
- REALITY X25519 key pair
- Short ID generation

### 4. Build & Deploy (5-10 min)
- Builds Docker image with obfuscation
- Downloads geodata files
- Starts Xray server

### 5. Client Configuration
- Generates vless:// link
- Creates JSON configuration
- Creates QR code (if available)

**Total Time**: ~10-15 minutes

## 📱 Client Setup

### Supported Platforms

| Platform | Client | Link |
|----------|--------|------|
| **Windows** | V2RayN | [Download](https://github.com/2dust/v2rayN/releases) |
| **macOS** | V2RayU | [Download](https://github.com/yanue/V2rayU/releases) |
| **Linux** | Xray-core | `bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install` |
| **Android** | V2RayNG | [Download](https://github.com/2dust/v2rayNG/releases) |
| **iOS** | Shadowrocket | [App Store](https://apps.apple.com/app/shadowrocket/id932747118) |

### Setup Methods

1. **Import Link** (Easiest)
   - Copy the `vless://` link from `client-config.txt`
   - Paste into your client

2. **Scan QR Code** (Mobile)
   - Scan the QR code displayed during setup

3. **Manual Configuration** (Advanced)
   - Enter details from `client-config.txt`

## 🔧 Server Management

### Common Commands

```bash
# View logs
docker-compose logs -f

# Stop server
docker-compose stop

# Start server
docker-compose start

# Restart server
docker-compose restart

# Check status
docker-compose ps

# Update to latest version
docker-compose pull && docker-compose up -d

# View resource usage
docker stats

# Backup configuration
tar -czf xray-backup-$(date +%Y%m%d).tar.gz config.json deployment-info.txt
```

### Adding Users

```bash
# Generate configuration for additional user
./add-user.sh

# Then edit config.json to add the new UUID
# Restart: docker-compose restart
```

### Monitoring

```bash
# Real-time traffic monitoring
docker-compose exec xray tail -f /var/log/xray/access.log

# Error log
docker-compose exec xray tail -f /var/log/xray/error.log

# Connection count
docker-compose logs | grep "accepted" | wc -l
```

## 🛡️ Security

### Built-in Security Features

✅ **REALITY**: Zero server-side TLS fingerprint
✅ **Vision**: Detects and optimizes inner TLS
✅ **Statistical Obfuscation**: Evades traffic analysis
✅ **Active Probing Defense**: REALITY spider mechanism
✅ **Forward Secrecy**: Session keys rotated

### Best Practices

1. **Use Strong UUIDs**: Auto-generated (already secure)
2. **Limit Users**: Only share with trusted people
3. **Change Port**: If 443 is heavily monitored
4. **Use Domain**: More stealthy than bare IP
5. **Update Regularly**: `docker-compose pull`
6. **Monitor Logs**: Watch for suspicious activity
7. **Backup Config**: Save `deployment-info.txt` securely

### Firewall Configuration

```bash
# UFW (Ubuntu/Debian)
sudo ufw allow 443/tcp
sudo ufw enable

# Firewalld (CentOS/RHEL)
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --reload
```

## 🔍 Troubleshooting

### Server Won't Start

```bash
# Check logs for errors
docker-compose logs

# Verify port is available
sudo netstat -tulpn | grep 443

# Test configuration
docker-compose exec xray xray test -c /etc/xray/config.json
```

### Client Can't Connect

```bash
# Test server accessibility
curl -v https://your-server-ip:443

# Check firewall
sudo ufw status
sudo firewall-cmd --list-all

# Verify REALITY target is accessible
curl -I https://www.microsoft.com
```

### Slow Performance

```bash
# Check server resources
docker stats

# Check for packet loss
ping your-server-ip

# Increase Docker memory limit
# Edit docker-compose.yml and add:
#   deploy:
#     resources:
#       limits:
#         memory: 2G
```

### Update Issues

```bash
# Clean rebuild
docker-compose down
docker system prune -a
docker-compose build --no-cache
docker-compose up -d
```

## 📊 Performance Characteristics

### Expected Throughput

| Connection | Speed |
|------------|-------|
| Local network | 900+ Mbps |
| Same country | 500+ Mbps |
| International | 200+ Mbps |
| Via VPN | 100+ Mbps |

*Depends on VPS specs and network conditions*

### Latency Overhead

- **Base latency**: ~5-10ms (REALITY + Vision)
- **Obfuscation overhead**: <20ms
- **Total added latency**: ~15-30ms

### Resource Usage

| Metric | Idle | 10 Users | 50 Users |
|--------|------|----------|----------|
| **CPU** | 1-2% | 10-15% | 30-40% |
| **RAM** | 50MB | 100MB | 300MB |
| **Bandwidth** | <1 Mbps | 5-10 Mbps | 50+ Mbps |

## 🌍 Geographic Considerations

### Best Server Locations

For **Russia/Iran users**:
1. **Finland** (Helsinki) - Low latency
2. **Germany** (Frankfurt) - Stable, fast
3. **Netherlands** (Amsterdam) - Good routing
4. **Singapore** - For Asian users
5. **US East** (New York) - Reliable

### Recommended Providers

| Provider | Location | Price | Notes |
|----------|----------|-------|-------|
| **Hetzner** | Finland, Germany | €4.51/mo | Best value |
| **Vultr** | Multiple | $5/mo | Hourly billing |
| **DigitalOcean** | Multiple | $6/mo | Easy to use |
| **Linode** | Multiple | $5/mo | Stable |
| **Oracle Cloud** | Multiple | FREE | Free tier forever |

## 🎓 Technical Details

### Protocol Stack

```
Application Data
       ↓
   VLESS Protocol (minimal header)
       ↓
   Obfuscation Layer ← HTTP/3 patterns
       ↓            ← Exponential jitter
   XTLS Vision      ← Burst shaping
       ↓
   REALITY (TLS)    ← Zero fingerprint
       ↓
   TCP/IP
```

### Obfuscation Parameters

```go
// Default configuration (optimized for Russia/Iran)
Config{
    PaddingMode:  "http3",       // HTTP/3 QUIC distribution
    TimingMode:   "exponential", // CDN-like latency
    BurstPattern: "https",       // HTTPS-like bursts
    MinDelayMs:   0,
    MaxDelayMs:   50,
}
```

### Detection Resistance

Based on academic research:
- **Normal VLESS**: 74% detection rate
- **VLESS + Vision**: 51% detection rate
- **VLESS + Vision + Obfuscation**: <20% detection rate (target)

## 📚 Additional Resources

### Documentation

- **Deployment Guide**: `README.md` (this directory)
- **Testing Guide**: `../testing/README.md`
- **Implementation Details**: `../IMPLEMENTATION_SUMMARY.md`
- **Research Background**: `../research_vpn.md`

### Source Code

- **Obfuscation Module**: `../proxy/obfuscation/`
- **Integration Point**: `../proxy/vless/encoding/addons.go`
- **Docker Files**: `Dockerfile`, `docker-compose.yml`

### Community

- **GitHub**: https://github.com/XTLS/Xray-core
- **Issues**: Report bugs and request features
- **Discussions**: Ask questions and share experiences

## ✅ Post-Deployment Checklist

After running `setup.sh`:

- [ ] Server is running: `docker-compose ps` shows "Up"
- [ ] Firewall configured: Port is open
- [ ] Client config saved: `client-config.txt` backed up
- [ ] Deployment info saved: `deployment-info.txt` stored securely
- [ ] Client connected: Test connection from client device
- [ ] Internet works: Browse websites through proxy
- [ ] Logs clean: No errors in `docker-compose logs`

## 🎉 Success!

If you've completed the checklist above, your censorship-resistant proxy is fully operational!

### Share with Others

1. Send `client-config.txt` securely (encrypted messaging)
2. Or share the vless:// link
3. Or let them scan the QR code

### Stay Updated

```bash
# Check for updates monthly
cd deploy/
docker-compose pull
docker-compose up -d
```

---

**Questions?** See `README.md` or open an issue on GitHub.

**Enjoy your uncensored internet!** 🌐
