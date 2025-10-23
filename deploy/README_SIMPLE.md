# Simple Deployment - Zero Configuration

## The Simplest Way to Deploy Xray

You literally only need to provide **ONE thing**: Your server's IP address.

Everything else is **100% automatic**.

## Server Deployment

### Step 1: Edit .env (30 seconds)

```bash
cd deploy/server/
cp .env.example .env
nano .env
```

**Change ONLY this line:**
```bash
SERVER_ADDRESS=123.45.67.89  # Your server IP
```

That's it. Leave everything else as-is.

### Step 2: Run Setup (auto-generates everything)

```bash
./setup.sh
```

This automatically generates:
- ✅ Client UUID
- ✅ REALITY Private Key
- ✅ REALITY Public Key
- ✅ Server configuration files
- ✅ VLESS connection URL

You don't touch anything. It's all automatic.

### Step 3: Start Server

```bash
docker-compose up -d
```

Done! Server is running.

### Step 4: Get Connection URL

```bash
./generate-vless-url.sh
```

Copy the `vless://` URL. Share with clients. That's it.

## What You DON'T Need to Do

❌ Generate UUID manually
❌ Run separate key generation scripts
❌ Edit complex JSON configs
❌ Copy/paste keys between files
❌ Validate configuration manually
❌ Create VLESS URLs manually

All of that is **automated**.

## Example: Real-World Setup

```bash
# SSH into your VPS
ssh root@123.45.67.89

# Install Docker (if needed)
curl -fsSL https://get.docker.com | sh

# Clone repo
git clone https://github.com/xtls/Xray-core.git
cd Xray-core/deploy/server/

# Configure (ONLY set your IP)
cp .env.example .env
echo "SERVER_ADDRESS=123.45.67.89" >> .env

# Auto-generate everything and start
./setup.sh
docker-compose up -d

# Get VLESS URL
./generate-vless-url.sh
```

Total time: **2 minutes**

Total manual steps: **Set your IP address**

## What Happens Automatically

When you run `./setup.sh`:

```
[STEP] Loading configuration from .env...
[INFO] Server address: 123.45.67.89

[STEP] Generating CLIENT_UUID...
[INFO] Generated UUID: a1b2c3d4-5678-90ab-cdef-1234567890ab
[INFO] Updated .env with CLIENT_UUID

[STEP] Generating REALITY X25519 key pair...
[INFO] Generated Private Key: YCwIrw38TKHYt1k_qKfv0ng6...
[INFO] Generated Public Key: Z84J2IelR9ch3k8VtlVhhs5...
[INFO] Updated .env with REALITY keys

[INFO] Configuration loaded and auto-generated successfully

[STEP] Generating config.json from template...
[INFO] config.json generated successfully

[STEP] Configuration Summary:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Port:          443
Client UUID:   a1b2c3d4-5678-90ab-cdef-1234567890ab
REALITY Dest:  www.microsoft.com:443
Server Names:  www.microsoft.com,www.bing.com
Private Key:   YCwIrw38TKHYt1k_qKfv...
Public Key:    Z84J2IelR9ch3k8VtlVh... (for clients)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[STEP] Validating configuration...
✓ Configuration is valid!

[STEP] Generating VLESS connection URL...

╔════════════════════════════════════════════════════╗
║          Xray VLESS Connection Details            ║
╚════════════════════════════════════════════════════╝

VLESS URL (copy this to your client):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
vless://a1b2c3d4-5678-90ab-cdef-1234567890ab@123.45.67.89:443?...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[INFO] Setup complete!
```

## Client Connection

### Desktop/Mobile (Easiest)

1. Copy the `vless://` URL
2. Open your client app
3. Import from clipboard
4. Connect

### Linux/Docker

```bash
cd deploy/client/
./setup.sh 'vless://your-url-here'
docker-compose up -d
```

## Customization (Optional)

Want to use a different website for REALITY camouflage?

Edit `.env` BEFORE running `setup.sh`:

```bash
REALITY_DEST=www.apple.com:443
REALITY_SERVER_NAMES=www.apple.com
```

Popular choices:
- `www.microsoft.com:443` (default)
- `www.apple.com:443`
- `www.cloudflare.com:443`
- `www.amazon.com:443`

## Re-generating Keys

Want new keys? Just clear them in `.env`:

```bash
# Clear these lines in .env:
CLIENT_UUID=
REALITY_PRIVATE_KEY=
REALITY_PUBLIC_KEY=

# Run setup again:
./setup.sh

# New keys will be generated!
```

## Comparison: Old vs New Way

### ❌ Old Way (Manual)
```bash
# Generate UUID
docker run --rm ghcr.io/xtls/xray-core:latest uuid
# Copy output to .env

# Generate keys
./generate-keys.sh
# Type 'y' to save

# Edit config template manually
nano config.template.json
# Replace all PLACEHOLDER values

# Validate config
docker run --rm -v $(pwd)/config.json:/etc/xray/config.json xray run -test

# Create VLESS URL manually
# Construct URL with all parameters...

# Start server
docker-compose up -d
```

**Steps:** 8+
**Time:** 10+ minutes
**Error-prone:** Yes

### ✅ New Way (Automatic)
```bash
# Edit .env (set SERVER_ADDRESS only)
nano .env

# Auto-generate everything
./setup.sh

# Start server
docker-compose up -d
```

**Steps:** 3
**Time:** 2 minutes
**Error-prone:** No

## Files Generated Automatically

After running `./setup.sh`, you'll have:

- `config.json` - Complete server configuration
- `vless_url.txt` - VLESS connection URL
- `client-config.json` - Client configuration JSON
- `.env` (updated with generated keys)

All ready to use!

## Security

Auto-generated values are:
- ✅ **Cryptographically secure** - Using official Xray generators
- ✅ **Unique** - Different every time
- ✅ **Random** - Properly randomized
- ✅ **Saved** - Stored in .env for future reference

## Support

**Too long, didn't read?**

Just run this on your server:

```bash
cd deploy/server/
cp .env.example .env
nano .env  # Set SERVER_ADDRESS=your-ip
./setup.sh
docker-compose up -d
./generate-vless-url.sh
```

Copy the VLESS URL. Done.

---

**Documentation:**
- Quick start: [QUICKSTART.md](QUICKSTART.md)
- Detailed guide: [DEPLOYMENT.md](DEPLOYMENT.md)
- Installation: [INSTALL.md](INSTALL.md)
