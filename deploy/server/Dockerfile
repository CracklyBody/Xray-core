# Production Xray Server with VLESS + REALITY + Vision + Statistical Obfuscation
FROM golang:1.25-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git build-base

# Set working directory
WORKDIR /build

# Copy source code (will be mounted from parent directory)
COPY . .

# Build Xray with all optimizations
RUN CGO_ENABLED=0 go build -o xray -trimpath -buildvcs=false \
    -ldflags="-s -w -buildid=" \
    -v ./main

# Runtime stage - minimal image
FROM alpine:latest

LABEL maintainer="Xray-core with Statistical Obfuscation"
LABEL description="Production Xray server with VLESS, REALITY, Vision, and anti-DPI obfuscation"

# Install runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    curl \
    jq

# Copy binary from builder
COPY --from=builder /build/xray /usr/local/bin/xray

# Create necessary directories
RUN mkdir -p /etc/xray /usr/local/share/xray /var/log/xray && \
    chmod 755 /etc/xray /usr/local/share/xray /var/log/xray

# Download geodata files for routing
ADD https://github.com/v2fly/geoip/releases/latest/download/geoip.dat /usr/local/share/xray/
ADD https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat /usr/local/share/xray/geosite.dat

# Set proper permissions
RUN chmod 644 /usr/local/share/xray/*.dat

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pgrep xray || exit 1

WORKDIR /etc/xray

# Expose default REALITY port
EXPOSE 443

# Run as non-root user for security (optional, comment out if issues)
# RUN adduser -D -H -h /etc/xray xray && chown -R xray:xray /etc/xray /var/log/xray
# USER xray

ENTRYPOINT ["/usr/local/bin/xray"]
CMD ["run", "-c", "/etc/xray/config.json"]
