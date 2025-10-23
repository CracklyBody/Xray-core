# Production Xray Client with VLESS + REALITY + Vision
FROM golang:1.23-alpine AS builder

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

# Runtime stage - minimal image with tools
FROM alpine:latest

LABEL maintainer="Xray-core Client"
LABEL description="Production Xray client with VLESS, REALITY, Vision"

# Install runtime dependencies and useful tools
RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    curl \
    wget \
    bind-tools \
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

# Expose SOCKS and HTTP proxy ports
EXPOSE 10808 10809

ENTRYPOINT ["/usr/local/bin/xray"]
CMD ["run", "-c", "/etc/xray/config.json"]
