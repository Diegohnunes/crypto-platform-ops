# Crypto Platform Ops

A fully automated Internal Developer Platform (IDP) for cryptocurrency data collection, ingestion, and visualization running on Kubernetes.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    k3d Cluster (devlab)                 │
│                                                         │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────┐ │
│  │ btc-collector│───▶│crypto-ingestor│───▶│ SQLite  │ │
│  │  (Binance)   │    │   (Processor) │    │(crypto.db)│
│  └──────────────┘    └──────────────┘    └──────────┘ │
│         │                                      │        │
│         │              ┌──────────────────────┘        │
│         │              │                               │
│         ▼              ▼                               │
│  ┌─────────────────────────────────┐                  │
│  │      crypto-frontend            │                  │
│  │   (Dashboard + API Server)      │                  │
│  └─────────────────────────────────┘                  │
│                    │                                   │
│                    ▼                                   │
│         http://localhost:4000                         │
└─────────────────────────────────────────────────────────┘
          │
          ▼
    ┌──────────────┐
    │   ArgoCD     │ ◀─── GitOps Automation
    │ (GitOps CD)  │
    └──────────────┘
```

### Components

- **btc-collector**: Collects real-time cryptocurrency prices from Binance API
  - Historical backfill (5 minutes on startup)
  - 1-minute polling interval
  - No rate limit issues (1200 req/min available)
  
- **crypto-ingestor**: Processes raw JSON data and stores in SQLite
  - Watches `/data/raw/*.json` files
  - Inserts into `crypto_prices` table
  - Auto-cleanup after processing

- **crypto-frontend**: React dashboard with Express backend
  - Real-time price display
  - Historical charts (Recharts)
  - 10-second polling for live updates
  - API endpoints: `/api/cryptos`, `/api/price/{symbol}`, `/api/history/{symbol}`

## Quick Start

### Prerequisites
- k3d
- kubectl
- Docker
- Python 3.x
- Git

### Setup
```bash
# Clone repository
git clone https://github.com/Diegohnunes/crypto-platform-ops.git
cd crypto-platform-ops

# Create k3d cluster
k3d cluster create devlab \
  --agents 1 \
  --port "8080:80@loadbalancer" \
  --port "8443:443@loadbalancer"

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Deploy bootstrap app
kubectl apply -f gitops/bootstrap/bootstrap.yaml

# Wait for ArgoCD to sync
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Port-forward frontend
kubectl port-forward -n default svc/crypto-frontend 4000:80
```

Access: http://localhost:4000

## 🛠 IDP Commands

The platform includes a fully automated IDP for managing cryptocurrency collectors.

### Create a New Collector

```bash
python3 ops-cli/main.py create-service --name eth-collector --coin ETH --type collector
```

**What it does (10 automated steps):**
1.  Generates Go code from template
2.  Builds Docker image (`diegohnunes/{name}:v2.0`)
3.  Imports image to k3d cluster
4.  Creates Kubernetes namespace
5.  Creates PersistentVolume and PersistentVolumeClaim
6.  Generates all Kubernetes manifests
7.  Creates ArgoCD application config
8.  Deploys via ArgoCD
9.  Commits changes to Git
10.  Waits for pod to be ready

**Supported coins:** BTC, ETH, SOL, DOT, MATIC, ADA, AVAX, LINK, UNI, DOGE
(Any crypto with Binance `{SYMBOL}USDT` pair)

### Remove a Collector

```bash
python3 ops-cli/main.py rm-service --name eth-collector --coin ETH --type collector
```

**What it does (8 automated steps):**
1.  Deletes ArgoCD application
2.  Deletes Kubernetes namespace (waits for termination)
3.  Force-deletes PersistentVolume
4.  **Cleans database records** (SQL DELETE via ingestor pod)
5.  Deletes application code
6.  Deletes Kubernetes manifests
7.  Deletes ArgoCD config
8.  Commits changes to Git

## Monitoring

### Prometheus
```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
```
Access: http://localhost:9090

### Grafana
```bash
# Get admin password
kubectl get secret -n monitoring grafana -o jsonpath="{.data.admin-password}" | base64 -d

kubectl port-forward -n monitoring svc/grafana 3000:80
```
Access: http://localhost:3000

## Development

### Rebuild Frontend
```bash
cd apps/crypto-frontend
docker build -t diegohnunes/crypto-frontend:v2.1 .
k3d image import diegohnunes/crypto-frontend:v2.1 -c devlab
kubectl delete pod -n default -l app=crypto-frontend
```

### Rebuild Collector
```bash
cd apps/btc-collector
docker build -t diegohnunes/btc-collector:v2.0 .
k3d image import diegohnunes/btc-collector:v2.0 -c devlab
kubectl delete pod -n default -l app=btc-collector
```

### View Logs
```bash
# Collector logs
kubectl logs -n default -l app=btc-collector --tail=50

# Ingestor logs
kubectl logs -n default -l app=crypto-ingestor --tail=50

# Frontend logs
kubectl logs -n default -l app=crypto-frontend --tail=50
```

## Database

SQLite database located at `/data/crypto.db` (shared PVC)

### Schema
```sql
CREATE TABLE crypto_prices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    symbol TEXT NOT NULL,
    price REAL NOT NULL,
    timestamp TEXT NOT NULL,
    source TEXT NOT NULL
);
```

### Query Database
```bash
# Via ingestor pod
kubectl exec -n default deployment/crypto-ingestor -- \
  sqlite3 /data/crypto.db "SELECT * FROM crypto_prices ORDER BY id DESC LIMIT 10;"
```

## API Endpoints

### GET /api/cryptos
Returns list of available cryptocurrencies
```json
["BTC", "ETH"]
```

### GET /api/price/{symbol}
Returns latest price for a cryptocurrency
```json
{
  "id": 123,
  "symbol": "BTC",
  "price": 85200.01,
  "timestamp": "2025-11-21T17:38:17Z",
  "source": "binance-api"
}
```

### GET /api/history/{symbol}?limit=20
Returns price history (default: last 20 records)
```json
[
  {
    "id": 120,
    "symbol": "BTC",
    "price": 85100.50,
    "timestamp": "2025-11-21T17:35:00Z",
    "source": "binance-historical"
  },
  ...
]
```

## Troubleshooting

### Frontend shows no data
```bash
# Check frontend logs
kubectl logs -n default -l app=crypto-frontend

# Verify database has data
kubectl exec -n default deployment/crypto-ingestor -- \
  sqlite3 /data/crypto.db "SELECT COUNT(*) FROM crypto_prices;"

# Restart frontend
kubectl delete pod -n default -l app=crypto-frontend
```

### Collector not collecting
```bash
# Check collector logs
kubectl logs -n default -l app=btc-collector --tail=100

# Verify Binance API is accessible
kubectl exec -n default deployment/btc-collector -- \
  curl -s "https://api.binance.com/api/v3/ping"
```

### ArgoCD app OutOfSync
```bash
# Manual sync
kubectl patch application btc-collector -n argocd \
  --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'
```

## Project Structure

```
crypto-platform-ops/
├── apps/                      # Application code
│   ├── btc-collector/        # BTC collector (Go)
│   ├── crypto-frontend/      # Dashboard (React + Express)
│   └── crypto-ingestor/      # Data processor (Python)
├── gitops/
│   ├── apps/                 # ArgoCD application definitions
│   ├── manifests/            # Kubernetes manifests
│   └── bootstrap/            # Bootstrap app
├── ops-cli/                  # IDP automation
│   ├── commands/
│   │   ├── create_service.py
│   │   └── rm_service.py
│   ├── templates/
│   │   ├── Dockerfile
│   │   └── main.go.j2
│   └── main.py
└── README.md
```

## Learning Resources

- **GitOps**: ArgoCD automatically syncs from Git to Kubernetes
- **Binance API**: [API Documentation](https://binance-docs.github.io/apidocs/)
- **SQLite**: Lightweight database, perfect for this use case
- **k3d**: Lightweight Kubernetes in Docker

## Contributing

This is a learning/demo project. Feel free to:
- Add more cryptocurrencies
- Improve the dashboard UI
- Add alerting capabilities
- Implement backtesting features

## License

MIT