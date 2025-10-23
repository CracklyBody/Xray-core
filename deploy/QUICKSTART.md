# Quick Start - 3 Commands to Deploy!

Get your Xray server running with **just 3 commands**!

## Server Setup (2 minutes)

```bash
# 1. Clone repo and configure (ONLY set your server IP!)
git clone https://github.com/xtls/Xray-core.git
cd Xray-core/deploy/server/
cp .env.example .env
nano .env
# Set: SERVER_ADDRESS=your-server-ip
# Save and exit (Ctrl+X, Y, Enter)

# 2. Setup (auto-generates UUID, REALITY keys, configs)
./setup.sh

# 3. Start server
docker-compose up -d
```

**That's it!** Everything else is auto-generated:
- ✅ UUID
- ✅ REALITY keys
- ✅ Configuration files
- ✅ VLESS URL

**Get your VLESS URL:**
```bash
./generate-vless-url.sh
```

**Copy the VLESS URL** - you'll need it for the client!

---

## Client Setup (2 minutes)

### Desktop (Windows/Mac)

1. **Download client:**
   - Windows: [v2rayN](https://github.com/2dust/v2rayN/releases)
   - Mac: [Nekoray](https://github.com/MatsuriDayo/nekoray/releases)

2. **Import server:**
   - Copy VLESS URL from server
   - Open client → Import from Clipboard
   - Connect!

### Mobile (Android/iOS)

1. **Download app:**
   - Android: [V2RayNG](https://play.google.com/store/apps/details?id=com.v2ray.ang)
   - iOS: [Shadowrocket](https://apps.apple.com/app/shadowrocket/id932747118)

2. **Import server:**
   - Copy VLESS URL
   - Open app → Import from Clipboard
   - Connect!

### Linux (Docker)

```bash
cd Xray-core/deploy/client/
./setup.sh 'vless://your-url-here'
docker-compose up -d

# Test
curl -x socks5://127.0.0.1:10808 https://ifconfig.me
```

---

## Test It Works

**Desktop/Mobile apps:** Open browser, visit https://www.google.com

**Linux:**
```bash
curl -x socks5://127.0.0.1:10808 https://www.google.com
```

**Check your IP:**
```bash
curl -x socks5://127.0.0.1:10808 https://ifconfig.me
# Should show your server IP
```

---

## Troubleshooting

**Can't connect?**
```bash
# On server, check logs:
cd deploy/server
docker-compose logs -f

# Check firewall:
sudo ufw allow 443/tcp
```

**Still not working?** See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed guide.

---

## What You Built

- ✅ **VLESS Protocol**: High-performance proxy
- ✅ **REALITY**: Anti-detection (looks like normal HTTPS)
- ✅ **Vision/XTLS**: Advanced flow control
- ✅ **Statistical Obfuscation**: Evades Russia/Iran DPI
- ✅ **Production-ready**: Dockerized, auto-restart

---

**Next:** Share VLESS URL with friends, or add more users. See [DEPLOYMENT.md](DEPLOYMENT.md) for details.
