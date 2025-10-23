# Easy Deployment Guide - Xray with Statistical Obfuscation

Deploy your own censorship-resistant proxy server in 5 minutes!

## Features

✅ **VLESS + REALITY + Vision** - Maximum stealth
✅ **Statistical Obfuscation** - Evades Russia/Iran DPI
✅ **One-Command Setup** - Automated deployment
✅ **Docker-Based** - Easy updates and management
✅ **Zero Configuration** - Everything auto-generated

## Quick Start (VPS Server)

### Prerequisites
- A VPS (1GB RAM minimum)
- Ubuntu 20.04+ / Debian 10+ / CentOS 7+
- Root access
- Open port 443 (or your chosen port)

### Installation

1. **SSH into your server**
```bash
ssh root@your-server-ip
```

2. **Clone repository and run setup**
```bash
# Download setup script
curl -O https://raw.githubusercontent.com/xtls/xray-core/main/deploy/setup.sh

# Make executable
chmod +x setup.sh

# Run setup (interactive)
sudo ./setup.sh
```

That's it! The script will:
- ✅ Install Docker if needed
- ✅ Generate REALITY keys automatically
- ✅ Create optimized configuration
- ✅ Build and start Xray server
- ✅ Generate client configurations

### What Happens During Setup

The setup script will ask you:

1. **Domain or IP**: Your server domain (or just use the detected IP)
2. **Port**: Default 443 (recommended for REALITY)
3. **Target Website**: Choose what REALITY will mimic
   - Microsoft (recommended)
   - Apple
   - Cloudflare
   - Custom

Everything else is auto-generated!

### After Setup

You'll get two files:

1. **`client-config.txt`** - Full client configuration with:
   - Connection details
   - JSON config for manual setup
   - vless:// link for easy import
   - QR code (if available)

2. **`deployment-info.txt`** - Server credentials (keep safe!)

## Client Setup

### For Windows (V2RayN)

1. Download [V2RayN](https://github.com/2dust/v2rayN/releases)
2. Open `client-config.txt` from your server
3. Copy the `vless://` link
4. In V2RayN: **Add Server → Import from Clipboard**
5. Connect!

### For Android (V2RayNG)

1. Install [V2RayNG](https://github.com/2dust/v2rayNG/releases)
2. Scan the QR code from setup
3. Or import the `vless://` link
4. Connect!

### For iOS (Shadowrocket)

1. Install Shadowrocket
2. Tap **+** → **Type: VLESS**
3. Enter details from `client-config.txt`:
   - Address: Your server IP/domain
   - Port: Your chosen port
   - UUID: From config
   - Flow: xtls-rprx-vision
   - TLS: reality
   - ServerName: Target website
   - PublicKey: From config
4. Save and connect!

### For macOS/Linux (Xray Core)

1. Install Xray:
```bash
# macOS
brew install xray

# Linux
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
```

2. Create `/usr/local/etc/xray/config.json` with JSON from `client-config.txt`

3. Start Xray:
```bash
sudo xray run -c /usr/local/etc/xray/config.json
```

4. Configure system proxy to `127.0.0.1:10808` (SOCKS5)

## Server Management

### View Logs
```bash
cd deploy/
docker-compose logs -f
```

### Stop Server
```bash
docker-compose stop
```

### Start Server
```bash
docker-compose start
```

### Restart Server
```bash
docker-compose restart
```

### Update Server
```bash
docker-compose pull
docker-compose up -d
```

### Check Status
```bash
docker-compose ps
```

### Uninstall
```bash
docker-compose down
docker system prune -a
```

## Manual Setup (Advanced)

If you prefer manual configuration:

### 1. Create `docker-compose.yml`
```yaml
version: '3.8'

services:
  xray:
    image: your-registry/xray-obfuscation:latest
    container_name: xray
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./config.json:/etc/xray/config.json:ro
      - ./logs:/var/log/xray
```

### 2. Create `config.json`

See `client-config.txt` from setup for the server config template.

### 3. Generate REALITY Keys

```bash
# Private key
openssl rand -base64 32

# Public key (use the corresponding X25519 public key)
# In production, use: xray x25519
```

### 4. Build and Run

```bash
docker-compose up -d
```

## Firewall Configuration

### UFW (Ubuntu/Debian)
```bash
sudo ufw allow 443/tcp
sudo ufw reload
```

### Firewalld (CentOS/RHEL)
```bash
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --reload
```

### Cloud Provider Firewall

Also configure your cloud provider's firewall (AWS Security Groups, Google Cloud Firewall, etc.) to allow your chosen port.

## Troubleshooting

### Server won't start
```bash
# Check logs
docker-compose logs

# Check if port is already in use
sudo netstat -tulpn | grep 443

# Try different port in setup
```

### Client can't connect
```bash
# Test from client
curl -v https://your-server-ip:443

# Check server firewall
sudo ufw status

# Verify config
docker-compose exec xray xray test -c /etc/xray/config.json
```

### Connection slow or unstable
```bash
# Check server resources
docker stats

# View real-time logs
docker-compose logs -f --tail=100

# Restart if needed
docker-compose restart
```

### Update to latest version
```bash
cd deploy/
docker-compose pull
docker-compose down
docker-compose up -d
```

## Advanced Configuration

### Custom Obfuscation Settings

To adjust obfuscation parameters, edit the source code:

File: `proxy/vless/encoding/addons.go`

```go
obfConfig := obfuscation.DefaultConfig()

// Customize:
obfConfig.PaddingMode = "https"      // http3, https, uniform
obfConfig.TimingMode = "normal"      // exponential, normal, uniform
obfConfig.MaxDelayMs = 100           // 0-200ms
obfConfig.Debug = true               // Enable debug logs
```

Then rebuild:
```bash
docker-compose build --no-cache
docker-compose up -d
```

### Multiple Users

Add more UUIDs to config.json:

```json
"clients": [
  {
    "id": "uuid-1",
    "flow": "xtls-rprx-vision",
    "email": "user1@xray"
  },
  {
    "id": "uuid-2",
    "flow": "xtls-rprx-vision",
    "email": "user2@xray"
  }
]
```

### Custom REALITY Targets

Edit `config.json`:

```json
"realitySettings": {
  "dest": "www.your-target.com:443",
  "serverNames": [
    "www.your-target.com",
    "your-target.com"
  ],
  ...
}
```

Good targets:
- **CDNs**: cloudflare.com, fastly.com
- **Tech giants**: microsoft.com, apple.com, amazon.com
- **Popular sites**: wikipedia.org, github.com

Avoid: Sites with strict certificate pinning or unusual TLS configs.

## Performance Tuning

### For High Traffic

Increase Docker resources:

```yaml
# docker-compose.yml
services:
  xray:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
```

### For Low Latency

Disable debug logging:

```json
"log": {
  "loglevel": "warning"
}
```

## Security Best Practices

1. ✅ **Change default port** if 443 is monitored
2. ✅ **Use strong UUIDs** (auto-generated is fine)
3. ✅ **Keep server updated** regularly
4. ✅ **Monitor logs** for suspicious activity
5. ✅ **Limit users** to trusted people only
6. ✅ **Use domain** instead of IP when possible
7. ✅ **Enable firewall** on server
8. ✅ **Regular backups** of config files

## Cost Estimates

### VPS Providers (Monthly)

- **Vultr**: $3.50/mo (512MB RAM, 10GB SSD)
- **DigitalOcean**: $4/mo (512MB RAM, 10GB SSD)
- **Linode**: $5/mo (1GB RAM, 25GB SSD)
- **Hetzner**: €4.51/mo (2GB RAM, 20GB SSD) - Best value
- **Oracle Cloud**: FREE tier (1GB RAM) - Free forever

Recommended: **Hetzner** for best price/performance.

## Comparison with Other Solutions

| Feature | This Setup | Shadowsocks | WireGuard | OpenVPN |
|---------|-----------|-------------|-----------|---------|
| **DPI Resistance** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐ |
| **Speed** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Stealth** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐ |
| **Easy Setup** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ |
| **Mobile Support** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |

## FAQ

**Q: Is this legal?**
A: Using VPNs/proxies is legal in most countries. Check your local laws.

**Q: Can it be detected?**
A: Designed to resist Russia/Iran DPI. No solution is 100% undetectable, but this uses the latest research-backed techniques.

**Q: How many users can connect?**
A: Depends on your VPS specs. 1GB RAM = ~10-20 concurrent users.

**Q: Does it work on mobile?**
A: Yes! Use V2RayNG (Android) or Shadowrocket (iOS).

**Q: How do I update?**
A: Run: `docker-compose pull && docker-compose up -d`

**Q: What if my server gets blocked?**
A: Change the port, or deploy to a new IP. REALITY makes blocking harder.

**Q: Can I use my own domain?**
A: Yes! Just enter it during setup. Make sure DNS points to your server.

## Support

- **Issues**: [GitHub Issues](https://github.com/xtls/xray-core/issues)
- **Research**: See `/research_vpn.md`
- **Obfuscation Module**: See `/proxy/obfuscation/`
- **Testing**: See `/testing/README.md`

## Credits

- **Xray-core**: [XTLS Project](https://github.com/XTLS/Xray-core)
- **REALITY Protocol**: Advanced TLS steganography
- **Research Foundation**: USENIX Security 2024, NDSS 2024, ACM CCS 2019
- **Statistical Obfuscation**: This implementation

---

**Ready to deploy?** Run `./setup.sh` on your server!
