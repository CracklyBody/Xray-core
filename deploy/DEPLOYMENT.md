# Production Deployment Guide - Xray Server & Client

Complete step-by-step guide for deploying Xray server and connecting clients.

## Table of Contents
- [Server Deployment](#server-deployment)
- [Client Setup](#client-setup)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

---

## Server Deployment

### Step 1: Prepare Your Server

**Requirements:**
- Linux VPS with public IP
- Ubuntu 20.04+ / Debian 10+ / CentOS 8+
- Minimum 512MB RAM, 10GB disk
- Root or sudo access
- Docker installed

**Install Docker (if not installed):**
```bash
curl -fsSL https://get.docker.com | sh
sudo systemctl start docker
sudo systemctl enable docker
```

### Step 2: Clone Repository

```bash
# Clone Xray-core
git clone https://github.com/xtls/Xray-core.git
cd Xray-core/deploy/server/
```

### Step 3: Configure Server

**Copy example configuration:**
```bash
cp .env.example .env
```

**Edit .env file:**
```bash
nano .env
```

**Configuration values to set:**

```bash
# === REQUIRED: Your server's public IP or domain ===
SERVER_ADDRESS=123.45.67.89
# Or use domain: SERVER_ADDRESS=your-domain.com

# === Port (default: 443 - looks like HTTPS traffic) ===
XRAY_PORT=443

# === Client UUID (leave empty for now, will generate) ===
CLIENT_UUID=

# === REALITY Keys (leave empty, will generate in next step) ===
REALITY_PRIVATE_KEY=
REALITY_PUBLIC_KEY=

# === REALITY Target Website (what to camouflage as) ===
#  Choose a major website with good TLS:
REALITY_DEST=www.microsoft.com:443
REALITY_SERVER_NAMES=www.microsoft.com,www.bing.com

# Popular alternatives:
#   www.apple.com:443 / www.apple.com
#   www.cloudflare.com:443 / www.cloudflare.com,cloudflare.com
#   www.amazon.com:443 / www.amazon.com

# === Short IDs for REALITY (leave as is) ===
REALITY_SHORT_IDS=,0123456789abcdef

# === Timezone (optional) ===
TIMEZONE=UTC
```

**Save and exit** (Ctrl+X, Y, Enter in nano)

### Step 4: Generate Keys

**Generate REALITY X25519 key pair:**

```bash
./generate-keys.sh
```

This will output something like:
```
Private Key (for server): YCwIrw38TKHYt1k_qKfv0ng6RvwDF46fHZZNZEF5YEo
Public Key (for client):  Z84J2IelR9ch3k8VtlVhhs5ycBUlXZrtQLjbdsttuVU
```

**Update .env automatically:**
When prompted, type `y` to update .env file with generated keys.

**Or update manually:**
```bash
nano .env
# Set:
REALITY_PRIVATE_KEY=<your-private-key>
REALITY_PUBLIC_KEY=<your-public-key>
```

**Generate UUID (if not set):**
```bash
docker run --rm ghcr.io/xtls/xray-core:latest uuid
```
Add to .env:
```bash
CLIENT_UUID=<generated-uuid>
```

### Step 5: Build and Deploy

**Run setup script:**
```bash
./setup.sh
```

This will:
1. ✅ Validate your configuration
2. ✅ Generate config.json from template
3. ✅ Test configuration syntax
4. ✅ Generate VLESS connection URL

If successful, you'll see:
```
✓ Configuration is valid!
Setup complete!
```

**Start the server:**
```bash
docker-compose up -d
```

**Verify it's running:**
```bash
docker-compose ps
```

You should see:
```
NAME          STATUS
xray-server   Up X seconds
```

**Check logs:**
```bash
docker-compose logs -f
```

Look for:
```
[Info] Xray 1.x.x started
[Info] VLESS TCP server started at [::]:443
```

Press Ctrl+C to exit logs.

### Step 6: Get Connection Details

**Generate VLESS URL for clients:**
```bash
./generate-vless-url.sh
```

This will display:
- ✅ Full connection details
- ✅ VLESS URL (starts with `vless://`)
- ✅ QR Code (if qrencode installed)
- ✅ Client JSON config

**Save the output!** You'll need it for client setup.

**Example output:**
```
╔════════════════════════════════════════════════════╗
║          Xray VLESS Connection Details            ║
╚════════════════════════════════════════════════════╝

Server Information:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Address:      123.45.67.89
Port:         443
UUID:         b831381d-6324-4d53-ad4f-8cda48b30811
Flow:         xtls-rprx-vision
Protocol:     VLESS
Transport:    TCP
Security:     REALITY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

REALITY Settings:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SNI:          www.microsoft.com
Public Key:   Z84J2IelR9ch3k8VtlVhhs5ycBUlXZrtQLjbdsttuVU
Short ID:     0123456789abcdef
Fingerprint:  chrome
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

VLESS URL (copy this to your client):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
vless://b831381d-6324-4d53-ad4f-8cda48b30811@123.45.67.89:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.microsoft.com&fp=chrome&pbk=Z84J2IelR9ch3k8VtlVhhs5ycBUlXZrtQLjbdsttuVU&sid=0123456789abcdef&type=tcp&headerType=none#Xray-REALITY-Vision
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**✅ Server setup complete!** Now set up your client.

---

## Client Setup

There are two options:
1. **GUI Clients** (easiest) - for Windows, Mac, Android, iOS
2. **Docker Client** - for Linux servers or advanced users

### Option 1: GUI Clients (Recommended)

#### Windows - v2rayN

1. **Download v2rayN:**
   - Go to: https://github.com/2dust/v2rayN/releases
   - Download latest `v2rayN-windows-64.zip`
   - Extract and run `v2rayN.exe`

2. **Import Configuration:**
   - Copy the VLESS URL from server output
   - In v2rayN: Click **"Servers"** → **"Import from Clipboard"**
   - The server will appear in the list

3. **Connect:**
   - Right-click the server
   - Click **"Set as Active Server"**
   - Click **"Enable System Proxy"** (bottom left)

4. **Test:**
   - Open browser and visit: https://www.google.com
   - Visit: https://ifconfig.me (should show server IP)

#### Android - V2RayNG

1. **Install V2RayNG:**
   - Play Store: https://play.google.com/store/apps/details?id=com.v2ray.ang
   - Or GitHub: https://github.com/2dust/v2rayNG/releases

2. **Import Configuration:**
   - Copy VLESS URL to clipboard
   - Open V2RayNG
   - Tap **"+"** → **"Import from Clipboard"**

3. **Connect:**
   - Tap the server to select it
   - Tap the connect button (bottom right)
   - Allow VPN permission

4. **Test:**
   - Open browser → visit https://www.google.com

#### iOS - Shadowrocket

1. **Install Shadowrocket:**
   - App Store: https://apps.apple.com/app/shadowrocket/id932747118
   - (Paid app, ~$2.99)

2. **Import Configuration:**
   - Copy VLESS URL
   - Open Shadowrocket
   - Tap **"+"** (top right)
   - Tap **"Paste from Clipboard"**

3. **Connect:**
   - Tap the server to select it
   - Toggle connection switch
   - Allow VPN configuration

4. **Test:**
   - Open Safari → visit https://www.google.com

#### macOS/Linux - Nekoray

1. **Download Nekoray:**
   - Go to: https://github.com/MatsuriDayo/nekoray/releases
   - Download for your platform
   - Install and run

2. **Import Configuration:**
   - Copy VLESS URL
   - In Nekoray: **"Server"** → **"New Profile"** → **"Import from Clipboard"**

3. **Connect:**
   - Select the server
   - Click **"Start"**
   - Enable system proxy if needed

### Option 2: Docker Client (Linux/Servers)

This option runs an Xray client that provides local SOCKS5/HTTP proxy.

#### Quick Setup with VLESS URL

```bash
cd /path/to/Xray-core/deploy/client/
./setup.sh 'vless://paste-your-url-here'
docker-compose up -d
```

#### Manual Setup

1. **Navigate to client directory:**
```bash
cd Xray-core/deploy/client/
```

2. **Create configuration:**
```bash
cp .env.example .env
nano .env
```

3. **Fill in connection details** (from server):
```bash
# Proxy ports (localhost only by default)
SOCKS_PORT=10808
HTTP_PORT=10809

# Server details (from server output)
SERVER_ADDRESS=123.45.67.89
SERVER_PORT=443
CLIENT_UUID=b831381d-6324-4d53-ad4f-8cda48b30811

# REALITY settings (from server)
REALITY_PUBLIC_KEY=Z84J2IelR9ch3k8VtlVhhs5ycBUlXZrtQLjbdsttuVU
REALITY_SERVER_NAME=www.microsoft.com
REALITY_SHORT_ID=0123456789abcdef

TIMEZONE=UTC
```

4. **Run setup:**
```bash
./setup.sh
```

5. **Start client:**
```bash
docker-compose up -d
```

6. **Verify it's running:**
```bash
docker-compose ps
docker-compose logs -f
```

7. **Test connection:**
```bash
# Test SOCKS5 proxy
curl -x socks5://127.0.0.1:10808 https://www.google.com

# Check IP (should show server IP)
curl -x socks5://127.0.0.1:10808 https://ifconfig.me

# Test HTTP proxy
curl -x http://127.0.0.1:10809 https://www.google.com
```

8. **Configure applications:**
   - SOCKS5 Proxy: `127.0.0.1:10808`
   - HTTP Proxy: `127.0.0.1:10809`

---

## Testing

### Test Server Connection

From another machine or your phone:
```bash
# Test if port is open
nc -zv your-server-ip 443

# Or
telnet your-server-ip 443
```

Should connect successfully.

### Test Client Proxy

```bash
# Check your IP without proxy
curl https://ifconfig.me

# Check your IP with proxy (should show server IP)
curl -x socks5://127.0.0.1:10808 https://ifconfig.me

# Test DNS resolution
curl -x socks5://127.0.0.1:10808 https://www.google.com

# Speed test
curl -x socks5://127.0.0.1:10808 -o /dev/null -w "Speed: %{speed_download} bytes/sec\n" \
  https://speed.cloudflare.com/__down?bytes=100000000
```

### Browser Testing

**Firefox:**
1. Settings → Network Settings
2. Manual proxy configuration
3. SOCKS Host: `127.0.0.1`, Port: `10808`
4. SOCKS v5
5. Proxy DNS when using SOCKS v5 ✓
6. Visit: https://www.google.com

---

## Troubleshooting

### Server Issues

**Server won't start:**
```bash
# Check logs
docker-compose logs xray

# Common issues:
# 1. Port 443 already in use
sudo netstat -tlnp | grep 443
# Solution: Change XRAY_PORT in .env

# 2. Invalid configuration
./setup.sh  # Re-run setup

# 3. Firewall blocking
sudo ufw allow 443/tcp
sudo ufw reload
```

**Check if server is listening:**
```bash
# From server
sudo netstat -tlnp | grep 443

# Should show:
# tcp6  0  0 :::443  :::*  LISTEN  <pid>/xray
```

**Validate configuration:**
```bash
docker-compose exec xray xray run -test -c /etc/xray/config.json
```

### Client Issues

**Can't connect to server:**

1. **Test network connectivity:**
```bash
ping your-server-ip
nc -zv your-server-ip 443
```

2. **Check client logs:**
```bash
docker-compose logs -f xray-client
```

3. **Common issues:**
   - Wrong UUID → Check CLIENT_UUID matches server
   - Wrong Public Key → Check REALITY_PUBLIC_KEY matches server
   - Wrong SNI → Check REALITY_SERVER_NAME matches server config
   - Firewall → Check server firewall allows port 443

4. **Enable debug logging:**
```bash
# In client config.json, change:
"loglevel": "debug"

# Restart:
docker-compose restart
docker-compose logs -f
```

**Slow connection:**
```bash
# Test server location latency
ping -c 10 your-server-ip

# Check server load
ssh your-server
docker stats xray-server

# Try different REALITY target
# Edit server config.json, change REALITY_DEST
```

### Connection Drops

**Keepalive issues:**
Edit `server/config.json`, add to streamSettings:
```json
"tcpSettings": {
  "header": {
    "type": "none"
  },
  "acceptProxyProtocol": false
}
```

Restart server:
```bash
docker-compose restart
```

### Firewall Configuration

**Ubuntu/Debian (UFW):**
```bash
sudo ufw allow 443/tcp
sudo ufw reload
sudo ufw status
```

**CentOS/RHEL (firewalld):**
```bash
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --reload
sudo firewall-cmd --list-ports
```

**Cloud Provider:**
- AWS: Edit Security Group → Add Inbound Rule → Port 443
- Google Cloud: VPC Firewall → Create Rule → Port 443
- DigitalOcean: Networking → Firewalls → Add Rule → Port 443

---

## Management Commands

### Server Management

```bash
cd deploy/server/

# View logs
docker-compose logs -f

# View last 100 lines
docker-compose logs --tail=100 xray

# Restart
docker-compose restart

# Stop
docker-compose stop

# Start
docker-compose start

# Rebuild after config changes
docker-compose down
./setup.sh
docker-compose up -d

# View stats
docker stats xray-server

# Update to latest Xray
git pull
docker-compose build --no-cache
docker-compose up -d
```

### Client Management

```bash
cd deploy/client/

# View logs
docker-compose logs -f

# Restart
docker-compose restart

# Stop
docker-compose stop

# Start
docker-compose start

# Rebuild
docker-compose down
./setup.sh
docker-compose up -d
```

### Backup Configuration

```bash
# Server
cd deploy/server/
tar -czf ~/xray-server-backup-$(date +%Y%m%d).tar.gz .env config.json

# Client
cd deploy/client/
tar -czf ~/xray-client-backup-$(date +%Y%m%d).tar.gz .env config.json
```

### Restore Configuration

```bash
tar -xzf xray-server-backup-YYYYMMDD.tar.gz
docker-compose up -d
```

---

## Success Checklist

### Server ✅
- [ ] Docker installed and running
- [ ] .env file configured with correct SERVER_ADDRESS
- [ ] REALITY keys generated
- [ ] UUID generated
- [ ] `./setup.sh` completed successfully
- [ ] `docker-compose up -d` running
- [ ] `docker-compose logs` shows "Xray started"
- [ ] Port 443 open in firewall
- [ ] VLESS URL generated

### Client ✅
- [ ] VLESS URL copied from server
- [ ] Client app installed (v2rayN, V2RayNG, etc.)
- [ ] Configuration imported successfully
- [ ] Connection established (green/connected status)
- [ ] Browser loads websites
- [ ] IP check shows server IP
- [ ] Speed test works

---

## Next Steps

After successful deployment:

1. **Share with friends:** Generate new UUIDs for each user
2. **Monitor performance:** Check logs and resource usage
3. **Keep updated:** Run `git pull && docker-compose up -d --build` monthly
4. **Add monitoring:** Set up Netdata or similar for server monitoring
5. **Test thoroughly:** From different networks (mobile, work, home)

---

**Need help?** Check the main README.md or open an issue on GitHub.
