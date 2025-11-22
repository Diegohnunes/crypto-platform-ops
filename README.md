# Crypto Platform - Internal Developer Platform

A fully automated Internal Developer Platform (IDP) for crypto price monitoring with GitOps, observability, and Terraform-managed dashboards.

## Table of Contents
- [Features](#features)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Terraform Dashboard Management](#terraform-dashboard-management)
- [Troubleshooting](#troubleshooting)
- [Project Structure](#project-structure)

---

## Features

### Internal Developer Platform (IDP)
- **Fully Automated Service Creation**: One command creates code, Docker image, Kubernetes manifests, ArgoCD app, and Grafana dashboard
- **Zero Manual Steps**: Build, push, deploy, and monitor automatically
- **Service Lifecycle Management**: Create and remove services with `ops-cli`

### Observability
- **Premium APM Dashboards**: Glassmorphism design with radial gradients and modern UI
- **8 Prometheus Metrics per Service**: RED pattern (Rate, Errors, Duration) + business metrics
- **Multi-Percentile Latency Tracking**: p50, p95, p99 response times
- **Infrastructure as Code**: Dashboards managed via Terraform

### GitOps & Automation
- **ArgoCD**: Declarative deployments with auto-sync
- **Continuous Deployment**: Git push triggers automatic deployment
- **Terraform**: Dashboard provisioning and infrastructure management

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     ops-cli (Internal Developer Platform)        │
│  create-service: Code Gen → Docker → K8s → ArgoCD → Dashboard   │
│  rm-service: Clean removal of all resources                     │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ↓
┌─────────────────────────────────────────────────────────────────┐
│                         K3d Cluster (devlab)                     │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────────┐│
│  │  BTC Collector   │  │  Crypto Ingestor │  │ Crypto Frontend││
│  │  (Binance API)   │→ │  (SQLite Writer) │→ │  (React SPA)   ││
│  └──────────────────┘  └──────────────────┘  └────────────────┘│
│                                                                  │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────────┐│
│  │   Prometheus     │  │     Grafana      │  │    ArgoCD      ││
│  │  (Metrics Store) │→ │  (Dashboards)    │  │  (GitOps CD)   ││
│  └──────────────────┘  └──────────────────┘  └────────────────┘│
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ↓
                    Terraform (Dashboard IaC)
```

---

## Prerequisites

### Required Software
- **Docker Desktop** (or Docker Engine + k3d)
- **kubectl** - Kubernetes CLI
- **k3d** - Local Kubernetes cluster
- **Python 3.8+** - For ops-cli
- **Git** - Version control
- **Terraform 1.0+** - Infrastructure as Code
- **Make** (optional) - For Makefile commands

### System Requirements
- **RAM**: 4GB minimum (8GB recommended)
- **CPU**: 2 cores minimum
- **Disk**: 10GB free space
- **OS**: Linux, macOS, or WSL2 on Windows

### WSL2 Users (Windows)
**CRITICAL**: Limit WSL2 memory to prevent system freeze.

Create `C:\Users\<YourName>\.wslconfig`:
```ini
[wsl2]
memory=4GB
processors=2
swap=2GB
```

Then restart WSL: `wsl --shutdown` (in PowerShell as Admin)

See [WSL_SETUP.md](WSL_SETUP.md) for details.

---

## Quick Start

### 1. Clone Repository
```bash
git clone https://github.com/Diegohnunes/crypto-platform-ops.git
cd crypto-platform-ops
```

### 2. Install Dependencies
```bash
# macOS
brew install k3d kubectl terraform

# Linux
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
# Install kubectl: https://kubernetes.io/docs/tasks/tools/
# Install terraform: https://developer.hashicorp.com/terraform/install
```

### 3. Create Cluster
```bash
make create-cluster
# Or manually:
k3d cluster create devlab --config infra/k3d-config.yaml --servers-memory 3GB
```

### 4. Deploy Infrastructure
```bash
# Deploy ArgoCD and monitoring stack
kubectl apply -f gitops/bootstrap.yaml

# Wait for ArgoCD to sync (~30 seconds)
kubectl wait --for=condition=Ready pods -n argocd -l app.kubernetes.io/name=argocd-server --timeout=120s
```

### 5. Setup Grafana for Terraform
```bash
# Port-forward Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80 &

# Login to Grafana (admin/admin) at http://localhost:3000
# Create service account token:
# 1. Go to Administration → Service Accounts
# 2. Create account: "terraform-provisioner" (Admin role)
# 3. Generate token and copy it

# Configure Terraform
cd terraform/grafana
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values:
# grafana_url = "http://localhost:3000"
# grafana_service_account_token = "YOUR_TOKEN_HERE"
# prometheus_datasource_uid = "PBFA97CFB590B2093"  # Get from Grafana datasources

terraform init
terraform apply -auto-approve
```

### 6. Deploy BTC Collector
```bash
cd ../../  # Back to root
python ops-cli/main.py create-service btc-collector BTC collector
```

**This single command:**
- ✅ Generates Go code from template
- ✅ Creates Dockerfile
- ✅ Builds Docker image
- ✅ Imports to k3d cluster
- ✅ Creates Kubernetes namespace
- ✅ Provisions PersistentVolume
- ✅ Generates K8s manifests
- ✅ Deploys via ArgoCD
- ✅ Commits to Git
- ✅ Waits for pod readiness
- ✅ **Creates Grafana dashboard via Terraform**

### 7. Access Services
```bash
# Frontend (port-forward if not already running)
kubectl port-forward -n default svc/crypto-frontend 4000:4000 &

# Grafana (already running from step 5)
# http://localhost:3000

# Services
Frontend:    http://localhost:4000
Dashboard:   http://localhost:3000/d/btc-collector-apm
Prometheus:  kubectl port-forward -n monitoring svc/prometheus 9090:9090
```

---

## Usage

### Creating a New Service

Use the IDP to create a fully configured service:

```bash
python ops-cli/main.py create-service <NAME> <COIN> collector

# Examples:
python ops-cli/main.py create-service eth-collector ETH collector
python ops-cli/main.py create-service sol-collector SOL collector
python ops-cli/main.py create-service doge-collector DOGE collector
```

**What gets created:**
- `/apps/<name>/` - Go source code and Dockerfile
- `/gitops/manifests/<name>/` - Kubernetes manifests
- `/gitops/apps/<name>.yaml` - ArgoCD application
- `/terraform/grafana/<name>.tf` - Dashboard configuration
- Namespace: `<coin>-app`
- **Dashboard**: `http://localhost:3000/d/<name>-apm`

### Removing a Service

```bash
python ops-cli/main.py rm-service <NAME> <COIN> collector

# Example:
python ops-cli/main.py rm-service eth-collector ETH collector
```

**What gets deleted:**
- ArgoCD application
- Kubernetes namespace (and all resources)
- PersistentVolume
- Source code (`/apps/<name>/`)
- Manifests (`/gitops/manifests/<name>/`)
- Database records (SQLite cleanup)
- **Terraform dashboard** (via destroy)
- Git commit + push

### Monitoring Services

```bash
# View pods
kubectl get pods -n <coin>-app

# View logs
kubectl logs -n <coin>-app -l app=<name> -f

# Check metrics
curl http://localhost:9090/api/v1/query?query=crypto_price

# Access dashboard
open http://localhost:3000/d/<name>-apm
```

---

## Terraform Dashboard Management

### Manual Dashboard Operations

```bash
cd terraform/grafana

# View current dashboards
terraform state list

# Plan changes
terraform plan

# Apply changes
terraform apply -auto-approve

# Destroy specific dashboard
terraform destroy -target=grafana_dashboard.<name>_apm
```

### Dashboard Template

Edit `/ops-cli/templates/dashboard.tf.j2` to customize dashboards.

Variables available:
- `{{name}}` - Service name
- `{{coin}}` - Cryptocurrency symbol

### Getting Prometheus Datasource UID

```bash
# Via Grafana UI
# Go to: Configuration → Data Sources → Prometheus → Copy UID

# Or via API
curl -s http://admin:admin@localhost:3000/api/datasources | jq -r '.[] | select(.type=="prometheus") | .uid'
```

---

## Troubleshooting

### Port-Forward Stops Working

```bash
# Kill existing port-forwards
pkill -f "port-forward"

# Restart
kubectl port-forward -n monitoring svc/grafana 3000:80 &
kubectl port-forward -n default svc/crypto-frontend 4000:4000 &
```

### Pod Not Starting

```bash
# Check pod status
kubectl get pods -n <namespace>

# View events
kubectl describe pod <pod-name> -n <namespace>

# Check logs
kubectl logs <pod-name> -n <namespace>

# Common issues:
# - Image pull error: Re-import image (k3d image import)
# - PV mount issue: Delete PVC and recreate
# - Config error: Check ConfigMap
```

### Terraform Errors

```bash
# Grafana not accessible
# Make sure port-forward is running:
kubectl port-forward -n monitoring svc/grafana 3000:80

# Invalid token
# Regenerate service account token in Grafana

# State lock
rm terraform/grafana/.terraform.tfstate.lock.info

# Re-init
cd terraform/grafana && terraform init
```

### Dashboard Not Showing

```bash
# Verify Grafana HTML is enabled
kubectl get deployment -n monitoring grafana -o yaml | grep DISABLE_SANITIZE_HTML
# Should show: GF_PANELS_DISABLE_SANITIZE_HTML: "true"

# If not, edit deployment
kubectl edit deployment -n monitoring grafana
# Add under env:
#   - name: GF_PANELS_DISABLE_SANITIZE_HTML
#     value: "true"

# Restart Grafana
kubectl rollout restart deployment -n monitoring grafana
```

### ArgoCD Sync Issues

```bash
# Force refresh
kubectl -n argocd annotate application <app-name> argocd.argoproj.io/refresh=hard --overwrite

# Check sync status
kubectl get applications -n argocd

# View logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### Database Issues

```bash
# Check database
kubectl exec -n <namespace> -it <pod-name> -- ls -la /data
kubectl exec -n <namespace> -it <pod-name> -- sqlite3 /data/crypto.db "SELECT count(*) FROM crypto_prices;"

# Reset database
kubectl exec -n <namespace> -it <pod-name> -- rm /data/crypto.db
kubectl delete pod -n <namespace> <pod-name>  # Will recreate
```

---

## Project Structure

```
crypto-platform-ops/
├── README.md                    # This file
├── WSL_SETUP.md                # WSL2 memory configuration
├── Makefile                    # Helper commands
│
├── apps/                       # Application source code
│   ├── btc-collector/         # BTC price collector
│   ├── crypto-frontend/       # React frontend
│   └── crypto-ingestor/       # Data ingestion service
│
├── gitops/                    # GitOps configuration
│   ├── bootstrap.yaml         # ArgoCD app-of-apps
│   ├── apps/                  # ArgoCD applications
│   └── manifests/             # Kubernetes manifests
│       ├── btc-collector/
│       ├── crypto-frontend/
│       ├── crypto-ingestor/
│       ├── grafana/
│       └── prometheus/
│
├── infra/                     # Infrastructure config
│   ├── k3d-config.yaml       # k3d cluster setup
│   └── argocd-values.yaml    # ArgoCD Helm values
│
├── ops-cli/                   # Internal Developer Platform
│   ├── main.py               # CLI entry point
│   ├── commands/
│   │   ├── create_service.py # Service creation (11 steps)
│   │   └── rm_service.py     # Service deletion (8 steps)
│   └── templates/            # Jinja2 templates
│       ├── main.go.j2        # Go service template
│       ├── dashboard.tf.j2   # Grafana dashboard template
│       ├── deployment.yaml.j2
│       ├── service.yaml.j2
│       └── ...
│
└── terraform/                 # Infrastructure as Code
    └── grafana/              # Grafana configuration
        ├── provider.tf       # Grafana provider
        ├── variables.tf      # Variables
        ├── terraform.tfvars  # Sensitive values (gitignored)
        └── btc-collector-premium.tf  # BTC dashboard
```

---

## Metrics Collected

Each service exposes the following Prometheus metrics:

| Metric | Type | Description |
|--------|------|-------------|
| `<service>_up` | Gauge | Service health (1=up, 0=down) |
| `<service>_http_requests_total` | Counter | Total HTTP requests by endpoint/status |
| `<service>_http_request_duration_seconds` | Histogram | Request latency distribution |
| `<service>_data_collection_total` | Counter | Total data points collected |
| `<service>_data_collection_errors_total` | Counter | Collection errors |
| `<service>_api_calls_total` | Counter | External API calls by status |
| `crypto_price` | Gauge | Current crypto price (USD) |

---

## Dashboard Features

Premium APM Dashboard includes:

### Global Styling
- **Radial gradient background** across entire page
- **Grid overlay** for tech aesthetic
- **Rajdhani font** for modern look

### Panels
1. **Service Status** - UP/DOWN indicator
2. **Bitcoin Price** - Real-time price with gradient
3. **Data Collection Rate** - Throughput tracking
4. **API Success Rate** - Gauge (0-100%)
5. **HTTP Request Rate** - Timeseries by endpoint
6. **HTTP Response Time** - Multi-percentile (p50, p95, p99)
7. **Data Collection Metrics** - Success vs Errors
8. **API Call Distribution** - Donut chart by status
9. **Bitcoin Price Chart** - Full-width trend

---

## Useful Commands

### Cluster Management
```bash
# Create cluster
make create-cluster

# Delete cluster
make delete-cluster

# View cluster status
make status
```

### Port Forwarding
```bash
# Grafana
make port-forward-grafana

# Prometheus
make port-forward-prometheus

# Frontend (manual)
kubectl port-forward -n default svc/crypto-frontend 4000:4000
```

### Development
```bash
# View all pods
kubectl get pods -A

# Tail logs
kubectl logs -n <namespace> -l app=<name> -f

# Restart deployment
kubectl rollout restart deployment -n <namespace> <name>

# Force ArgoCD sync
kubectl -n argocd annotate application <app> argocd.argoproj.io/refresh=hard --overwrite
```

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

---

## License

MIT License - See LICENSE file for details

---

## Support

- **Issues**: [GitHub Issues](https://github.com/Diegohnunes/crypto-platform-ops/issues)
- **Documentation**: This README
- **Examples**: See `apps/` directory for working examples

---

**Built with**: Kubernetes, ArgoCD, Prometheus, Grafana, Terraform, Python, Go, React