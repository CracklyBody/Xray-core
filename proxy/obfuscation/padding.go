package obfuscation

import (
	"crypto/rand"
	"math"
	"math/big"

	"github.com/xtls/xray-core/common/buf"
	"github.com/xtls/xray-core/common/errors"
)

// PaddingDistribution defines different padding strategies
type PaddingDistribution int

const (
	// UniformDistribution uses uniform random padding (0-255 bytes)
	UniformDistribution PaddingDistribution = iota
	// HTTP3Distribution mimics HTTP/3 QUIC packet size distribution
	HTTP3Distribution
	// HTTPSDistribution mimics normal HTTPS traffic patterns
	HTTPSDistribution
)

// PaddingEngine handles padding generation with various distributions
type PaddingEngine struct {
	distribution PaddingDistribution
	minPadding   int32
	maxPadding   int32
}

// NewPaddingEngine creates a new padding engine with specified distribution
func NewPaddingEngine(dist PaddingDistribution) *PaddingEngine {
	return &PaddingEngine{
		distribution: dist,
		minPadding:   0,
		maxPadding:   1400,
	}
}

// GeneratePadding generates padding bytes based on the configured distribution
// and whether this is a handshake packet or application data
func (p *PaddingEngine) GeneratePadding(isHandshake bool, currentSize int32) int32 {
	switch p.distribution {
	case HTTP3Distribution:
		return p.generateHTTP3Padding(isHandshake, currentSize)
	case HTTPSDistribution:
		return p.generateHTTPSPadding(isHandshake, currentSize)
	default:
		return p.generateUniformPadding(isHandshake)
	}
}

// generateUniformPadding generates uniform random padding (original Vision style)
func (p *PaddingEngine) generateUniformPadding(isHandshake bool) int32 {
	if isHandshake {
		// Long padding for handshake: 900-1400 bytes
		l, err := rand.Int(rand.Reader, big.NewInt(500))
		if err != nil {
			return 900
		}
		return int32(l.Int64()) + 900
	}
	// Short padding: 0-255 bytes
	l, err := rand.Int(rand.Reader, big.NewInt(256))
	if err != nil {
		return 128
	}
	return int32(l.Int64())
}

// generateHTTP3Padding mimics HTTP/3 QUIC packet size distribution
// HTTP/3 Initial packets: ~1200 bytes
// Subsequent: bimodal distribution (200-300 bytes, 1000-1400 bytes)
func (p *PaddingEngine) generateHTTP3Padding(isHandshake bool, currentSize int32) int32 {
	if isHandshake {
		// HTTP/3 Initial packet target: ~1200 bytes
		target := int32(1200)
		if currentSize >= target {
			// Already large enough, add small random padding
			l, _ := rand.Int(rand.Reader, big.NewInt(100))
			return int32(l.Int64())
		}

		// Pad to approximately 1200 bytes with jitter
		l, _ := rand.Int(rand.Reader, big.NewInt(200))
		padding := target - currentSize + int32(l.Int64()) - 100
		if padding < 0 {
			padding = 0
		}
		if padding > p.maxPadding {
			padding = p.maxPadding
		}
		return padding
	}

	// Application data: bimodal distribution
	// 70% small packets (200-300 bytes target)
	// 30% large packets (1000-1400 bytes target)
	r, _ := rand.Int(rand.Reader, big.NewInt(100))

	if r.Int64() < 70 {
		// Small packet target: 200-300 bytes
		target := int32(250)
		l, _ := rand.Int(rand.Reader, big.NewInt(100))
		padding := target - currentSize + int32(l.Int64()) - 50
		if padding < 0 {
			padding = int32(l.Int64())
		}
		if padding > 300 {
			padding = 300
		}
		return padding
	}

	// Large packet target: 1000-1400 bytes
	target := int32(1200)
	l, _ := rand.Int(rand.Reader, big.NewInt(400))
	padding := target - currentSize + int32(l.Int64()) - 200
	if padding < 0 {
		padding = int32(l.Int64())
	}
	if padding > p.maxPadding {
		padding = p.maxPadding
	}
	return padding
}

// generateHTTPSPadding mimics normal HTTPS traffic patterns
// First burst: 200-300 bytes
// Subsequent: exponential distribution with lambda=0.002 (mean ~500 bytes)
func (p *PaddingEngine) generateHTTPSPadding(isHandshake bool, currentSize int32) int32 {
	if isHandshake {
		// HTTPS handshake: target 200-300 bytes initial burst
		target := int32(250)
		l, _ := rand.Int(rand.Reader, big.NewInt(100))
		padding := target - currentSize + int32(l.Int64()) - 50
		if padding < 0 {
			l, _ := rand.Int(rand.Reader, big.NewInt(100))
			padding = int32(l.Int64())
		}
		if padding > 500 {
			padding = 500
		}
		return padding
	}

	// Application data: exponential distribution
	// Generate exponential random variable with lambda = 0.002
	u, _ := rand.Int(rand.Reader, big.NewInt(1000000))
	uniformRand := float64(u.Int64()) / 1000000.0
	if uniformRand == 0 {
		uniformRand = 0.000001
	}

	lambda := 0.002
	expRand := -math.Log(uniformRand) / lambda

	padding := int32(expRand)
	if padding > p.maxPadding {
		padding = p.maxPadding
	}
	if padding < 0 {
		padding = 0
	}

	return padding
}

// ApplyPadding adds padding to a buffer
func (p *PaddingEngine) ApplyPadding(b *buf.Buffer, paddingLen int32) *buf.Buffer {
	if paddingLen <= 0 {
		return b
	}

	// Limit padding to avoid exceeding buffer size
	maxAvailable := buf.Size - b.Len() - 21 // Reserve 21 bytes for header
	if paddingLen > maxAvailable {
		paddingLen = maxAvailable
	}

	if paddingLen <= 0 {
		return b
	}

	// Extend buffer with random padding bytes
	paddingStart := b.Len()
	b.Extend(paddingLen)
	paddingBytes := b.BytesFrom(paddingStart)

	// Fill with random data for better entropy
	_, err := rand.Read(paddingBytes)
	if err != nil {
		errors.LogDebug(nil, "failed to generate random padding: ", err)
	}

	return b
}

// CalculateEntropyEstimate estimates the Shannon entropy of a buffer
// Used for testing/validation that our padding maintains high entropy
func CalculateEntropyEstimate(data []byte) float64 {
	if len(data) == 0 {
		return 0
	}

	// Count byte frequencies
	freq := make(map[byte]int)
	for _, b := range data {
		freq[b]++
	}

	// Calculate Shannon entropy
	var entropy float64
	length := float64(len(data))
	for _, count := range freq {
		if count > 0 {
			p := float64(count) / length
			entropy -= p * math.Log2(p)
		}
	}

	return entropy
}
