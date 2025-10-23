#!/usr/bin/env python3
"""
Traffic Analysis Script for Xray Obfuscation Testing
Analyzes packet captures to detect TLS-in-TLS patterns and measure obfuscation effectiveness
"""

import sys
import math
from collections import Counter
from dataclasses import dataclass
from typing import List, Tuple

@dataclass
class PacketInfo:
    timestamp: float
    size: int
    direction: str  # 'client_to_server' or 'server_to_client'


def parse_pcap_basic(filename: str) -> List[PacketInfo]:
    """
    Parse pcap file using tshark (must be installed)
    Returns list of PacketInfo objects
    """
    import subprocess

    # Use tshark to extract packet info
    cmd = [
        'tshark', '-r', filename, '-T', 'fields',
        '-e', 'frame.time_epoch',
        '-e', 'frame.len',
        '-e', 'ip.src',
        '-e', 'ip.dst',
        '-E', 'separator=,'
    ]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    except FileNotFoundError:
        print("Error: tshark not found. Please install wireshark/tshark")
        return []
    except subprocess.CalledProcessError as e:
        print(f"Error running tshark: {e}")
        return []

    packets = []
    client_ip = '172.25.0.20'  # From docker-compose.yml

    for line in result.stdout.strip().split('\n'):
        if not line:
            continue

        parts = line.split(',')
        if len(parts) < 4:
            continue

        timestamp = float(parts[0])
        size = int(parts[1])
        src_ip = parts[2]
        dst_ip = parts[3]

        direction = 'client_to_server' if src_ip == client_ip else 'server_to_client'

        packets.append(PacketInfo(timestamp, size, direction))

    return packets


def calculate_entropy(data: bytes) -> float:
    """Calculate Shannon entropy of data"""
    if not data:
        return 0.0

    # Count byte frequencies
    counter = Counter(data)
    length = len(data)

    # Calculate Shannon entropy
    entropy = 0.0
    for count in counter.values():
        p = count / length
        if p > 0:
            entropy -= p * math.log2(p)

    return entropy


def analyze_burst_patterns(packets: List[PacketInfo]) -> dict:
    """
    Analyze burst patterns to detect TLS-in-TLS signature
    TLS-in-TLS typically shows 2-3 RTT bursts after initial handshake
    """
    if not packets:
        return {}

    # Group packets into bursts (gap > 50ms = new burst)
    bursts = []
    current_burst = []
    last_time = packets[0].timestamp

    for pkt in packets:
        if pkt.timestamp - last_time > 0.05:  # 50ms gap
            if current_burst:
                bursts.append(current_burst)
            current_burst = [pkt]
        else:
            current_burst.append(pkt)
        last_time = pkt.timestamp

    if current_burst:
        bursts.append(current_burst)

    # Analyze burst characteristics
    burst_sizes = [sum(p.size for p in burst) for burst in bursts]
    burst_counts = [len(burst) for burst in bursts]

    return {
        'total_bursts': len(bursts),
        'avg_burst_size': sum(burst_sizes) / len(burst_sizes) if burst_sizes else 0,
        'avg_packets_per_burst': sum(burst_counts) / len(burst_counts) if burst_counts else 0,
        'burst_size_stddev': math.sqrt(sum((x - sum(burst_sizes)/len(burst_sizes))**2
                                           for x in burst_sizes) / len(burst_sizes)) if len(burst_sizes) > 1 else 0,
    }


def analyze_packet_sizes(packets: List[PacketInfo]) -> dict:
    """Analyze packet size distribution"""
    if not packets:
        return {}

    sizes = [p.size for p in packets]

    # Calculate 3-grams for pattern detection
    trigrams = []
    for i in range(len(sizes) - 2):
        trigrams.append((sizes[i], sizes[i+1], sizes[i+2]))

    trigram_counts = Counter(trigrams)

    return {
        'total_packets': len(sizes),
        'min_size': min(sizes),
        'max_size': max(sizes),
        'avg_size': sum(sizes) / len(sizes),
        'size_stddev': math.sqrt(sum((x - sum(sizes)/len(sizes))**2 for x in sizes) / len(sizes)),
        'unique_trigrams': len(trigram_counts),
        'most_common_trigrams': trigram_counts.most_common(5),
    }


def analyze_timing(packets: List[PacketInfo]) -> dict:
    """Analyze inter-arrival time distribution"""
    if len(packets) < 2:
        return {}

    iats = []
    for i in range(1, len(packets)):
        iat = (packets[i].timestamp - packets[i-1].timestamp) * 1000  # Convert to ms
        iats.append(iat)

    return {
        'min_iat_ms': min(iats),
        'max_iat_ms': max(iats),
        'avg_iat_ms': sum(iats) / len(iats),
        'iat_stddev_ms': math.sqrt(sum((x - sum(iats)/len(iats))**2 for x in iats) / len(iats)),
    }


def detect_tls_in_tls(packets: List[PacketInfo]) -> dict:
    """
    Detect TLS-in-TLS patterns based on research findings
    Normal HTTPS: 1 RTT after TLS, ~200-300 byte initial burst
    TLS-in-TLS: 2-3 RTT after TLS, ~500-700 byte initial burst
    """
    if len(packets) < 10:
        return {'detected': False, 'confidence': 0.0, 'reason': 'Insufficient packets'}

    # Analyze first 10 packets (handshake phase)
    handshake_packets = packets[:10]
    handshake_sizes = [p.size for p in handshake_packets]
    avg_handshake_size = sum(handshake_sizes) / len(handshake_sizes)

    # Check for characteristic burst pattern
    burst_analysis = analyze_burst_patterns(handshake_packets)

    detection_score = 0.0
    reasons = []

    # Criterion 1: Large initial burst (500-700 bytes suggests TLS-in-TLS)
    if 500 <= avg_handshake_size <= 900:
        detection_score += 0.3
        reasons.append(f"Large handshake burst: {avg_handshake_size:.0f} bytes")
    elif 200 <= avg_handshake_size <= 350:
        reasons.append(f"Normal handshake burst: {avg_handshake_size:.0f} bytes (HTTPS-like)")

    # Criterion 2: Multiple RTT rounds (>2 bursts in first 10 packets)
    if burst_analysis.get('total_bursts', 0) > 2:
        detection_score += 0.3
        reasons.append(f"Multiple RTT rounds: {burst_analysis['total_bursts']} bursts")

    # Criterion 3: High burst size variability
    if burst_analysis.get('burst_size_stddev', 0) > 300:
        detection_score += 0.2
        reasons.append(f"High variability: stddev={burst_analysis['burst_size_stddev']:.0f}")

    detected = detection_score >= 0.5
    confidence = min(detection_score, 1.0)

    return {
        'detected': detected,
        'confidence': confidence,
        'score': detection_score,
        'reasons': reasons,
        'avg_handshake_size': avg_handshake_size,
    }


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 analyze_traffic.py <pcap_file>")
        sys.exit(1)

    filename = sys.argv[1]

    print(f"=== Analyzing {filename} ===\n")

    # Parse packets
    print("Parsing pcap file...")
    packets = parse_pcap_basic(filename)

    if not packets:
        print("No packets found or error parsing file")
        sys.exit(1)

    print(f"Found {len(packets)} packets\n")

    # Analyze packet sizes
    print("--- Packet Size Analysis ---")
    size_analysis = analyze_packet_sizes(packets)
    print(f"Total packets: {size_analysis['total_packets']}")
    print(f"Size range: {size_analysis['min_size']} - {size_analysis['max_size']} bytes")
    print(f"Average size: {size_analysis['avg_size']:.2f} ± {size_analysis['size_stddev']:.2f} bytes")
    print(f"Unique 3-grams: {size_analysis['unique_trigrams']}")
    print()

    # Analyze timing
    print("--- Timing Analysis ---")
    timing_analysis = analyze_timing(packets)
    print(f"IAT range: {timing_analysis['min_iat_ms']:.2f} - {timing_analysis['max_iat_ms']:.2f} ms")
    print(f"Average IAT: {timing_analysis['avg_iat_ms']:.2f} ± {timing_analysis['iat_stddev_ms']:.2f} ms")
    print()

    # Analyze bursts
    print("--- Burst Pattern Analysis ---")
    burst_analysis = analyze_burst_patterns(packets)
    print(f"Total bursts: {burst_analysis['total_bursts']}")
    print(f"Average burst size: {burst_analysis['avg_burst_size']:.2f} bytes")
    print(f"Average packets/burst: {burst_analysis['avg_packets_per_burst']:.2f}")
    print(f"Burst size stddev: {burst_analysis['burst_size_stddev']:.2f}")
    print()

    # TLS-in-TLS detection
    print("--- TLS-in-TLS Detection ---")
    detection = detect_tls_in_tls(packets)
    print(f"Detected: {detection['detected']}")
    print(f"Confidence: {detection['confidence']:.2%}")
    print(f"Score: {detection['score']:.2f}")
    if detection['reasons']:
        print("Reasons:")
        for reason in detection['reasons']:
            print(f"  - {reason}")
    print()

    # Overall assessment
    print("--- Overall Assessment ---")
    if detection['detected']:
        print("⚠️  TLS-in-TLS pattern DETECTED - Obfuscation may be INSUFFICIENT")
        print("   Recommendation: Increase padding, adjust burst patterns")
    else:
        print("✓ No clear TLS-in-TLS signature detected")
        print(f"  Handshake burst size: {detection['avg_handshake_size']:.0f} bytes (target: 200-350)")
        print("  Traffic appears similar to normal HTTPS")
    print()


if __name__ == '__main__':
    main()
