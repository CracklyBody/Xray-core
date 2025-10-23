package obfuscation

import (
	"context"

	"github.com/xtls/xray-core/common/buf"
	"github.com/xtls/xray-core/common/errors"
)

// ObfuscationWriter wraps a buf.Writer to apply statistical obfuscation
type ObfuscationWriter struct {
	buf.Writer
	config      *Config
	burstShaper *BurstShaper
	ctx         context.Context
	packetCount int
	isHandshake bool
}

// NewObfuscationWriter creates a new obfuscation writer wrapper
func NewObfuscationWriter(writer buf.Writer, config *Config, ctx context.Context) *ObfuscationWriter {
	if config == nil {
		config = DefaultConfig()
	}

	var burstShaper *BurstShaper
	if config.Enabled {
		burstShaper = NewBurstShaper(config.GetBurstPattern())
	}

	return &ObfuscationWriter{
		Writer:      writer,
		config:      config,
		burstShaper: burstShaper,
		ctx:         ctx,
		packetCount: 0,
		isHandshake: true,
	}
}

// WriteMultiBuffer applies obfuscation to buffers before writing
func (w *ObfuscationWriter) WriteMultiBuffer(mb buf.MultiBuffer) error {
	if !w.config.Enabled || w.burstShaper == nil {
		// Obfuscation disabled, pass through
		return w.Writer.WriteMultiBuffer(mb)
	}

	// Process each buffer in the multi-buffer
	obfuscatedMB := make(buf.MultiBuffer, 0, len(mb))
	for _, b := range mb {
		if b == nil || b.Len() == 0 {
			continue
		}

		w.packetCount++

		// First 8 packets are considered handshake phase
		// This aligns with Vision's filter window
		isHandshake := w.packetCount <= 8

		// Apply burst shaping (includes padding and timing)
		shapedBuffer := w.burstShaper.ShapePacket(w.ctx, b, isHandshake)
		obfuscatedMB = append(obfuscatedMB, shapedBuffer)

		if w.config.Debug {
			errors.LogDebug(w.ctx, "Obfuscation applied: packet=", w.packetCount,
				" handshake=", isHandshake,
				" original_size=", b.Len(),
				" final_size=", shapedBuffer.Len())
		}
	}

	if len(obfuscatedMB) == 0 {
		return nil
	}

	// Write obfuscated buffers
	return w.Writer.WriteMultiBuffer(obfuscatedMB)
}

// ObfuscationReader wraps a buf.Reader (currently pass-through)
// Future: could implement adaptive reading based on detected patterns
type ObfuscationReader struct {
	buf.Reader
	config      *Config
	ctx         context.Context
	packetCount int
}

// NewObfuscationReader creates a new obfuscation reader wrapper
func NewObfuscationReader(reader buf.Reader, config *Config, ctx context.Context) *ObfuscationReader {
	if config == nil {
		config = DefaultConfig()
	}

	return &ObfuscationReader{
		Reader:      reader,
		config:      config,
		ctx:         ctx,
		packetCount: 0,
	}
}

// ReadMultiBuffer reads buffers (currently pass-through)
func (r *ObfuscationReader) ReadMultiBuffer() (buf.MultiBuffer, error) {
	r.packetCount++

	// Currently pass-through, but can add deobfuscation logic here
	// For example: removing padding markers, adjusting timing windows, etc.
	mb, err := r.Reader.ReadMultiBuffer()

	if r.config.Debug && !mb.IsEmpty() {
		errors.LogDebug(r.ctx, "Obfuscation read: packet=", r.packetCount, " size=", mb.Len())
	}

	return mb, err
}

// WrapWriter wraps a writer with obfuscation if config is enabled
func WrapWriter(writer buf.Writer, config *Config, ctx context.Context) buf.Writer {
	if config == nil || !config.Enabled {
		return writer
	}
	return NewObfuscationWriter(writer, config, ctx)
}

// WrapReader wraps a reader with obfuscation if config is enabled
func WrapReader(reader buf.Reader, config *Config, ctx context.Context) buf.Reader {
	if config == nil || !config.Enabled {
		return reader
	}
	return NewObfuscationReader(reader, config, ctx)
}
