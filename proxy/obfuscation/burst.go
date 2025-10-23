package obfuscation

import (
	"context"
	"time"

	"github.com/xtls/xray-core/common/buf"
)

// BurstPattern defines traffic burst characteristics
type BurstPattern int

const (
	// NormalPattern uses default burst behavior
	NormalPattern BurstPattern = iota
	// HTTPSPattern mimics HTTPS traffic bursts
	HTTPSPattern
	// HTTP3Pattern mimics HTTP/3 QUIC traffic bursts
	HTTP3Pattern
	// VideoStreamPattern mimics video streaming bursts
	VideoStreamPattern
)

// BurstShaper shapes traffic bursts to match specific patterns
type BurstShaper struct {
	pattern       BurstPattern
	paddingEngine *PaddingEngine
	timingEngine  *TimingEngine
	packetCount   int
	burstCount    int
	inBurst       bool
}

// NewBurstShaper creates a new burst shaper with specified pattern
func NewBurstShaper(pattern BurstPattern) *BurstShaper {
	var paddingDist PaddingDistribution
	var timingProfile TimingProfile

	switch pattern {
	case HTTPSPattern:
		paddingDist = HTTPSDistribution
		timingProfile = ExponentialJitter
	case HTTP3Pattern:
		paddingDist = HTTP3Distribution
		timingProfile = ExponentialJitter
	default:
		paddingDist = UniformDistribution
		timingProfile = NoJitter
	}

	return &BurstShaper{
		pattern:       pattern,
		paddingEngine: NewPaddingEngine(paddingDist),
		timingEngine:  NewTimingEngine(timingProfile),
		packetCount:   0,
		burstCount:    0,
		inBurst:       true,
	}
}

// ShapePacket applies burst shaping to a packet buffer
// Returns the shaped buffer with padding applied
func (b *BurstShaper) ShapePacket(ctx context.Context, buffer *buf.Buffer, isHandshake bool) *buf.Buffer {
	b.packetCount++

	// Determine padding based on pattern and position in burst
	currentSize := buffer.Len()
	paddingLen := b.paddingEngine.GeneratePadding(isHandshake, currentSize)

	// Apply timing jitter before the packet is sent
	// This is non-blocking if context is cancelled
	if b.packetCount > 1 && !isHandshake {
		b.adjustTimingForBurst()
		b.timingEngine.ApplyJitter(ctx)
	}

	// Apply padding
	if paddingLen > 0 {
		b.paddingEngine.ApplyPadding(buffer, paddingLen)
	}

	return buffer
}

// adjustTimingForBurst adjusts timing based on burst position
func (b *BurstShaper) adjustTimingForBurst() {
	switch b.pattern {
	case HTTPSPattern:
		b.adjustHTTPSTiming()
	case HTTP3Pattern:
		b.adjustHTTP3Timing()
	case VideoStreamPattern:
		b.adjustVideoTiming()
	}
}

// adjustHTTPSTiming mimics HTTPS request/response patterns
// Initial burst: minimal delay (0-5ms)
// Between bursts: longer delay (20-50ms)
func (b *BurstShaper) adjustHTTPSTiming() {
	// HTTPS typically has bursts of 3-5 packets
	if b.inBurst {
		// Within burst: minimal delay
		b.timingEngine.SetDelayRange(0, 5*time.Millisecond)
		b.timingEngine.SetMeanDelay(2 * time.Millisecond)

		if b.packetCount%5 == 0 {
			b.inBurst = false
			b.burstCount++
		}
	} else {
		// Between bursts: longer delay
		b.timingEngine.SetDelayRange(20*time.Millisecond, 50*time.Millisecond)
		b.timingEngine.SetMeanDelay(30 * time.Millisecond)

		if b.packetCount%8 == 0 {
			b.inBurst = true
		}
	}
}

// adjustHTTP3Timing mimics HTTP/3 QUIC patterns
// More uniform pacing due to UDP and congestion control
func (b *BurstShaper) adjustHTTP3Timing() {
	// HTTP/3 has more uniform inter-packet timing
	// Typical: 5-15ms between packets
	b.timingEngine.SetDelayRange(5*time.Millisecond, 15*time.Millisecond)
	b.timingEngine.SetMeanDelay(10 * time.Millisecond)
}

// adjustVideoTiming mimics video streaming patterns
// Periodic bursts with longer gaps
func (b *BurstShaper) adjustVideoTiming() {
	// Video streaming: bursts of frames with gaps
	// Assuming 30fps = ~33ms between frames
	if b.inBurst {
		// Within frame: minimal delay (0-2ms)
		b.timingEngine.SetDelayRange(0, 2*time.Millisecond)
		b.timingEngine.SetMeanDelay(1 * time.Millisecond)

		if b.packetCount%10 == 0 {
			b.inBurst = false
		}
	} else {
		// Between frames: ~33ms
		b.timingEngine.SetDelayRange(25*time.Millisecond, 40*time.Millisecond)
		b.timingEngine.SetMeanDelay(33 * time.Millisecond)

		if b.packetCount%11 == 0 {
			b.inBurst = true
			b.burstCount++
		}
	}
}

// GetStatistics returns burst shaping statistics
func (b *BurstShaper) GetStatistics() map[string]interface{} {
	return map[string]interface{}{
		"total_packets":   b.packetCount,
		"burst_count":     b.burstCount,
		"in_burst":        b.inBurst,
		"time_since_last": b.timingEngine.GetTimeSinceLastSend(),
	}
}

// Reset resets the burst shaper state
func (b *BurstShaper) Reset() {
	b.packetCount = 0
	b.burstCount = 0
	b.inBurst = true
}
