package obfuscation

// Config defines configuration for the statistical obfuscation module
type Config struct {
	// Enable enables the obfuscation module
	Enabled bool

	// PaddingMode specifies the padding distribution to use
	// Options: "uniform", "http3", "https"
	PaddingMode string

	// TimingMode specifies the timing jitter profile to use
	// Options: "none", "uniform", "exponential", "normal"
	TimingMode string

	// BurstPattern specifies the burst pattern to mimic
	// Options: "normal", "https", "http3", "video"
	BurstPattern string

	// MinDelay minimum delay in milliseconds for timing jitter
	MinDelayMs int32

	// MaxDelay maximum delay in milliseconds for timing jitter
	MaxDelayMs int32

	// Debug enables debug logging
	Debug bool
}

// DefaultConfig returns the default obfuscation configuration
// Optimized for Russia/Iran DPI systems
func DefaultConfig() *Config {
	return &Config{
		Enabled:      true,
		PaddingMode:  "http3",       // Mimic HTTP/3 QUIC patterns
		TimingMode:   "exponential", // Exponential IAT distribution
		BurstPattern: "https",       // HTTPS-like bursts
		MinDelayMs:   0,
		MaxDelayMs:   50,
		Debug:        false,
	}
}

// GetPaddingDistribution converts string config to PaddingDistribution enum
func (c *Config) GetPaddingDistribution() PaddingDistribution {
	switch c.PaddingMode {
	case "http3":
		return HTTP3Distribution
	case "https":
		return HTTPSDistribution
	default:
		return UniformDistribution
	}
}

// GetTimingProfile converts string config to TimingProfile enum
func (c *Config) GetTimingProfile() TimingProfile {
	switch c.TimingMode {
	case "uniform":
		return UniformJitter
	case "exponential":
		return ExponentialJitter
	case "normal":
		return NormalJitter
	default:
		return NoJitter
	}
}

// GetBurstPattern converts string config to BurstPattern enum
func (c *Config) GetBurstPattern() BurstPattern {
	switch c.BurstPattern {
	case "https":
		return HTTPSPattern
	case "http3":
		return HTTP3Pattern
	case "video":
		return VideoStreamPattern
	default:
		return NormalPattern
	}
}
