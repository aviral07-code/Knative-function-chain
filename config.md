# Autoscaling Configuration Deployment Guide
## Deploy Concurrency-Based Chain
```bash
cd ~/knative-function-chain

# Replace placeholder with your Docker username
sed "s/YOUR_DOCKER_USER/$DOCKER_USER/g" chain-concurrency.yaml > chain-concurrency-deploy.yaml

kubectl apply -f chain-concurrency-deploy.yaml

# Wait for services to be ready
kubectl wait --for=condition=ready ksvc func-a-conc func-b-conc func-c-conc --timeout=300s

# Verify
kubectl get ksvc | grep conc
```

## Deploy Request-Rate-Based (RPS) Chain
```bash
sed "s/YOUR_DOCKER_USER/$DOCKER_USER/g" chain-rps.yaml > chain-rps-deploy.yaml
kubectl apply -f chain-rps-deploy.yaml
kubectl wait --for=condition=ready ksvc func-a-rps func-b-rps func-c-rps --timeout=300s
kubectl get ksvc | grep rps
```

## Deploy Custom Metrics Chain (position aware tuning)
```bash
sed "s/YOUR_DOCKER_USER/$DOCKER_USER/g" chain-custom.yaml > chain-custom-deploy.yaml
kubectl apply -f chain-custom-deploy.yaml
kubectl wait --for=condition=ready ksvc func-a-custom func-b-custom func-c-custom --timeout=300s
kubectl get ksvc | grep custom
```

## Verify all deployments
```bash 
# Check all services
kubectl get ksvc

# Expected output (9 services total):
# NAME             URL                                          READY
# func-a-conc      http://func-a-conc.default.example.com       True
# func-b-conc      http://func-b-conc.default.example.com       True
# func-c-conc      http://func-c-conc.default.example.com       True
# func-a-rps       http://func-a-rps.default.example.com        True
# func-b-rps       http://func-b-rps.default.example.com        True
# func-c-rps       http://func-c-rps.default.example.com        True
# func-a-custom    http://func-a-custom.default.example.com     True
# func-b-custom    http://func-b-custom.default.example.com     True
# func-c-custom    http://func-c-custom.default.example.com     True
```

## Test each chain
```bash
# Test concurrency-based chain
curl -H "Host: func-a-conc.default.example.com" http://$NODE_IP:$KOURIER_PORT/ | jq .

# Test RPS-based chain
curl -H "Host: func-a-rps.default.example.com" http://$NODE_IP:$KOURIER_PORT/ | jq .

# Test custom chain
curl -H "Host: func-a-custom.default.example.com" http://$NODE_IP:$KOURIER_PORT/ | jq .
```

## Expected output format
```json
{
  "function": "A",
  "work_ms": 100,
  "iterations": 250000,
  "latency_ms": 350.5,
  "next": {
    "function": "B",
    "work_ms": 100,
    "iterations": 250000,
    "latency_ms": 280.3,
    "next": {
      "function": "C",
      "work_ms": 100,
      "iterations": 250000,
      "latency_ms": 120.1,
      "message": "Chain completed successfully"
    }
  }
}

```

## Install wrk Load Generator
```bash
# Install wrk
sudo apt-get install -y wrk

# Verify installation
wrk --version
```

## TODO
grafana (graph is running but I have no idea what it is showing)
fix report generation