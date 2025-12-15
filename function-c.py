from flask import Flask, jsonify
import time
import os

app = Flask(__name__)

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
        'function': 'C',
        'work_ms': WORK_MS,
        'iterations': iterations,
        'message': 'Chain completed successfully'
    }
    
    result['latency_ms'] = (time.time() - start_time) * 1000
    return jsonify(result)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)