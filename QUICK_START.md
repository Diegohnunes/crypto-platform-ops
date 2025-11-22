# Quick Start Guide - 5 Minutes to Running

Complete setup from zero to operational crypto platform in 5 minutes.

## Step 1: Install Prerequisites (2 min)

```bash
# macOS
brew install k3d kubectl terraform

# Linux
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
# Download kubectl: https://kubernetes.io/docs/tasks/tools/
# Download terraform: https://developer.hashicorp.com/terraform/install

# Verify installations
k3d version
kubectl version --client
terraform version
```

## Step 2: Clone & Setup Cluster (1 min)

```bash
git clone https://github.com/Diegohnunes/crypto-platform-ops.git
cd crypto-platform-ops

# Create cluster
k3d cluster create devlab --config infra/k3d-config.yaml --servers-memory 3GB
```

## Step 3: Deploy Platform (1 min)

```bash
# Deploy GitOps bootstrap
kubectl apply -f gitops/bootstrap.yaml

# Wait for infrastructure (30-45 seconds)
kubectl wait --for=condition=Ready pods -n argocd -l app.kubernetes.io/name=argocd-server --timeout=120s
kubectl wait --for=condition=Ready pods -n monitoring -l app=grafana --timeout=120s
```

## Step 4: Setup Grafana Terraform (30 sec)

```bash
# Start port-forward
kubectl port-forward -n monitoring svc/grafana 3000:80 &

# Open Grafana: http://localhost:3000
# Login: admin / admin
# Go to: Administration → Service Accounts → Add service account
# Name: terraform-provisioner
# Role: Admin
# Click "Add service account token"
# Copy the token

# Configure Terraform
cd terraform/grafana
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # or vim/code
```

Edit `terraform.tfvars`:
```hcl
grafana_url = "http://localhost:3000"
grafana_service_account_token = "YOUR_TOKEN_HERE"
prometheus_datasource_uid = "PBFA97CFB590B2093"
```

Save and apply:
```bash
terraform init
terraform apply -auto-approve
cd ../..
```

## Step 5: Deploy BTC Collector (30 sec)

```bash
python ops-cli/main.py create-service btc-collector BTC collector
```

This creates:
- ✅ Go application code
- ✅ Docker image
- ✅ Kubernetes deployment
- ✅ ArgoCD application
- ✅ **Premium Grafana dashboard**

## Access Services

```bash
# Frontend
kubectl port-forward -n default svc/crypto-frontend 4000:4000 &
open http://localhost:4000

# Dashboard (already port-forwarded)
open http://localhost:3000/d/btc-collector-apm

# Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090 &
open http://localhost:9090
```

## Verify Everything Works

```bash
# Check pods
kubectl get pods -A

# View metrics
curl http://localhost:9090/api/v1/query?query=crypto_price

# Check database
kubectl exec -n default deployment/crypto-ingestor -- \
  sqlite3 /data/crypto.db "SELECT count(*) FROM crypto_prices;"
```

## What You Have Now

- ✅ Local Kubernetes cluster (k3d)
- ✅ GitOps automation (ArgoCD)
- ✅ Observability stack (Prometheus + Grafana)
- ✅ BTC price collector (real-time Binance data)
- ✅ SQLite database with historical data
- ✅ React frontend dashboard
- ✅ **Premium APM dashboard with Terraform management**
- ✅ Internal Developer Platform (create/delete services with one command)

## Next Steps

**Create more collectors:**
```bash
python ops-cli/main.py create-service eth-collector ETH collector
python ops-cli/main.py create-service sol-collector SOL collector
```

**Remove a collector:**
```bash
python ops-cli/main.py rm-service eth-collector ETH collector
```

**View logs:**
```bash
kubectl logs -n default -l app=btc-collector -f
```

**See full documentation:** [README.md](README.md)

## Troubleshooting

**Port-forward stopped?**
```bash
pkill -f "port-forward"
kubectl port-forward -n monitoring svc/grafana 3000:80 &
kubectl port-forward -n default svc/crypto-frontend 4000:4000 &
```

**Dashboard not showing data?**
```bash
# Wait 1-2 minutes for data collection
# Force refresh Grafana: Ctrl+Shift+R
# Check metrics: http://localhost:9090/graph?g0.expr=crypto_price
```

**Need help?** Check [README.md](README.md) Troubleshooting section.
