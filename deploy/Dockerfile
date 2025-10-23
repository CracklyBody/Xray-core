# Production Dockerfile for Xray with Statistical Obfuscation
FROM golang:1.23-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git build-base

# Set working directory
WORKDIR /build

# Copy source code
COPY . .

# Build Xray with obfuscation module
RUN CGO_ENABLED=0 go build -o xray -trimpath -buildvcs=false \
    -ldflags="-s -w -buildid=" \
    -v ./main

# Runtime stage - minimal image
FROM alpine:latest

LABEL maintainer="Xray Obfuscation"
LABEL description="Xray-core with Statistical Obfuscation for DPI Evasion"

# Install runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    && rm -rf /var/cache/apk/*

# Copy binary from builder
COPY --from=builder /build/xray /usr/local/bin/xray

# Create necessary directories
RUN mkdir -p /etc/xray /usr/local/share/xray /var/log/xray

# Download geodata files
ADD https://github.com/v2fly/geoip/releases/latest/download/geoip.dat \
    /usr/local/share/xray/geoip.dat

ADD https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat \
    /usr/local/share/xray/geosite.dat

# Set permissions
RUN chmod +x /usr/local/bin/xray && \
    chmod 644 /usr/local/share/xray/*.dat

WORKDIR /etc/xray

# Expose REALITY port (443)
EXPOSE 443

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD xray version || exit 1

ENTRYPOINT ["/usr/local/bin/xray"]
CMD ["run", "-c", "/etc/xray/config.json"]
