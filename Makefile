CLUSTER_NAME := k3d-devlab
KUBECONFIG := $(HOME)/.kube/config

.PHONY: all create-cluster delete-cluster install-argocd deploy-bootstrap status help

all: help

help:
	@echo "CryptoLab Platform Engineering - Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  create-cluster       - Create K3d cluster with 3GB memory"
	@echo "  delete-cluster       - Delete the K3d cluster"
	@echo "  install-argocd       - Install ArgoCD via Helm"
	@echo "  deploy-bootstrap     - Deploy the GitOps bootstrap (App of Apps)"
	@echo "  status               - Show cluster and pod status"
	@echo "  port-forward-argocd  - Port forward ArgoCD UI to localhost:8080"
	@echo "  port-forward-grafana - Port forward Grafana to localhost:3000"
	@echo "  port-forward-prometheus - Port forward Prometheus to localhost:9090"
	@echo "  port-forward-backstage - Port forward Backstage to localhost:7007"
	@echo ""

create-cluster:
	@echo "Creating K3d cluster..."
	k3d cluster create --config infra/k3d-config.yaml --servers-memory 3GB
	@echo "Waiting for cluster to be ready..."
	kubectl wait --for=condition=Ready nodes --all --timeout=120s

delete-cluster:
	@echo "Deleting K3d cluster..."
	k3d cluster delete devlab

install-argocd:
	@echo "Installing ArgoCD..."
	helm repo add argo https://argoproj.github.io/argo-helm
	helm repo update
	helm upgrade --install argocd argo/argo-cd \
		--namespace argocd --create-namespace \
		-f infra/argocd-values.yaml
	@echo ""
	@echo "ArgoCD installed!"
	@echo "Get admin password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
	@echo "Port forward: make port-forward-argocd"

deploy-bootstrap:
	@echo "Deploying GitOps bootstrap (App of Apps)..."
	kubectl apply -f gitops/bootstrap.yaml
	@echo "Bootstrap deployed! ArgoCD will sync all applications."

status:
	@echo "=== Cluster Status ==="
	kubectl get nodes
	@echo ""
	@echo "=== ArgoCD Applications ==="
	kubectl get applications -n argocd
	@echo ""
	@echo "=== Pods by Namespace ==="
	kubectl get pods -n argocd
	kubectl get pods -n monitoring
	kubectl get pods -n backstage

port-forward-argocd:
	@echo "Port forwarding ArgoCD..."
	@echo "Access at http://localhost:8080"
	@echo "Username: admin"
	@echo "Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
	kubectl port-forward --address 0.0.0.0 -n argocd svc/argocd-server 8080:80

port-forward-grafana:
	@echo "Port forwarding Grafana..."
	@echo "Access at http://localhost:3000"
	@echo "Username: admin / Password: admin"
	kubectl port-forward --address 0.0.0.0 -n monitoring svc/grafana 3000:80

port-forward-prometheus:
	@echo "Port forwarding Prometheus..."
	@echo "Access at http://localhost:9090"
	kubectl port-forward --address 0.0.0.0 -n monitoring svc/prometheus 9090:9090

port-forward-backstage:
	@echo "Port forwarding Backstage..."
	@echo "Access at http://localhost:7007"
	kubectl port-forward --address 0.0.0.0 -n backstage svc/backstage 7007:7007
