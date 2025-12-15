import requests
from flask import Flask, request, jsonify
import time
import os

app = Flask(__name__)

NEXT_FUNCTION = os.getenv('NEXT_FUNCTION', '')
WORK_MS = int(os.getenv('WORK_MS', '100'))

@app.route('/', methods=['GET'])
@app.route('/healthz', methods=['GET'])
def handler():
    start_time = time.time()
    
    # Simulate CPU-bound work
    work_start = time.time()
    iterations = 0
    while (time.time() - work_start) * 1000 < WORK_MS:
        iterations += 1
    
    result = {
        'function': 'A',
        'work_ms': WORK_MS,
        'iterations': iterations
    }
    
    # Call next function in chain
    if NEXT_FUNCTION:
        try:
            next_start = time.time()
            response = requests.get(NEXT_FUNCTION, timeout=30)
            result['next'] = response.json()
            result['next_call_time_ms'] = (time.time() - next_start) * 1000
        except Exception as e:
            result['error'] = str(e)
    
    result['latency_ms'] = (time.time() - start_time) * 1000
    return jsonify(result)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)