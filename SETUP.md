# Infrastructure Setup Guide

**Project:** Comparison of Knative Autoscaling Policies for Serverless Function Chains

## Overview

This guide sets up the infrastructure needed to compare three Knative autoscaling mechanisms:
- **Concurrency-based scaling** (in-flight requests per pod)
- **Request-rate-based scaling (RPS)** (requests per second)
- **Custom metrics-based scaling** (position-aware tuning)

### Technology Stack

- **Platform:** CloudLab (3-node cluster)
- **OS:** Ubuntu 22.04
- **Kubernetes:** v1.28.15
- **Container Runtime:** containerd
- **CNI Plugin:** Flannel
- **Knative Serving:** v1.14.0 (compatible with K8s 1.28)
- **Ingress:** Kourier v1.14.0

### Cluster Architecture
```
┌─────────────────────────────────────────────────────────┐
│                     CloudLab Cluster                    │
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │    node0     │  │    node1     │  │    node2     │   │
│  │ (Control     │  │  (Worker)    │  │  (Worker)    │   │
│  │  Plane)      │  │              │  │              │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
│         │                  │                  │         │
│         └──────────────────┴──────────────────┘         │
│                    Flannel CNI                          │
└─────────────────────────────────────────────────────────┘
                           │
                           ↓
              ┌─────────────────────────┐
              │   Knative Serving       │
              │   + Kourier Ingress     │
              └─────────────────────────┘
```

---

## Prerequisites

### Required Accounts
- CloudLab account (https://www.cloudlab.us/)
- Docker Hub account (https://hub.docker.com/)

### Local Machine Requirements
- SSH client
- Web browser
- Text editor

---

## Phase 1: CloudLab Cluster Setup

### Step 1.1: Create Experiment

1. **Login to CloudLab:** https://www.cloudlab.us/

2. **Start New Experiment:**
   - Navigate to: `Experiments` → `Start Experiment`
   - Select Profile: `small-lan` or `multi-node-cluster`

3. **Configure:**
```
   Number of Nodes: 3
   OS Image: Ubuntu 22.04
   Hardware Type: Any available
```

4. **Schedule:**
```
   Name: knative-function-chain
   Duration: 16 hours (or reserve for 2+ weeks)
```

5. **Wait:** 10-15 minutes for nodes to boot

6. **Note SSH Details:**
   From the experiment page, save the SSH commands:
```bash
   ssh username@node0.experiment.cloudlab.us
   ssh username@node1.experiment.cloudlab.us
   ssh username@node2.experiment.cloudlab.us
```

### Step 1.2: Initial System Setup (ALL NODES)

**SSH into each node (node0, node1, node2) and run:**
```bash
# Update system
sudo apt-get update

# Install essential tools
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common \
    git \
    jq \
    wget \
    vim \
    python3-pip

# Disable swap (required for Kubernetes)
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Verify swap is disabled
free -h  # Swap should show 0
```

### Step 1.3: Configure Kernel Modules (ALL NODES)
```bash
# Load required kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Configure sysctl for Kubernetes
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

```

---

## Phase 2: Kubernetes Installation

### Step 2.1: Install containerd (ALL NODES)
```bash
# Install containerd
sudo apt-get install -y containerd

# Create default configuration
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

# Enable systemd cgroup driver
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Restart and enable
sudo systemctl restart containerd
sudo systemctl enable containerd

# Verify
sudo systemctl status containerd
```

### Step 2.2: Install Kubernetes Components (ALL NODES)
```bash
# Add Kubernetes repository
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | \
    sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | \
    sudo tee /etc/apt/sources.list.d/kubernetes.list

# Install Kubernetes packages
sudo apt-get update
sudo apt-get install -y kubelet=1.28.0-1.1 kubeadm=1.28.0-1.1 kubectl=1.28.0-1.1

# Prevent auto-updates
sudo apt-mark hold kubelet kubeadm kubectl

# Enable kubelet
sudo systemctl enable kubelet
```

### Step 2.3: Initialize Cluster (NODE0 ONLY)
```bash
# Get node0's IP address
export CONTROL_PLANE_IP=$(hostname -I | awk '{print $1}')
echo "Control Plane IP: $CONTROL_PLANE_IP"

# Initialize Kubernetes cluster
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=$CONTROL_PLANE_IP \
  --apiserver-cert-extra-sans=$CONTROL_PLANE_IP

# IMPORTANT: Save the "kubeadm join" command from the output!
# Example:
# kubeadm join 10.10.1.1:6443 --token xxxxx \
#   --discovery-token-ca-cert-hash sha256:yyyyy
```

**Configure kubectl (node0):**
```bash
# Setup kubeconfig
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Verify
kubectl get nodes
# node0 should show "NotReady" (normal, needs CNI)
```

### Step 2.4: Install Flannel CNI (NODE0 ONLY)
```bash
# Deploy Flannel
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Wait for Flannel pods
kubectl wait --for=condition=ready pod -l app=flannel -n kube-flannel --timeout=300s

# Verify node is Ready
kubectl get nodes
# node0 should now show "Ready"
```

### Step 2.5: Join Worker Nodes (NODE1 and NODE2)

**On node1 and node2, run the join command from Step 2.3:**
```bash
# Example (use YOUR actual values):
sudo kubeadm join 10.10.1.1:6443 --token xxxxx \
  --discovery-token-ca-cert-hash sha256:yyyyy
```

**If you lost the join command:**
```bash
# On node0, generate new join command:
kubeadm token create --print-join-command
```

**Verify all nodes (node0):**
```bash
kubectl get nodes

# Expected output (all nodes Ready):
# NAME    STATUS   ROLES           AGE   VERSION
# node0   Ready    control-plane   10m   v1.28.0
# node1   Ready    <none>          5m    v1.28.0
# node2   Ready    <none>          5m    v1.28.0
```

---

## Phase 3: Knative Serving Installation

> **Important:** We're using Knative v1.14.0 because it's compatible with Kubernetes v1.28. Knative v1.17+ requires Kubernetes v1.30+.

### Step 3.1: Install Knative Serving (NODE0)
```bash
# Install Knative CRDs
kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.14.0/serving-crds.yaml

# Wait for CRDs to be established
sleep 15

# Install Knative Core components
kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.14.0/serving-core.yaml

# Wait for all components to be ready (may take 3-5 minutes)
kubectl wait --for=condition=ready pod --all -n knative-serving --timeout=600s

# Verify installation
kubectl get pods -n knative-serving
```

**Expected output (all Running and 1/1 Ready):**
```
NAME                          READY   STATUS    RESTARTS   AGE
activator-55d856fccd-5549s    1/1     Running   0          9s
autoscaler-5fb49c64c7-lhzrq   1/1     Running   0          9s
controller-ddbb9d4f-7bzrh     1/1     Running   0          9s
webhook-85b9744fc5-5b92g      1/1     Running   0          9s
```

### Step 3.2: Install Kourier Ingress (NODE0)
```bash
# Install Kourier
kubectl apply -f https://github.com/knative/net-kourier/releases/download/knative-v1.14.0/kourier.yaml

# Configure Knative to use Kourier
kubectl patch configmap/config-network \
  --namespace knative-serving \
  --type merge \
  --patch '{"data":{"ingress-class":"kourier.ingress.networking.knative.dev"}}'

# Wait for Kourier
kubectl wait --for=condition=ready pod --all -n kourier-system --timeout=300s

# Verify
kubectl get pods -n kourier-system
```

### Step 3.3: Configure Kourier for NodePort (NODE0)

CloudLab doesn't provide LoadBalancer, so we use NodePort:
```bash
# Change service type to NodePort
kubectl -n kourier-system patch svc kourier \
  -p '{"spec":{"type":"NodePort"}}'

# Get the assigned NodePort
export KOURIER_PORT=$(kubectl -n kourier-system get svc kourier \
  -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')

echo "Kourier NodePort: $KOURIER_PORT"

# Get node0's public IP
export NODE_IP=$(hostname -I | awk '{print $1}')
echo "Node IP: $NODE_IP"

# Save to bashrc for persistence
echo "export KOURIER_PORT=$KOURIER_PORT" >> ~/.bashrc
echo "export NODE_IP=$NODE_IP" >> ~/.bashrc
source ~/.bashrc
```

### Step 3.4: Configure DNS (NODE0)
```bash
# Configure Knative domain
kubectl patch configmap/config-domain \
  -n knative-serving \
  --type merge \
  -p '{"data":{"example.com":""}}'
```

**How this works:**
- Services will be accessible at: `<service-name>.<namespace>.example.com`
- We'll use the `Host` header to route requests via NodePort
- Example: `curl -H "Host: myservice.default.example.com" http://$NODE_IP:$KOURIER_PORT`

### Step 3.5: Test Knative Installation (NODE0)
```bash
# Deploy test service
cat <<EOF | kubectl apply -f -
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: hello-test
  namespace: default
spec:
  template:
    spec:
      containers:
      - image: gcr.io/knative-samples/helloworld-go:latest
        env:
        - name: TARGET
          value: "Knative v1.14 on CloudLab"
EOF

# Wait for service to be ready
kubectl wait --for=condition=ready ksvc hello-test --timeout=300s

# Get service status
kubectl get ksvc hello-test

# Test the service
curl -H "Host: hello-test.default.example.com" http://$NODE_IP:$KOURIER_PORT

# Expected output: "Hello Knative v1.14 on CloudLab!"

# Clean up test service
kubectl delete ksvc hello-test
```

**✅ Knative Serving is ready!**

## Phase 4: Installing Monitoring Stack
### Step 4.1: Install Helm Package Manager (NODE0)
```bash
sudo apt-get install curl gpg apt-transport-https --yes
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
```

### Step 4.2: Install Prometheus + Grafana Stack (NODE0)
```bash
# Add Prometheus community Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack (includes Prometheus, Grafana, Alertmanager)
helm upgrade --install kps prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.retention=7d \
  --set prometheus.prometheusSpec.scrapeInterval=15s \
  --wait \
  --timeout 10m
```

**This will take 5-10 minutes. Wait for completion.**
```bash
# Wait for all pods to be ready
kubectl wait --for=condition=ready pod --all -n monitoring --timeout=600s

# Verify installation
kubectl get pods -n monitoring
```

**Expected output (all Running and Ready):**
```
NAME                                                   READY   STATUS    RESTARTS   AGE
alertmanager-kps-kube-prometheus-alertmanager-0        2/2     Running   0          3m
kps-grafana-xxx                                        3/3     Running   0          3m
kps-kube-prometheus-operator-xxx                       1/1     Running   0          3m
kps-kube-state-metrics-xxx                             1/1     Running   0          3m
kps-prometheus-node-exporter-xxx (on each node)        1/1     Running   0          3m
prometheus-kps-kube-prometheus-prometheus-0            2/2     Running   0          3m
```

### Step 4.3: Access Grafana (NODE0)
```bash
# Get Grafana admin password
export GRAFANA_PASSWORD=$(kubectl get secret -n monitoring kps-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d)

echo "Grafana Password: $GRAFANA_PASSWORD"
echo "export GRAFANA_PASSWORD=$GRAFANA_PASSWORD" >> ~/.bashrc

# Port-forward Grafana to be accessible from your local machine
# Option 1: Bind to all interfaces (accessible from outside)
kubectl -n monitoring port-forward --address=0.0.0.0 svc/kps-grafana 3000:80 &
```
Access Grafana in browser

### Install Metrics Server for HPA Support (NODE0)
```bash
# Install metrics-server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch for CloudLab (allows insecure TLS to kubelet)
kubectl -n kube-system patch deployment metrics-server --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

# Wait for metrics-server to be ready
kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=300s

# Verify metrics are available (may take 30-60 seconds)
kubectl top nodes
# Should show CPU and Memory usage for all nodes
```

### Install wrk Load Generator
```bash
# Install wrk
sudo apt-get install -y wrk

# Verify installation
wrk --version
```
**✅ Monitoring stack is ready!**

## Phase 5: Build and Push Docker Images
### Step 5.1: Install Docker on node0
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add your user to docker group (avoid sudo)
sudo usermod -aG docker $USER

# Log out and back in, or run:
newgrp docker

# Verify
docker --version
```

### Step 5.2: Build and Push Images
```bash 
# Login to Docker Hub
docker login
# Enter your Docker Hub username and password

# Set your Docker Hub username
export DOCKER_USER=<your-dockerhub-username>
echo "export DOCKER_USER=$DOCKER_USER" >> ~/.bashrc

# Build images
cd ~/knative-function-chain

docker build -t $DOCKER_USER/function-a:v1 -f Dockerfile.function-a .
docker build -t $DOCKER_USER/function-b:v1 -f Dockerfile.function-b .
docker build -t $DOCKER_USER/function-c:v1 -f Dockerfile.function-c .

# Push to Docker Hub
docker push $DOCKER_USER/function-a:v1
docker push $DOCKER_USER/function-b:v1
docker push $DOCKER_USER/function-c:v1
```
**✅ Docker Images ready!**

---