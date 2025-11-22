import os
import subprocess

def run_command(cmd, cwd=None, check=True):
    """Execute shell command"""
    print(f"   Running: {cmd}")
    result = subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True, check=check)
    if result.returncode != 0:
        if check:
            print(f"   Error: {result.stderr}")
            raise Exception(f"Command failed: {cmd}")
        else:
            print(f"   Command failed (ignoring): {result.stderr.strip()}")
    return result.stdout

def rm_service_command(name, coin, service_type):
    print(f"\n{'='*60}")
    print(f"IDP: Removing {name} ({service_type}) for {coin}")
    print(f"{'='*60}\n")

    base_dir = os.getcwd()
    namespace = f"{coin.lower()}-app"
    pv_name = f"crypto-pv-{coin.lower()}"


    print("Step 1/9: Suspending ArgoCD auto-sync...")
    run_command(f"kubectl patch application {name} -n argocd --type=merge -p '{{\"spec\":{{\"syncPolicy\":null}}}}'", check=False)
    print(f"   ArgoCD auto-sync suspended")

    print("\nStep 2/9: Deleting ArgoCD application...")
    run_command(f"kubectl delete application -n argocd {name}", check=False)
    print(f"   ArgoCD application deleted")


    print(f"\nStep 3/9: Deleting namespace {namespace}...")
    run_command(f"kubectl delete namespace {namespace} --timeout=60s", check=False)
    

    import time
    print(f"   Waiting for namespace {namespace} to disappear...")
    for _ in range(30):

        result = subprocess.run(
            f"kubectl get namespace {namespace}", 
            shell=True, 
            capture_output=True, 
            text=True
        )
        
        if result.returncode != 0:
            if "NotFound" in result.stderr or "not found" in result.stderr:
                print(f"   Namespace deleted")
                break
        
        time.sleep(2)
    else:
         print(f"   Namespace {namespace} is still terminating (likely stuck on finalizers)")


    print(f"\nStep 3/7: Deleting PersistentVolume...")
    # Force delete PV even if it's in Released state
    run_command(f"kubectl delete pv {pv_name} --force --grace-period=0", check=False)
    
    # Wait a moment for deletion
    import time
    time.sleep(2)
    
    # Verify it's gone
    check_pv = run_command(f"kubectl get pv {pv_name}", check=False)
    if pv_name in check_pv and "NotFound" not in check_pv:
        print(f"   Warning: PV {pv_name} may still exist")
    else:
        print(f"   PV deleted")



    print(f"\nStep 4/8: Cleaning database records...")
    # Clean up database entries for this coin
    cleanup_script = f"""import sqlite3
import os

db_path = '/data/crypto.db'
if os.path.exists(db_path):
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    cur.execute("DELETE FROM crypto_prices WHERE symbol = ?", ('{coin.upper()}',))
    deleted = cur.rowcount
    conn.commit()
    conn.close()
    print(f"Deleted {{deleted}} records for {coin.upper()}")
else:
    print("Database not found")
"""
    
    # Write cleanup script to temp file
    import tempfile
    with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
        f.write(cleanup_script)
        temp_script = f.name
    
    try:
        # Get ingestor pod name
        pod_result = run_command(
            "kubectl get pod -n default -l app=crypto-ingestor -o jsonpath='{.items[0].metadata.name}'",
            check=False
        )
        
        if pod_result and 'crypto-ingestor' in pod_result:
            pod_name = pod_result.strip().strip("'")
            
            # Copy script to pod
            run_command(f"kubectl cp {temp_script} default/{pod_name}:/tmp/cleanup.py", check=False)
            
            # Execute script
            result = run_command(
                f"kubectl exec -n default {pod_name} -- python3 /tmp/cleanup.py",
                check=False
            )
            
            if "Deleted" in result:
                print(f"   {result.strip()}")
            else:
                print(f"   Database cleanup completed")
        else:
            print(f"   Ingestor pod not found (skipping database cleanup)")
    finally:
        # Clean up temp file
        import os as os_module
        if os_module.path.exists(temp_script):
            os_module.remove(temp_script)



    print(f"\nStep 5/8: Deleting application code...")
    app_dir = os.path.join(base_dir, "apps", name)
    if os.path.exists(app_dir):
        import shutil
        shutil.rmtree(app_dir)
        print(f"   Deleted: apps/{name}/")
    else:
        print(f"   Directory doesn't exist: apps/{name}/")


    print(f"\nStep 6/8: Deleting manifests...")
    manifests_dir = os.path.join(base_dir, "gitops", "manifests", name)
    if os.path.exists(manifests_dir):
        import shutil
        shutil.rmtree(manifests_dir)
        print(f"   Deleted: gitops/manifests/{name}/")
    else:
        print(f"   Directory doesn't exist")


    print(f"\nStep 7/8: Deleting ArgoCD app file...")
    argocd_file = os.path.join(base_dir, "gitops", "apps", f"{name}.yaml")
    if os.path.exists(argocd_file):
        os.remove(argocd_file)
        print(f"   Deleted: gitops/apps/{name}.yaml")
    else:
        print(f"   File doesn't exist")


    print(f"\nStep 8/8: Committing to Git...")
    run_command("git add .", cwd=base_dir)
    run_command(f'git commit -m "feat(idp): remove {name} service"', cwd=base_dir, check=False)
    run_command("git push origin main", cwd=base_dir)
    print(f"   Changes pushed to Git")


    print(f"\n{'='*60}")
    print(f"IDP: Service {name} removed successfully!")
    print(f"{'='*60}")
    print(f"\nWhat was deleted:")
    print(f"   • ArgoCD Application: {name}")
    print(f"   • Namespace: {namespace}")
    print(f"   • PersistentVolume: {pv_name}")
    print(f"   • Application Code: apps/{name}/")
    print(f"   • Manifests: gitops/manifests/{name}/")
    print(f"   • ArgoCD Config: gitops/apps/{name}.yaml")
    print(f"\nAll clean!")
    print("")
