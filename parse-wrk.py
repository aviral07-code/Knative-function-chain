#!/usr/bin/env python3

import re
import sys
import json

def parse_wrk_output(filename):
    """Parse wrk output file and extract key metrics"""
    
    with open(filename, 'r') as f:
        content = f.read()
    
    results = {}
    
    # Extract requests/sec
    match = re.search(r'Requests/sec:\s+([\d.]+)', content)
    if match:
        results['requests_per_sec'] = float(match.group(1))
    
    # Extract average latency
    match = re.search(r'Latency\s+([\d.]+)(\w+)', content)
    if match:
        value = float(match.group(1))
        unit = match.group(2)
        # Convert to ms
        if unit == 's':
            value *= 1000
        results['latency_avg_ms'] = value
    
    # Extract latency percentiles
    percentiles = ['50.000', '75.000', '90.000', '95.000', '99.000']
    for p in percentiles:
        match = re.search(rf'{p}%\s+([\d.]+)(\w+)', content)
        if match:
            value = float(match.group(1))
            unit = match.group(2)
            if unit == 's':
                value *= 1000
            p_num = p.split('.')[0]
            results[f'p{p_num}_latency_ms'] = value
    
    # Extract transfer stats
    match = re.search(r'Transfer/sec:\s+([\d.]+)(\w+)', content)
    if match:
        results['transfer_per_sec'] = match.group(1) + match.group(2)
    
    # Extract total requests
    match = re.search(r'(\d+) requests in', content)
    if match:
        results['total_requests'] = int(match.group(1))
    
    return results

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python3 parse-wrk.py RESULT_FILE")
        sys.exit(1)
    
    results = parse_wrk_output(sys.argv[1])
    
    print("\n=== Performance Metrics ===\n")
    print(json.dumps(results, indent=2))
    
    # Also print in table format
    print("\n=== Summary ===")
    print(f"Throughput:       {results.get('requests_per_sec', 'N/A')} req/s")
    print(f"Avg Latency:      {results.get('latency_avg_ms', 'N/A')} ms")
    print(f"P50 Latency:      {results.get('p50_latency_ms', 'N/A')} ms")
    print(f"P95 Latency:      {results.get('p95_latency_ms', 'N/A')} ms")
    print(f"P99 Latency:      {results.get('p99_latency_ms', 'N/A')} ms")
    print(f"Total Requests:   {results.get('total_requests', 'N/A')}")