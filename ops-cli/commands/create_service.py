import os
from jinja2 import Environment, FileSystemLoader

def create_service_command(name, coin, service_type):
    print(f"🚀 Scaffolding service: {name} ({service_type}) for {coin}...")

    # Paths
    base_dir = os.getcwd()
    templates_dir = os.path.join(base_dir, "ops-cli", "templates")
    output_manifests_dir = os.path.join(base_dir, "gitops", "manifests", name)
    output_apps_dir = os.path.join(base_dir, "gitops", "apps")
    output_code_dir = os.path.join(base_dir, "apps", name)

    # Ensure directories exist
    os.makedirs(output_manifests_dir, exist_ok=True)
    os.makedirs(output_apps_dir, exist_ok=True)
    os.makedirs(output_code_dir, exist_ok=True)

    # Jinja2 Setup
    env = Environment(loader=FileSystemLoader(templates_dir))

    # Context for templates
    namespace = f"{coin.lower()}-app"
    context = {
        "name": name,
        "coin": coin.upper(),
        "type": service_type,
        "image": f"diegohnunes/{name}:v2.0",  # Binance-compatible v2.0
        "namespace": namespace
    }

    # 1. Generate Application Code (main.go)
    generate_file(env, "main.go.j2", output_code_dir, "main.go", context)
    
    # 2. Generate Deployment
    generate_file(env, "deployment.yaml.j2", output_manifests_dir, "deployment.yaml", context)
    
    # 3. Generate Service
    generate_file(env, "service.yaml.j2", output_manifests_dir, "service.yaml", context)

    # 4. Generate ConfigMap
    generate_file(env, "configmap.yaml.j2", output_manifests_dir, "configmap.yaml", context)

    # 5. Generate ArgoCD Application
    generate_file(env, "argocd-app.yaml.j2", output_apps_dir, f"{name}.yaml", context)

    print(f"✅ Service {name} scaffolded successfully!")
    print(f"👉 Application Code: {output_code_dir}/main.go")
    print(f"👉 Manifests: {output_manifests_dir}")
    print(f"👉 ArgoCD App: {output_apps_dir}/{name}.yaml")
    print(f"\n📦 Next steps:")
    print(f"   1. cd apps/{name}")
    print(f"   2. docker build -t diegohnunes/{name}:v2.0 .")
    print(f"   3. k3d image import diegohnunes/{name}:v2.0 -c devlab")
    print(f"   4. git add . && git commit -m 'feat: add {name} service' && git push")

def generate_file(env, template_name, output_dir, output_filename, context):
    template = env.get_template(template_name)
    content = template.render(context)
    output_path = os.path.join(output_dir, output_filename)
    
    with open(output_path, "w") as f:
        f.write(content)
    print(f"   📄 Created {output_filename}")

