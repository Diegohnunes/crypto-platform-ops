#!/bin/bash
set -e

# Script para criar ETH collector automaticamente
# Este script cria uma nova criptomoeda do zero usando o ops-cli

echo "🚀 Criando ETH Collector..."
echo ""

# 1. Gerar serviço com ops-cli
echo "📝 Passo 1: Gerando serviço com ops-cli..."
python ops-cli/main.py create-service eth-collector eth collector
echo ""

# 2. Copiar Dockerfile
echo "📦 Passo 2: Copiando Dockerfile..."
cp apps/btc-collector/Dockerfile apps/eth-collector/
echo "   ✅ Dockerfile copiado"
echo ""

# 3. Build da imagem Docker
echo "🐳 Passo 3: Building Docker image..."
docker build -t diegohnunes/eth-collector:v2.0 apps/eth-collector
echo ""

# 4. Importar para k3d
echo "📥 Passo 4: Importando para k3d..."
k3d image import diegohnunes/eth-collector:v2.0 -c devlab
echo ""

# 5. Criar namespace
echo "🏗️  Passo 5: Criando namespace eth-app..."
kubectl create namespace eth-app 2>/dev/null || echo "   ℹ️  Namespace já existe"
echo ""

# 6. Adicionar PV e PVC para ETH
echo "💾 Passo 6: Configurando storage..."
cat >> gitops/manifests/shared-storage/resources.yaml << 'EOF'

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
EOF

kubectl apply -f gitops/manifests/shared-storage/resources.yaml
echo "   ✅ PV e PVC criados"
echo ""

# 7. Deploy via ArgoCD
echo "🔄 Passo 7: Deploying via ArgoCD..."
kubectl apply -f gitops/apps/eth-collector.yaml
sleep 2
kubectl -n argocd annotate application eth-collector argocd.argoproj.io/refresh=hard --overwrite
echo ""

# 8. Commit no Git
echo "📤 Passo 8: Commitando no Git..."
git add .
git commit -m "feat: add ETH collector via automated script"
git push origin main
echo ""

# 9. Aguardar pod estar Running
echo "⏳ Passo 9: Aguardando pod iniciar..."
kubectl wait --for=condition=Ready pod -l app=eth-collector -n eth-app --timeout=60s
echo ""

# 10. Verificar
echo "✅ Passo 10: Verificando deployment..."
echo ""
echo "📊 Status do Pod:"
kubectl get pods -n eth-app
echo ""

echo "📝 Logs (primeiras 20 linhas):"
kubectl logs -n eth-app -l app=eth-collector --tail=20
echo ""

echo "💾 Arquivos coletados:"
kubectl exec -n default deployment/crypto-ingestor -- sh -c "ls /data/raw/ETH_*.json 2>/dev/null | wc -l" || echo "0"
echo ""

echo "🎉 ETH Collector criado com sucesso!"
echo ""
echo "📌 Próximos passos:"
echo "   - Aguarde ~30 segundos para o backfill completar"
echo "   - Acesse http://localhost:4000 para ver o frontend"
echo "   - ETH deve aparecer na lista de criptomoedas"
echo ""
echo "🔍 Comandos úteis:"
echo "   kubectl logs -n eth-app -l app=eth-collector -f"
echo "   kubectl exec -n default deployment/crypto-ingestor -- ls /data/raw/"
echo "   curl http://localhost:4000/api/prices"
