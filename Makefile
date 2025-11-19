CLUSTER_NAME := cryptolab
KUBECONFIG := $(HOME)/.kube/config

.PHONY: all setup clean

all: setup

setup: create-cluster install-localstack install-postgres

create-cluster:
	@echo "Creating K3d cluster..."
	k3d cluster create --config infra/k3d-config.yaml --servers-memory 3GB
	@echo "Waiting for cluster to be ready..."
	kubectl wait --for=condition=Ready nodes --all --timeout=60s

delete-cluster:
	@echo "Deleting K3d cluster..."
	k3d cluster delete $(CLUSTER_NAME)

install-localstack:
	@echo "Installing LocalStack..."
	helm repo add localstack https://localstack.github.io/helm-charts
	helm repo update
	helm upgrade --install localstack localstack/localstack \
		--namespace localstack --create-namespace \
		-f infra/localstack-values.yaml

install-postgres:
	@echo "Installing PostgreSQL..."
	kubectl apply -f infra/postgres.yaml

status:
	@echo "Cluster Status:"
	kubectl get nodes
	@echo "\nPod Status:"
	kubectl get pods -A

install-argocd:
	@echo "Installing ArgoCD..."
	helm repo add argo https://argoproj.github.io/argo-helm
	helm repo update
	helm upgrade --install argocd argo/argo-cd \
		--namespace argocd --create-namespace \
		-f infra/argocd-values.yaml

port-forward-argocd:
	@echo "Port forwarding ArgoCD Server..."
	@echo "Access at http://localhost:8080"
	@echo "Username: admin"
	@echo "Password: (get it via: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
	kubectl -n argocd port-forward svc/argocd-server 8080:80

install-observability:
	@echo "Installing Prometheus..."
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo add grafana https://grafana.github.io/helm-charts
	helm repo update
	helm upgrade --install prometheus prometheus-community/prometheus \
		--namespace monitoring --create-namespace \
		-f infra/prometheus-values.yaml
	@echo "Installing Grafana..."
	helm upgrade --install grafana grafana/grafana \
		--namespace monitoring --create-namespace \
		-f infra/grafana-values.yaml

port-forward-grafana:
	@echo "Port forwarding Grafana..."
	@echo "Access at http://localhost:3000"
	@echo "Username: admin"
	@echo "Password: admin"
	kubectl -n monitoring port-forward svc/grafana 3000:80


