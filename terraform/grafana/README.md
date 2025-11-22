# Grafana Provider Configuration
# This file configures the Grafana Terraform provider to manage dashboards

# To use:
# 1. Set the Grafana token:
#    export TF_VAR_grafana_service_account_token="<your-token>"
#
# 2. Initialize Terraform:
#    terraform init
#
# 3. Apply configuration:
#    terraform apply

# Dashboard files will be generated in the dashboards/ directory
# Each service will have its own .tf file (e.g., btc-collector.tf)
