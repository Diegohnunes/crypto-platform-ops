# CryptoLab Platform Engineering Home Lab

A resource-optimized Platform Engineering demonstration featuring GitOps, Observability, and an Internal Developer Portal (IDP).

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    K3d Cluster (3GB RAM)                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────┐   │
│  │   ArgoCD    │  │ Prometheus   │  │   Backstage     │   │
│  │  (GitOps)   │  │  (Metrics)   │  │     (IDP)       │   │
│  │   ~300 MB   │  │    ~80 MB    │  │    ~256 MB      │   │
│  └─────────────┘  └──────────────┘  └─────────────────┘   │
│                                                             │
│  ┌─────────────┐                                           │
│  │   Grafana   │                                           │
│  │ (Dashboards)│                                           │
│  │    ~80 MB   │                                           │
│  └─────────────┘                                           │
│                                                             │
│  Total Resources: ~1.7 GB / 3.7 GB (45% used)              │
└─────────────────────────────────────────────────────────────┘
```

## ✨ Features

- ✅ **GitOps**: ArgoCD with App-of-Apps pattern
- ✅ **Observability**: Prometheus + Grafana (application metrics only)
- ✅ **IDP**: Backstage with software templates
- ✅ **Pure YAML**: All deployments use YAML manifests (no Helm charts)
- ✅ **Resource Optimized**: ~400 MB saved via aggressive optimization

## 📁 Repository Structure

```
crypto-platform-ops/
├── gitops/
│   ├── apps/              # ArgoCD Application definitions
│   ├── manifests/         # Pure YAML deployments
│   │   ├── backstage/
│   │   ├── grafana/
│   │   └── prometheus/
│   └── bootstrap.yaml     # App-of-Apps entry point
├── idp/
│   ├── catalog-info.yaml  # Backstage catalog registration
│   └── templates/         # Software templates
│       └── crypto-collector/
├── infra/
│   ├── argocd-values.yaml # ArgoCD Helm values
│   └── k3d-config.yaml    # K3d cluster config
├── Makefile               # Cluster management commands
└── WSL_SETUP.md           # WSL2 configuration guide
```

## 🚀 Quick Start

### Prerequisites
- WSL2 (configured with 4-5GB memory via `.wslconfig`)
- Docker Desktop
- kubectl, k3d, helm

### 1. Create Cluster
```bash
make create-cluster
```

### 2. Install ArgoCD
```bash
make install-argocd
```

### 3. Deploy Platform Components
```bash
make deploy-bootstrap
```

### 4. Access Services

**ArgoCD UI:**
```bash
make port-forward-argocd
# Access: http://localhost:8080
# Username: admin
# Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

**Backstage IDP:**
```bash
make port-forward-backstage
# Access: http://localhost:7007
```

**Prometheus:**
```bash
make port-forward-prometheus
# Access: http://localhost:9090
```

**Grafana:**
```bash
make port-forward-grafana
# Access: http://localhost:3000
# Username: admin / Password: admin
```

## 📊 Resource Consumption

| Component | Memory | CPU | Pods |
|-----------|--------|-----|------|
| K3s Server | 1.04 GB | - | - |
| ArgoCD | ~300 MB | ~150m | 5 |
| Prometheus | ~80 MB | ~50m | 1 |
| Grafana | ~80 MB | ~25m | 1 |
| Backstage | ~256 MB | ~100m | 1 |
| **Total** | **~1.7 GB** | **~325m** | **8** |

**Available**: ~2 GB free for applications 🎉

## 🎯 Software Templates

The platform includes a **Crypto Collector** template that demonstrates:
- Self-service application creation via Backstage
- Automatic GitHub repository generation
- Ready-to-deploy Kubernetes manifests
- GitOps-ready structure

**Create a new collector:**
1. Access Backstage at `http://localhost:7007/create`
2. Select "Crypto Collector Service"
3. Fill in the service name and cryptocurrency symbol
4. Click "Create"

## 🔧 Customization

### Add New Components
1. Create YAML manifests in `gitops/manifests/<component>/`
2. Create ArgoCD Application in `gitops/apps/<component>.yaml`
3. Commit and push - ArgoCD will auto-deploy

### Adjust Resource Limits
Edit the deployment YAMLs in `gitops/manifests/*/deployment.yaml`

## 📚 Documentation

- [WSL2 Setup Guide](./WSL_SETUP.md)
- [Implementation Plan](../.gemini/antigravity/brain/.../implementation_plan.md)
- [Walkthrough](../.gemini/antigravity/brain/.../walkthrough.md)

## 🎓 Learning Outcomes

This lab demonstrates:
- ✅ GitOps workflows with ArgoCD
- ✅ Resource optimization techniques
- ✅ Pure YAML vs Helm trade-offs
- ✅ IDP implementation with Backstage
- ✅ Platform Engineering principles

## 🧹 Cleanup

```bash
make delete-cluster
```

## 📄 License

MIT