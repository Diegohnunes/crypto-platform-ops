import os
from jinja2 import Environment, FileSystemLoader

def create_service_command(name, coin, service_type):
    print(f"🚀 Scaffolding service: {name} ({service_type}) for {coin}...")

    # Paths
    base_dir = os.getcwd()
    templates_dir = os.path.join(base_dir, "ops-cli", "templates")
    output_manifests_dir = os.path.join(base_dir, "gitops", "manifests", name)
    output_apps_dir = os.path.join(base_dir, "gitops", "apps")

    # Ensure directories exist
    os.makedirs(output_manifests_dir, exist_ok=True)
    os.makedirs(output_apps_dir, exist_ok=True)

    # Jinja2 Setup
    env = Environment(loader=FileSystemLoader(templates_dir))

    # Context for templates
    namespace = f"{coin.lower()}-app"
    context = {
        "name": name,
        "coin": coin,
        "type": service_type,
        "image": f"diegohnunes/btc-collector:v1.3", # Re-using the generic collector image
        "namespace": namespace
    }

    # 1. Generate Deployment
    generate_file(env, "deployment.yaml.j2", output_manifests_dir, "deployment.yaml", context)
    
    # 2. Generate Service
    generate_file(env, "service.yaml.j2", output_manifests_dir, "service.yaml", context)

    # 3. Generate ConfigMap
    generate_file(env, "configmap.yaml.j2", output_manifests_dir, "configmap.yaml", context)

    # 4. Generate ArgoCD Application
    generate_file(env, "argocd-app.yaml.j2", output_apps_dir, f"{name}.yaml", context)

    print(f"✅ Service {name} scaffolded successfully!")
    print(f"👉 Manifests: {output_manifests_dir}")
    print(f"👉 ArgoCD App: {output_apps_dir}/{name}.yaml")
    print("run 'git add . && git commit -m \"feat: add new service\" && git push' to deploy")

def generate_file(env, template_name, output_dir, output_filename, context):
    template = env.get_template(template_name)
    content = template.render(context)
    output_path = os.path.join(output_dir, output_filename)
    
    with open(output_path, "w") as f:
        f.write(content)
    print(f"   📄 Created {output_filename}")
