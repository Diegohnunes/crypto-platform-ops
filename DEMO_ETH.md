# Demo: Criando ETH Collector do Zero

Este guia mostra como criar uma nova criptomoeda (ETH) usando o ops-cli.

## Pré-requisitos
- Cluster k3d rodando (devlab)
- ArgoCD instalado
- Docker funcionando

## Passo 1: Criar o Serviço com ops-cli

```bash
cd /home/diego/crypto-plataform/crypto-platform-ops

# Criar o serviço ETH
python ops-cli/main.py create-service eth-collector eth collector
```

**O que foi gerado:**
- ✅ `apps/eth-collector/main.go` - Código da aplicação com Binance API
- ✅ `gitops/manifests/eth-collector/deployment.yaml` - Deployment Kubernetes
- ✅ `gitops/manifests/eth-collector/service.yaml` - Service
- ✅ `gitops/manifests/eth-collector/configmap.yaml` - ConfigMap (COIN=ETH)
- ✅ `gitops/apps/eth-collector.yaml` - ArgoCD Application

## Passo 2: Criar Dockerfile

```bash
cd apps/eth-collector

# Copiar Dockerfile do BTC
cp ../btc-collector/Dockerfile .
```

## Passo 3: Build e Import da Imagem

```bash
# Voltar para root do projeto
cd /home/diego/crypto-plataform/crypto-platform-ops

# Build da imagem
docker build -t diegohnunes/eth-collector:v2.0 apps/eth-collector

# Importar para k3d
k3d image import diegohnunes/eth-collector:v2.0 -c devlab
```

## Passo 4: Criar PersistentVolume para ETH

Edite `gitops/manifests/shared-storage/resources.yaml` e adicione:

```yaml
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: crypto-pv-eth
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteMany
  hostPath:
    path: "/tmp/crypto-data"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: crypto-shared-storage
  namespace: eth-app
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  volumeName: crypto-pv-eth
```

## Passo 5: Deploy via Git

```bash
# Adicionar tudo ao git
git add .

# Commit
git commit -m "feat: add ETH collector with Binance API v2.0"

# Push
git push origin main

# Criar namespace
kubectl create namespace eth-app

# Aplicar PV/PVC
kubectl apply -f gitops/manifests/shared-storage/resources.yaml

# Aplicar ArgoCD app
kubectl apply -f gitops/apps/eth-collector.yaml

# Forçar sync do ArgoCD
kubectl -n argocd annotate application eth-collector argocd.argoproj.io/refresh=hard --overwrite
```

## Passo 6: Verificar

```bash
# Ver pods
kubectl get pods -n eth-app

# Ver logs (aguardar ~30s após pod Running)
kubectl logs -n eth-app -l app=eth-collector --tail=50

# Verificar dados coletados
kubectl exec -n default deployment/crypto-ingestor -- sh -c "ls /data/raw/ETH_*.json | wc -l"

# Ver dados no SQLite
kubectl exec -n default deployment/crypto-ingestor -- sh -c "sqlite3 /data/crypto.db 'SELECT symbol, COUNT(*) FROM prices WHERE symbol=\"ETH\";'"
```

## Resultado Esperado

**Logs do Collector:**
```
Starting ETH Collector (Binance API v2.0)...
Trading Pair: ETHUSDT
🔄 Backfilling 5 minutes of historical data from Binance...
✅ Backfilled 5 historical data points from Binance
Server listening on port 8080
Saved: /data/raw/ETH_1763745000.json | Price: $2845.67
```

**Frontend:**
- ETH aparece na lista de criptomoedas
- Gráfico de linha com preços atualizando
- Página de detalhes com histórico dos últimos 5 minutos

## Troubleshooting

### Pod não inicia
```bash
kubectl describe pod -n eth-app -l app=eth-collector
```

### Sem dados no volume
```bash
kubectl exec -n eth-app deployment/eth-collector -- ls -lh /data/raw
```

### Verificar PVC
```bash
kubectl get pvc -n eth-app
kubectl describe pvc crypto-shared-storage -n eth-app
```

## Comandos Úteis

```bash
# Restart do collector
kubectl delete pod -n eth-app -l app=eth-collector

# Ver todas as apps do ArgoCD
kubectl get applications -n argocd

# Deletar tudo (se precisar recomeçar)
kubectl delete application -n argocd eth-collector
kubectl delete namespace eth-app
kubectl delete pv crypto-pv-eth
rm -rf apps/eth-collector gitops/manifests/eth-collector gitops/apps/eth-collector.yaml
```
