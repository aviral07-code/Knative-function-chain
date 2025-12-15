# Knative Function Chain – Autoscaling Policy Comparison

This project implements a three-stage serverless function chain on Knative Serving and compares three autoscaling policies:

- **Concurrency-based scaling** (in-flight requests per pod)  
- **RPS-based scaling** (requests per second per pod)  
- **Custom, position-aware scaling** (different targets per function in the chain)  

The goal is to study how each policy affects end-to-end latency, throughput, cold-start behavior, and propagation of scaling decisions along the chain. [file:1][file:2]

---

## 1. Architecture Overview

- **Platform:** CloudLab, 3-node Kubernetes cluster (node0 control plane, node1–2 workers)  
- **OS:** Ubuntu 22.04  
- **Kubernetes:** v1.28.x with `containerd` and Flannel CNI  
- **Knative:** Serving v1.14.0 with Kourier ingress  
- **Functions:** A → B → C chain, implemented as Python Flask services  
- **Chains:**  
  - `*-conc`: concurrency-based autoscaling  
  - `*-rps`: RPS-based autoscaling  
  - `*-custom`: custom/position-aware tuning [file:1][file:2]

---

## 2. Repository Layout

- `SETUP.md` – full Kubernetes + Knative + CloudLab setup guide  
- `config.md` – how to deploy each autoscaling configuration and test it  
- `function-a.py`, `function-b.py`, `function-c.py` – Flask implementations for A/B/C  
- `Dockerfile.function-a`, `Dockerfile.function-b`, `Dockerfile.function-c` – build images for each function  
- `chain-concurrency.yaml` – ksvc definitions for `func-a/b/c-conc` (concurrency metric)  
- `chain-rps.yaml` – ksvc definitions for `func-a/b/c-rps` (RPS metric)  
- `chain-custom.yaml` – ksvc definitions for `func-a/b/c-custom` (custom tuning)  
- `deploy-all.sh` – generate manifests with your Docker username and deploy all 9 services  
- `collect-metrics.sh` – periodically scrape replica counts into `metrics-*.csv`  
- `burst-test.sh` – run burst load tests using `wrk` and save `results/burst-*.txt`  
- `analyze-cascading.py` – parse one JSON response and print A/B/C latency breakdown  
- `calculate-pdc.py` – compute Propagation Delay Coefficient (PDC) from `metrics-*.csv` [file:1][file:2][file:57][file:58]

---

## 3. Prerequisites

### Accounts and tools

- CloudLab account and active 3-node experiment  
- Docker Hub account  
- Local tools: `docker`, `kubectl`, `ssh`, `wrk`, Python 3 [file:1][file:2]

### Cluster and Knative

Follow **`SETUP.md`** on all nodes to:

1. Install `containerd`, Kubernetes (kubeadm/kubelet/kubectl)  
2. Initialize the control plane on node0 and join node1–2  
3. Install Flannel CNI  
4. Install Knative Serving v1.14.0 and Kourier ingress [file:1]

---

## 4. Build and Push Function Images

On your local machine (Mac or dev box):

export DOCKER_USER=<your-dockerhub-username>

Build images
docker build -t $DOCKER_USER/function-a:v1 -f Dockerfile.function-a .
docker build -t $DOCKER_USER/function-b:v1 -f Dockerfile.function-b .
docker build -t $DOCKER_USER/function-c:v1 -f Dockerfile.function-c .

Push images
docker push $DOCKER_USER/function-a:v1
docker push $DOCKER_USER/function-b:v1
docker push $DOCKER_USER/function-c:v1


Verify that `docker.io/$DOCKER_USER/function-{a,b,c}:v1` exist and are public. [file:1]

---

## 5. Deploy the Three Chains

On **node0**, from the repo root:

### Option A: Manual per chain

export DOCKER_USER=<your-dockerhub-username>

Concurrency chain
sed "s/YOUR_DOCKER_USER/$DOCKER_USER/g" chain-concurrency.yaml > chain-concurrency-deploy.yaml
kubectl apply -f chain-concurrency-deploy.yaml
kubectl wait --for=condition=ready ksvc func-a-conc func-b-conc func-c-conc --timeout=300s
kubectl get ksvc | grep conc

RPS chain
sed "s/YOUR_DOCKER_USER/$DOCKER_USER/g" chain-rps.yaml > chain-rps-deploy.yaml
kubectl apply -f chain-rps-deploy.yaml
kubectl wait --for=condition=ready ksvc func-a-rps func-b-rps func-c-rps --timeout=300s
kubectl get ksvc | grep rps

Custom chain
sed "s/YOUR_DOCKER_USER/$DOCKER_USER/g" chain-custom.yaml > chain-custom-deploy.yaml
kubectl apply -f chain-custom-deploy.yaml
kubectl wait --for=condition=ready ksvc func-a-custom func-b-custom func-c-custom --timeout=300s
kubectl get ksvc | grep custom


### Option B: One-shot deployment

If using the `deploy-all.sh` helper and `manifests/` structure:

export DOCKER_USER=<your-dockerhub-username>
chmod +x deploy-all.sh
./deploy-all.sh
kubectl get ksvc


Expect 9 services (`func-a/b/c-{conc,rps,custom}`) with `READY=True`. [file:2]

---

## 6. Testing the Chains

Expose Kourier on node0 (via NodePort or port-forward) and set:

export NODE_IP=<node0-ip>
export KOURIER_PORT=<kourier-port> # e.g., 32122


### Quick functional test

Concurrency chain
curl -H "Host: func-a-conc.default.example.com" http://$NODE_IP:$KOURIER_PORT/ | jq .

RPS chain
curl -H "Host: func-a-rps.default.example.com" http://$NODE_IP:$KOURIER_PORT/ | jq .

Custom chain
curl -H "Host: func-a-custom.default.example.com" http://$NODE_IP:$KOURIER_PORT/ | jq .


The JSON response includes nested information for A, B, C with per-function latency in milliseconds. [file:2][file:57]

---

## 7. Load Generation & Metrics Collection

### 7.1 `wrk` installation

On node0:

sudo apt-get install -y wrk
wrk --version



### 7.2 Sustained load and metrics

Use `collect-metrics.sh` (if included in your repo) to capture replica counts over time while driving load with `wrk`. For example:

./collect-metrics.sh conc metrics-conc.csv 300
./collect-metrics.sh rps metrics-rps.csv 300
./collect-metrics.sh custom metrics-custom.csv 300


- Inputs: policy name (`conc|rps|custom`), output CSV path, duration in seconds.  
- Outputs: `metrics-*.csv` with timestamped replica counts per function. [file:58]

Run `wrk` in parallel to generate load, e.g.:

wrk -t4 -c50 -d60s --latency
-H "Host: func-a-rps.default.example.com"
http://$NODE_IP:$KOURIER_PORT/


Adjust threads (`-t`), connections (`-c`), and duration (`-d`) to test light/medium/heavy loads. [file:2]

### 7.3 Burst tests

Use `burst-test.sh` to simulate bursts:

export NODE_IP=<node0-ip>
export KOURIER_PORT=<kourier-port>

chmod +x burst-test.sh
./burst-test.sh burst1


This runs two 30 s bursts (8 threads, 200 connections) for each policy (conc, rps, custom) and writes:

- `results/burst-burst1-conc.txt`  
- `results/burst-burst1-rps.txt`  
- `results/burst-burst1-custom.txt`  

Each file contains full `wrk` output (latency distribution, throughput, errors).  

---

## 8. Analysis Scripts

### Cascading latency breakdown

Given a saved JSON response:

curl -H "Host: func-a-rps.default.example.com"
http://$NODE_IP:$KOURIER_PORT/ -o RESPONSE.json

python3 analyze-cascading.py RESPONSE.json


This prints per-function latency and total chain latency. [file:57]

### Propagation Delay Coefficient (PDC)

On any `metrics-*.csv` file:

python3 calculate-pdc.py metrics-conc.csv
python3 calculate-pdc.py metrics-rps.csv
python3 calculate-pdc.py metrics-custom.csv


The script reports:

- First scale-up time for A, B, C  
- Delays between A→B and B→C  
- PDC in seconds per stage and a qualitative interpretation (fast/moderate/slow propagation). [file:58]

---

## 9. Expected Results (High-Level)

From the experiments run with this framework:

- **RPS-based autoscaling**:  
  - Best steady-state performance across light/medium/heavy loads (lowest average latency, highest requests/sec).  
- **Custom (position-aware) autoscaling**:  
  - Excellent cold-start and burst performance due to non-zero min-scale at the head and tuned targets per function.  
- **Concurrency-based autoscaling**:  
  - Higher latencies and lower throughput, especially under heavy and bursty traffic, showing slower propagation and weaker chain coordination.  

Use `metrics-*.csv`, `burst-*.txt`, and outputs from the Python scripts to generate figures/tables for reports or presentations. [file:2][file:58][file:57]

---

## 10. Troubleshooting

Common deployment issues:

- `RevisionMissing` / `ContainerMissing`:  
  - Image name in YAML does not match Docker Hub repo, or image is private.  
  - Fix `image:` in `chain-*.yaml` and re-apply, or re-tag/push images.  

- `ImagePullBackOff` / `ErrImagePull`:  
  - Check `docker pull docker.io/$DOCKER_USER/function-a:v1` from node0.  

- Application crashes (`CrashLoopBackOff`):  
  - Inspect `kubectl logs` for Flask/Python errors.  

- `kubectl wait` timeouts:  
  - Normal for cold starts; wait and re-check `kubectl get ksvc`, `kubectl get rev`, `kubectl get pods -n default`.  

Refer to `SETUP.md` and `config.md` for detailed commands and expected outputs. [file:1][file:2]

---

## 11. License / Acknowledgments

- Educational project for comparing Knative autoscaling policies on CloudLab.  
- Built with Kubernetes, Knative Serving, Kourier, Flannel, and `wrk`.  

