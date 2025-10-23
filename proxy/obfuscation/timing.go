package obfuscation

import (
	"context"
	"crypto/rand"
	"math"
	"math/big"
	"time"
)

// TimingProfile defines different timing jitter strategies
type TimingProfile int

const (
	// NoJitter disables timing jitter
	NoJitter TimingProfile = iota
	// UniformJitter adds uniform random delay (0-50ms)
	UniformJitter
	// ExponentialJitter adds exponential distributed delay (models CDN latency)
	ExponentialJitter
	// NormalJitter adds normally distributed delay (models network jitter)
	NormalJitter
)

// TimingEngine handles timing obfuscation and inter-arrival time randomization
type TimingEngine struct {
	profile      TimingProfile
	minDelay     time.Duration
	maxDelay     time.Duration
	meanDelay    time.Duration
	lastSendTime time.Time
}

// NewTimingEngine creates a new timing engine with specified profile
func NewTimingEngine(profile TimingProfile) *TimingEngine {
	return &TimingEngine{
		profile:      profile,
		minDelay:     0,
		maxDelay:     50 * time.Millisecond,
		meanDelay:    10 * time.Millisecond,
		lastSendTime: time.Now(),
	}
}

// ApplyJitter applies timing jitter before sending a packet
// Returns immediately if jitter is disabled or context is cancelled
func (t *TimingEngine) ApplyJitter(ctx context.Context) {
	if t.profile == NoJitter {
		return
	}

	delay := t.calculateDelay()
	if delay <= 0 {
		return
	}

	// Update last send time
	t.lastSendTime = time.Now()

	// Apply delay with context cancellation support
	timer := time.NewTimer(delay)
	defer timer.Stop()

	select {
	case <-timer.C:
		return
	case <-ctx.Done():
		return
	}
}

// calculateDelay calculates the delay duration based on the timing profile
func (t *TimingEngine) calculateDelay() time.Duration {
	switch t.profile {
	case UniformJitter:
		return t.uniformDelay()
	case ExponentialJitter:
		return t.exponentialDelay()
	case NormalJitter:
		return t.normalDelay()
	default:
		return 0
	}
}

// uniformDelay generates uniform random delay between minDelay and maxDelay
func (t *TimingEngine) uniformDelay() time.Duration {
	rangeMs := t.maxDelay.Milliseconds() - t.minDelay.Milliseconds()
	if rangeMs <= 0 {
		return t.minDelay
	}

	r, err := rand.Int(rand.Reader, big.NewInt(rangeMs))
	if err != nil {
		return t.meanDelay
	}

	return t.minDelay + time.Duration(r.Int64())*time.Millisecond
}

// exponentialDelay generates exponentially distributed delay
// Models CDN and network latency patterns
// lambda = 1/mean, typical mean = 10ms for CDN edge servers
func (t *TimingEngine) exponentialDelay() time.Duration {
	// Generate uniform random [0,1)
	u, err := rand.Int(rand.Reader, big.NewInt(1000000))
	if err != nil {
		return t.meanDelay
	}
	uniformRand := float64(u.Int64()) / 1000000.0
	if uniformRand == 0 {
		uniformRand = 0.000001
	}

	// Transform to exponential distribution
	meanMs := float64(t.meanDelay.Milliseconds())
	lambda := 1.0 / meanMs
	expRand := -math.Log(uniformRand) / lambda

	delayMs := int64(expRand)
	if delayMs < 0 {
		delayMs = 0
	}
	if delayMs > t.maxDelay.Milliseconds() {
		delayMs = t.maxDelay.Milliseconds()
	}

	return time.Duration(delayMs) * time.Millisecond
}

// normalDelay generates normally distributed delay using Box-Muller transform
// Models natural network jitter
func (t *TimingEngine) normalDelay() time.Duration {
	// Box-Muller transform to generate normal distribution
	u1, err1 := rand.Int(rand.Reader, big.NewInt(1000000))
	u2, err2 := rand.Int(rand.Reader, big.NewInt(1000000))
	if err1 != nil || err2 != nil {
		return t.meanDelay
	}

	uniform1 := float64(u1.Int64())/1000000.0 + 0.000001
	uniform2 := float64(u2.Int64())/1000000.0 + 0.000001

	// Box-Muller transform
	z0 := math.Sqrt(-2.0*math.Log(uniform1)) * math.Cos(2.0*math.Pi*uniform2)

	// Scale to desired mean and standard deviation
	meanMs := float64(t.meanDelay.Milliseconds())
	stdDevMs := meanMs / 3.0 // stddev = mean/3 for reasonable spread

	delayMs := int64(z0*stdDevMs + meanMs)
	if delayMs < 0 {
		delayMs = 0
	}
	if delayMs > t.maxDelay.Milliseconds() {
		delayMs = t.maxDelay.Milliseconds()
	}

	return time.Duration(delayMs) * time.Millisecond
}

// GetTimeSinceLastSend returns duration since last send operation
// Useful for measuring actual inter-arrival times
func (t *TimingEngine) GetTimeSinceLastSend() time.Duration {
	return time.Since(t.lastSendTime)
}

// SetDelayRange configures the min/max delay range
func (t *TimingEngine) SetDelayRange(min, max time.Duration) {
	t.minDelay = min
	t.maxDelay = max
	t.meanDelay = (min + max) / 2
}

// SetMeanDelay configures the mean delay for exponential/normal distributions
func (t *TimingEngine) SetMeanDelay(mean time.Duration) {
	t.meanDelay = mean
}
