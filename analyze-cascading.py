#!/usr/bin/env python3
import json
import sys

def extract_chain(d):
    chain = []
    cur = d
    while cur is not None:
        func = cur.get("function")
        lat = cur.get("latency_ms")
        chain.append((func, lat))
        cur = cur.get("next")
    return chain

def main(filename):
    with open(filename) as f:
        data = json.load(f)

    chain = extract_chain(data)
    print("\n=== Cascading latency breakdown ===\n")
    total = 0.0
    for func, lat in chain:
        if lat is None:
            continue
        print(f"{func}: {lat:.2f} ms")
        total += lat
    print(f"\nTotal chain latency: {total:.2f} ms")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 analyze-cascading.py")
        sys.exit(1)
    main(sys.argv[1])

