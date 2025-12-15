import csv
import sys
from collections import defaultdict

def calculate_pdc(metrics_file):
    """Calculate Propagation Delay Coefficient from metrics CSV"""
    
    # Read metrics
    timestamps = defaultdict(list)
    
    with open(metrics_file, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            func = row['function']
            ts = int(row['timestamp'])
            replicas = int(row['replica_count'])
            
            timestamps[func].append((ts, replicas))
    
    # Find first scale-up time for each function
    scale_times = {}
    
    for func, data in timestamps.items():
        for i, (ts, replicas) in enumerate(data):
            if replicas > 0:
                scale_times[func] = ts
                break
    
    # Calculate delays
    if len(scale_times) == 3:
        funcs = sorted(scale_times.keys())
        
        delay_a_to_b = scale_times[funcs[1]] - scale_times[funcs[0]]
        delay_b_to_c = scale_times[funcs[2]] - scale_times[funcs[1]]
        
        pdc = (delay_a_to_b + delay_b_to_c) / 2
        
        print("\n=== Propagation Delay Coefficient (PDC) ===\n")
        print(f"Function A scale time:    {scale_times[funcs[0]]}s (baseline)")
        print(f"Function B scale time:    {scale_times[funcs[1]]}s (+{delay_a_to_b}s)")
        print(f"Function C scale time:    {scale_times[funcs[2]]}s (+{delay_b_to_c}s)")
        print(f"\nPropagation Delay Coefficient: {pdc:.1f} seconds/stage")
        print(f"\nInterpretation:")
        if pdc < 3:
            print("  ✓ Fast propagation (good coordination)")
        elif pdc < 6:
            print("  ⚠ Moderate propagation (acceptable)")
        else:
            print("  ✗ Slow propagation (cascading delays)")
    else:
        print("Error: Could not find scale-up times for all functions")

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python3 calculate-pdc.py results/METRICS.csv")
        sys.exit(1)
    
    calculate_pdc(sys.argv[1])