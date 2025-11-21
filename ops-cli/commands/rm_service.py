import os
import subprocess

def run_command(cmd, cwd=None, check=True):
    """Execute shell command"""
    print(f"   🔧 Running: {cmd}")
    result = subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True, check=check)
    if result.returncode != 0 and check:
        print(f"   ❌ Error: {result.stderr}")
        raise Exception(f"Command failed: {cmd}")
    return result.stdout

def rm_service_command(name, coin, service_type):
    print(f"\n{'='*60}")
    print(f"🗑️  IDP: Removing {name} ({service_type}) for {coin}")
    print(f"{'='*60}\n")

    base_dir = os.getcwd()
    namespace = f"{coin.lower()}-app"
    pv_name = f"crypto-pv-{coin.lower()}"

    # ============================================================
    # STEP 1: Delete ArgoCD Application
    # ============================================================
    print("🔄 Step 1/7: Deleting ArgoCD application...")
    run_command(f"kubectl delete application -n argocd {name}", check=False)
    print(f"   ✅ ArgoCD application deleted")

    # ============================================================
    # STEP 2: Delete Namespace (this deletes all resources)
    # ============================================================
    print(f"\n🏗️  Step 2/7: Deleting namespace {namespace}...")
    run_command(f"kubectl delete namespace {namespace}", check=False)
    print(f"   ✅ Namespace deleted")

    # ============================================================
    # STEP 3: Delete PersistentVolume
    # ============================================================
    print(f"\n💾 Step 3/7: Deleting PersistentVolume...")
    run_command(f"kubectl delete pv {pv_name}", check=False)
    print(f"   ✅ PV deleted")

    # ============================================================
    # STEP 4: Delete Application Code
    # ============================================================
    print(f"\n📂 Step 4/7: Deleting application code...")
    app_dir = os.path.join(base_dir, "apps", name)
    if os.path.exists(app_dir):
        import shutil
        shutil.rmtree(app_dir)
        print(f"   ✅ Deleted: apps/{name}/")
    else:
        print(f"   ℹ️  Directory doesn't exist: apps/{name}/")

    # ============================================================
    # STEP 5: Delete Manifests
    # ============================================================
    print(f"\n📦 Step 5/7: Deleting manifests...")
    manifests_dir = os.path.join(base_dir, "gitops", "manifests", name)
    if os.path.exists(manifests_dir):
        import shutil
        shutil.rmtree(manifests_dir)
        print(f"   ✅ Deleted: gitops/manifests/{name}/")
    else:
        print(f"   ℹ️  Directory doesn't exist")

    # ============================================================
    # STEP 6: Delete ArgoCD App File
    # ============================================================
    print(f"\n🔄 Step 6/7: Deleting ArgoCD app file...")
    argocd_file = os.path.join(base_dir, "gitops", "apps", f"{name}.yaml")
    if os.path.exists(argocd_file):
        os.remove(argocd_file)
        print(f"   ✅ Deleted: gitops/apps/{name}.yaml")
    else:
        print(f"   ℹ️  File doesn't exist")

    # ============================================================
    # STEP 7: Commit to Git
    # ============================================================
    print(f"\n📤 Step 7/7: Committing to Git...")
    run_command("git add .", cwd=base_dir)
    run_command(f'git commit -m "feat(idp): remove {name} service"', cwd=base_dir, check=False)
    run_command("git push origin main", cwd=base_dir)
    print(f"   ✅ Changes pushed to Git")

    # ============================================================
    # SUCCESS SUMMARY
    # ============================================================
    print(f"\n{'='*60}")
    print(f"✅ IDP: Service {name} removed successfully!")
    print(f"{'='*60}")
    print(f"\n📊 What was deleted:")
    print(f"   • ArgoCD Application: {name}")
    print(f"   • Namespace: {namespace}")
    print(f"   • PersistentVolume: {pv_name}")
    print(f"   • Application Code: apps/{name}/")
    print(f"   • Manifests: gitops/manifests/{name}/")
    print(f"   • ArgoCD Config: gitops/apps/{name}.yaml")
    print(f"\n✨ All clean!")
    print("")
