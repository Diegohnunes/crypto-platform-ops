import os
import subprocess
import time
from jinja2 import Environment, FileSystemLoader

def run_command(cmd, cwd=None, check=True):
    """Execute shell command and return output"""
    print(f"   🔧 Running: {cmd}")
    result = subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True, check=check)
    if result.returncode != 0 and check:
        print(f"   ❌ Error: {result.stderr}")
        raise Exception(f"Command failed: {cmd}")
    return result.stdout

def create_service_command(name, coin, service_type):
    print(f"\n{'='*60}")
    print(f"🚀 IDP: Creating {name} ({service_type}) for {coin}")
    print(f"{'='*60}\n")

    # Paths
    base_dir = os.getcwd()
    templates_dir = os.path.join(base_dir, "ops-cli", "templates")
    output_manifests_dir = os.path.join(base_dir, "gitops", "manifests", name)
    output_apps_dir = os.path.join(base_dir, "gitops", "apps")
    output_code_dir = os.path.join(base_dir, "apps", name)
    namespace = f"{coin.lower()}-app"

    # Context for templates
    context = {
        "name": name,
        "coin": coin.upper(),
        "type": service_type,
        "image": f"diegohnunes/{name}:v2.0",
        "namespace": namespace
    }

    # Jinja2 Setup
    env = Environment(loader=FileSystemLoader(templates_dir))

    # ============================================================
    # STEP 1: Generate Application Code
    # ============================================================
    print("📝 Step 1/10: Generating application code...")
    os.makedirs(output_code_dir, exist_ok=True)
    generate_file(env, "main.go.j2", output_code_dir, "main.go", context)
    
    # Copy Dockerfile
    dockerfile_src = os.path.join(base_dir, "apps", "btc-collector", "Dockerfile")
    dockerfile_dst = os.path.join(output_code_dir, "Dockerfile")
    with open(dockerfile_src, 'r') as src, open(dockerfile_dst, 'w') as dst:
        dst.write(src.read())
    print(f"   📄 Created Dockerfile")

    # ============================================================
    # STEP 2: Build Docker Image
    # ============================================================
    print("\n🐳 Step 2/10: Building Docker image...")
    run_command(f"docker build -t diegohnunes/{name}:v2.0 apps/{name}", cwd=base_dir)
    print(f"   ✅ Image built: diegohnunes/{name}:v2.0")

    # ============================================================
    # STEP 3: Import to k3d
    # ============================================================
    print("\n📥 Step 3/10: Importing image to k3d...")
    run_command(f"k3d image import diegohnunes/{name}:v2.0 -c devlab", cwd=base_dir)
    print(f"   ✅ Image imported to k3d")

    # ============================================================
    # STEP 4: Create Namespace
    # ============================================================
    print(f"\n🏗️  Step 4/10: Creating namespace {namespace}...")
    result = run_command(f"kubectl create namespace {namespace}", check=False)
    if "already exists" in result:
        print(f"   ℹ️  Namespace already exists")
    else:
        print(f"   ✅ Namespace created")

    # ============================================================
    # STEP 5: Create PersistentVolume and PVC
    # ============================================================
    print(f"\n💾 Step 5/10: Creating storage (PV/PVC)...")
    pv_name = f"crypto-pv-{coin.lower()}"
    
    # Check if PV already exists
    pv_exists = run_command(f"kubectl get pv {pv_name}", check=False)
    if pv_name not in pv_exists:
        # Create PV
        pv_yaml = f"""---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: {pv_name}
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
"""
        with open(f"/tmp/{pv_name}.yaml", "w") as f:
            f.write(pv_yaml)
        run_command(f"kubectl apply -f /tmp/{pv_name}.yaml")
        print(f"   ✅ PV created: {pv_name}")
    else:
        print(f"   ℹ️  PV already exists: {pv_name}")

    # Create PVC
    pvc_yaml = f"""---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: crypto-shared-storage
  namespace: {namespace}
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  volumeName: {pv_name}
"""
    with open(f"/tmp/pvc-{namespace}.yaml", "w") as f:
        f.write(pvc_yaml)
    run_command(f"kubectl apply -f /tmp/pvc-{namespace}.yaml")
    print(f"   ✅ PVC created in {namespace}")

    # ============================================================
    # STEP 6: Generate Kubernetes Manifests
    # ============================================================
    print("\n📦 Step 6/10: Generating Kubernetes manifests...")
    os.makedirs(output_manifests_dir, exist_ok=True)
    generate_file(env, "deployment.yaml.j2", output_manifests_dir, "deployment.yaml", context)
    generate_file(env, "service.yaml.j2", output_manifests_dir, "service.yaml", context)
    generate_file(env, "configmap.yaml.j2", output_manifests_dir, "configmap.yaml", context)

    # ============================================================
    # STEP 7: Generate ArgoCD Application
    # ============================================================
    print("\n🔄 Step 7/10: Generating ArgoCD application...")
    os.makedirs(output_apps_dir, exist_ok=True)
    generate_file(env, "argocd-app.yaml.j2", output_apps_dir, f"{name}.yaml", context)

    # ============================================================
    # STEP 8: Apply ArgoCD Application
    # ============================================================
    print("\n🚀 Step 8/10: Deploying to Kubernetes via ArgoCD...")
    run_command(f"kubectl apply -f gitops/apps/{name}.yaml", cwd=base_dir)
    time.sleep(2)
    run_command(f"kubectl -n argocd annotate application {name} argocd.argoproj.io/refresh=hard --overwrite", cwd=base_dir)
    print(f"   ✅ ArgoCD application deployed")

    # ============================================================
    # STEP 9: Commit to Git
    # ============================================================
    print("\n📤 Step 9/10: Committing to Git...")
    run_command("git add .", cwd=base_dir)
    run_command(f'git commit -m "feat(idp): add {name} service for {coin}"', cwd=base_dir, check=False)
    run_command("git push origin main", cwd=base_dir)
    print(f"   ✅ Changes pushed to Git")

    # ============================================================
    # STEP 10: Wait for Pod and Verify
    # ============================================================
    print(f"\n⏳ Step 10/10: Waiting for pod to be ready...")
    print(f"   ⏰ Timeout: 60 seconds")
    try:
        run_command(f"kubectl wait --for=condition=Ready pod -l app={name} -n {namespace} --timeout=60s", cwd=base_dir)
        print(f"   ✅ Pod is ready!")
        
        # Show logs
        print(f"\n📝 Latest logs:")
        logs = run_command(f"kubectl logs -n {namespace} -l app={name} --tail=10", cwd=base_dir, check=False)
        for line in logs.split('\n')[:10]:
            if line:
                print(f"   {line}")
    except:
        print(f"   ⚠️  Pod took longer than expected, but deployment is in progress")
        print(f"   💡 Check status with: kubectl get pods -n {namespace}")

    # ============================================================
    # SUCCESS SUMMARY
    # ============================================================
    print(f"\n{'='*60}")
    print(f"✅ IDP: Service {name} created successfully!")
    print(f"{'='*60}")
    print(f"\n📊 Summary:")
    print(f"   • Application: {name}")
    print(f"   • Coin: {coin}")
    print(f"   • Namespace: {namespace}")
    print(f"   • Image: diegohnunes/{name}:v2.0")
    print(f"   • Code: apps/{name}/main.go")
    print(f"   • Manifests: gitops/manifests/{name}/")
    print(f"   • ArgoCD: gitops/apps/{name}.yaml")
    
    print(f"\n🔍 Useful commands:")
    print(f"   kubectl get pods -n {namespace}")
    print(f"   kubectl logs -n {namespace} -l app={name} -f")
    print(f"   curl http://localhost:4000/api/prices")
    
    print(f"\n🗑️  To remove:")
    print(f"   python ops-cli/main.py rm-service {name} {coin} {service_type}")
    print("")

def generate_file(env, template_name, output_dir, output_filename, context):
    template = env.get_template(template_name)
    content = template.render(context)
    output_path = os.path.join(output_dir, output_filename)
    
    with open(output_path, "w") as f:
        f.write(content)
    print(f"   📄 Created {output_filename}")


