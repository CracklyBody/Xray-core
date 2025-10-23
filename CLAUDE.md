# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Xray-core is a high-performance network proxy platform implementing XTLS protocol and supporting multiple proxy protocols including VLESS, VMess, Trojan, Shadowsocks, SOCKS, and HTTP. It's forked from v2ray-core with significant enhancements.

**Key protocols and features:**
- VLESS with XTLS-Vision and REALITY (anti-detection)
- XHTTP (advanced HTTP-based transport)
- Multiple transport layers: TCP, UDP, WebSocket, HTTP/2 (gRPC), QUIC, splithttp, httpupgrade
- Advanced routing with domain/IP matching
- DNS resolution with DoH, DoQ support
- Observatory for connection health monitoring

## Build and Development Commands

### Building

**Standard build:**
```bash
# Linux/macOS
CGO_ENABLED=0 go build -o xray -trimpath -buildvcs=false -ldflags="-s -w -buildid=" -v ./main

# Windows (PowerShell)
$env:CGO_ENABLED=0
go build -o xray.exe -trimpath -buildvcs=false -ldflags="-s -w -buildid=" -v ./main
```

**Reproducible builds (with git commit):**
```bash
# Replace 'REPLACE' with 7-byte git commit hash
CGO_ENABLED=0 go build -o xray -trimpath -buildvcs=false -gcflags="all=-l=4" -ldflags="-X github.com/xtls/xray-core/core.build=REPLACE -s -w -buildid=" -v ./main
```

**For 32-bit MIPS/MIPSLE:**
```bash
CGO_ENABLED=0 go build -o xray -trimpath -buildvcs=false -gcflags="-l=4" -ldflags="-X github.com/xtls/xray-core/core.build=REPLACE -s -w -buildid=" -v ./main
```

### Testing

**Run all tests:**
```bash
go test -timeout 1h -v ./...
```

**Run specific package tests:**
```bash
go test -v ./app/dispatcher
go test -v ./proxy/vless
```

**Run single test:**
```bash
go test -v ./app/router -run TestRouter
```

### Running

**Run with config:**
```bash
./xray run -c config.json
./xray run -config config.json  # alternative

# Multiple config files
./xray run -c config1.json -c config2.json

# Config directory (all JSON files)
./xray run -confdir /path/to/configs
```

**Test config without running:**
```bash
./xray run -test -c config.json
```

**Dump merged config:**
```bash
./xray run -dump -c config.json
```

**Supported config formats:** JSON (default), TOML, YAML (auto-detected or use `-format`)

### Code Generation

**Regenerate protobuf files:**
```bash
go generate ./...
```

This regenerates `.pb.go` files from `.proto` definitions.

## Architecture

### Core Components

**`core/` - Instance & Configuration**
- `Instance`: Main server instance managing all features
- Feature dependency resolution system
- Context-based feature management
- Essential features auto-initialized: DNS client, policy manager, router, stats

**`app/` - Application Features**
Features implement `features.Feature` interface (HasType + Runnable):

- **dispatcher**: Routes connections between inbound and outbound, handles sniffing (protocol detection)
- **dns**: DNS client with multiple nameserver types (UDP, TCP, DoH, DoQ, FakeDNS)
- **router**: Advanced routing based on domain, IP, protocol, source, user; supports balancing strategies
- **proxyman**: Manages inbound/outbound handlers, worker pools
- **policy**: User-level policies (timeouts, buffer sizes)
- **stats**: Traffic statistics collection
- **log**: Logging system
- **commander**: gRPC API for runtime management
- **observatory**: Health checking and latency measurement for outbounds
- **reverse**: Reverse proxy (bridge/portal)

**`proxy/` - Protocol Implementations**
Each proxy implements `Inbound` and/or `Outbound` interfaces:

- **vless**: VLESS protocol with vision (XTLS flow control) and REALITY support
- **vmess**: VMess protocol with AEAD encryption
- **trojan**: Trojan protocol
- **shadowsocks**: Classic Shadowsocks
- **shadowsocks_2022**: Modern Shadowsocks 2022 edition
- **socks**: SOCKS4/4a/5 proxy
- **http**: HTTP/HTTPS proxy
- **dokodemo**: Transparent proxy (any door)
- **freedom**: Direct connection outbound
- **dns**: DNS outbound
- **wireguard**: WireGuard VPN integration
- **blackhole**: Drop connections
- **loopback**: Internal loopback

**`transport/internet/` - Transport Layer**
Handles connection establishment and stream encryption:

- **tls**: TLS 1.3 with uTLS fingerprinting
- **reality**: Anti-detection TLS (steals TLS handshake from real servers)
- **tcp**: Raw TCP with header obfuscation
- **udp**: UDP with XUDP support
- **websocket**: WebSocket transport
- **httpupgrade**: HTTP upgrade transport
- **splithttp**: Split HTTP transport for bypass
- **grpc**: HTTP/2 gRPC transport
- **kcp**: KCP (UDP-based reliable transport)
- **quic**: QUIC transport
- **dialer.go**: Connection dialing with Happy Eyeballs (dual-stack)
- **system_dialer.go**: System-level dialer with DNS integration
- **sockopt_*.go**: Platform-specific socket options (TFO, TCP_USER_TIMEOUT, etc.)

**`features/` - Feature Interfaces**
Define contracts for pluggable features (DNS, routing, inbound/outbound management, policy, stats).

**`common/` - Shared Utilities**
- **buf**: Buffer pool for efficient memory management
- **net**: Network address types and utilities
- **protocol**: User authentication and protocol helpers
- **session**: Connection session metadata (inbound, outbound, source, destination)
- **mux**: Connection multiplexing
- **errors**: Structured error handling
- **signal**: Async I/O helpers
- **task**: Periodic and scheduled tasks
- **strmatcher**: Domain/pattern matching for routing

**`infra/conf/` - Configuration Parsing**
Converts JSON/TOML/YAML configs to protobuf structures.

**`main/` - Entry Point**
- `main.go`: CLI entry with command routing
- `run.go`: Config loading and server startup
- `commands/`: Subcommands (run, version, etc.)
- `distro/all/`: Imports all proxy implementations (enables them)

### Data Flow

1. **Inbound**: Connection arrives → Protocol handler (proxy/*) → Dispatcher
2. **Dispatcher**: Sniff protocol → Route via Router → Select outbound
3. **Outbound**: Protocol encoding → Transport layer → Network

### Key Patterns

**Feature Registration:**
```go
// Features register themselves via common.RegisterConfig
func init() {
    common.Must(common.RegisterConfig((*Config)(nil), func(ctx context.Context, config interface{}) (interface{}, error) {
        return New(ctx, config.(*Config))
    }))
}
```

**Dependency Injection:**
```go
// Features request dependencies via RequireFeatures
core.RequireFeatures(ctx, func(d routing.Dispatcher, r routing.Router) {
    // Use dispatcher and router
})
```

**Connection Processing:**
```go
// Inbound.Process receives connections
func (h *Handler) Process(ctx context.Context, network net.Network, conn stat.Connection, dispatcher routing.Dispatcher) error
```

## Protocol-Specific Notes

### VLESS
- Core protocol: minimal overhead, extensible via addons
- Vision flow: XTLS splice optimization for TLS-in-TLS
- REALITY: Steals TLS handshake from target server to avoid detection

### REALITY Implementation
Located in `transport/internet/reality/`:
- `reality.go`: Client/server connection wrapping
- Configured via TLS settings with `reality.Config`
- Requires target SNI (server to mimic) and private/public key pair

### XHTTP
Advanced HTTP-based transport in discussions, see issue #4113.

### XUDP
Global UDP session management (`common/xudp/`):
- Session deduplication
- Global session ID

## Testing Workflow

Tests require geodata files (geoip.dat, geosite.dat) for router tests. CI caches these in `resources/`.

Run locally:
```bash
mkdir -p resources
# Download geodata if needed
go test -v ./...
```

## Configuration Notes

- Main config structure defined in `core/config.proto`
- Inbound/Outbound configs in respective proxy directories
- Transport configs in `transport/internet/*/config.proto`
- Use `xray run -dump` to debug merged configurations

## Common Development Patterns

**Adding a new proxy protocol:**
1. Create directory under `proxy/`
2. Implement `Inbound` and/or `Outbound` interfaces
3. Define `.proto` config
4. Register via `common.RegisterConfig` in `init()`
5. Import in `main/distro/all/all.go`

**Adding a new transport:**
1. Create directory under `transport/internet/`
2. Implement `DialFunc` for client, `ListenFunc` for server
3. Register via `internet.RegisterTransportDialer/Listener`
4. Define `.proto` config

**Modifying routing:**
Edit `app/router/` - be aware of performance implications as routing is hot path.

## Important Files

- `core/xray.go`: Core instance management
- `app/dispatcher/default.go`: Connection dispatcher (routing entry point)
- `proxy/proxy.go`: Proxy interface definitions
- `transport/internet/dialer.go`: Connection establishment
- `common/session/session.go`: Connection metadata
