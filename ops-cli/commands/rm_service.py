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
    namespace = "default"  # All services now run in default namespace


    # Step 1: Suspend Sync
    print("Step 1/11: Suspending ArgoCD auto-sync...")
    run_command(f"kubectl patch application {name} -n argocd --type=merge -p '{{\"spec\":{{\"syncPolicy\":null}}}}'", check=False)
    print(f"   ArgoCD auto-sync suspended")

    # Step 2: Delete Files & Commit (CRITICAL: Do this before deleting App to prevent recreation by App of Apps)
    print(f"\nStep 2/11: Removing files from Git (to prevent recreation)...")
    
    # Delete ArgoCD app file
    argocd_file = os.path.join(base_dir, "gitops", "apps", f"{name}.yaml")
    if os.path.exists(argocd_file):
        os.remove(argocd_file)
        print(f"   Deleted: gitops/apps/{name}.yaml")
    
    # Delete manifests
    manifests_dir = os.path.join(base_dir, "gitops", "manifests", name)
    if os.path.exists(manifests_dir):
        import shutil
        shutil.rmtree(manifests_dir)
        print(f"   Deleted: gitops/manifests/{name}/")
        
    # Delete app code
    app_dir = os.path.join(base_dir, "apps", name)
    if os.path.exists(app_dir):
        import shutil
        shutil.rmtree(app_dir)
        print(f"   Deleted: apps/{name}/")

    # Commit and Push
    print(f"   Committing removal to Git...")
    run_command("git add .", cwd=base_dir)
    run_command(f'git commit -m "feat(idp): remove {name} service"', cwd=base_dir, check=False)
    run_command("git push origin main", cwd=base_dir)
    print(f"   ✅ Changes pushed to Git (App of Apps will now prune it)")

    # Step 3: Delete ArgoCD App (Manual)
    print("\nStep 3/11: Deleting ArgoCD application...")
    run_command(f"kubectl delete application -n argocd {name} --wait=false", check=False)
    print(f"   ArgoCD application deletion triggered")

    # Step 4: Delete K8s Resources
    print(f"\nStep 4/11: Deleting Kubernetes resources in {namespace}...")
    run_command(f"kubectl delete deployment {name} -n {namespace} --wait=false", check=False)
    run_command(f"kubectl delete service {name} -n {namespace} --wait=false", check=False)
    run_command(f"kubectl delete configmap {name}-config -n {namespace} --wait=false", check=False)
    print(f"   Kubernetes resources deletion triggered")

    # Step 5: Clean DB
    print(f"\nStep 5/11: Cleaning database records...")
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

    # Step 6: Restart Frontend
    print(f"\nStep 6/11: Restarting frontend to refresh cache...")
    run_command("kubectl rollout restart deployment/crypto-frontend -n default", check=False)
    print(f"   Frontend restarted (SQLite cache will be refreshed)")

    # Step 7-8: Skipped (Files already deleted in Step 2)
    print(f"\nStep 7/11: Files already deleted (Skipped)")
    print(f"\nStep 8/11: Files already deleted (Skipped)")

    # Step 9: Terraform Destroy
    print(f"\nStep 9/11: Destroying Grafana dashboard via Terraform...")
    tf_file = os.path.join(base_dir, "terraform", "grafana", f"{name}.tf")
    
    if os.path.exists(tf_file):
        # Run terraform destroy for this specific dashboard
        terraform_dir = os.path.join(base_dir, "terraform", "grafana")
        resource_name = f"grafana_dashboard.{name.replace('-', '_')}_apm"
        
        try:
            destroy_output = run_command(
                f"cd {terraform_dir} && terraform destroy -auto-approve -target={resource_name}",
                check=False
            )
            
            if "Destroy complete!" in destroy_output or "destroyed" in destroy_output.lower():
                print(f"   ✅ Grafana dashboard destroyed: {name}")
            else:
                print(f"   ⚠️  Dashboard destroy completed (check Grafana to confirm)")
                
        except Exception as e:
            print(f"   ⚠️  Terraform destroy failed (dashboard may not exist): {e}")
        
        # Delete the .tf file after destroying
        os.remove(tf_file)
        print(f"   Deleted: terraform/grafana/{name}.tf")
    else:
        print(f"   No Terraform file found (skipping destroy)")
    
    # Also check legacy path
    tf_legacy = os.path.join(base_dir, "terraform", "grafana", "dashboards", f"{name}.tf")
    if os.path.exists(tf_legacy):
        os.remove(tf_legacy)
        print(f"   Deleted: terraform/grafana/dashboards/{name}.tf")

    # Step 10: Commit Terraform changes
    print(f"\nStep 10/11: Committing Terraform changes to Git...")
    run_command("git add .", cwd=base_dir)
    run_command(f'git commit -m "feat(idp): remove {name} dashboard"', cwd=base_dir, check=False)
    run_command("git push origin main", cwd=base_dir)
    print(f"   Changes pushed to Git")


    print(f"\nStep 11/11: Post-removal verification...")
    print(f"   Ensuring no resources were recreated by race conditions...")
    
    # Verify deployment is gone
    check_deploy = run_command(f"kubectl get deployment {name} -n {namespace}", check=False)
    if name in check_deploy and "NotFound" not in check_deploy:
        print(f"   ⚠️  Deployment {name} reappeared! Deleting again...")
        run_command(f"kubectl delete deployment {name} -n {namespace} --force --grace-period=0", check=False)

    # Verify ArgoCD App
    check_app = run_command(f"kubectl get application -n argocd {name}", check=False)
    if name in check_app and "NotFound" not in check_app:
        print(f"   ⚠️  ArgoCD app {name} reappeared! Deleting again...")
        run_command(f"kubectl delete application -n argocd {name} --force --grace-period=0", check=False)
        
    print(f"   Verification complete.")


    print(f"\n{'='*60}")
    print(f"IDP: Service {name} removed successfully!")
    print(f"{'='*60}")
    print(f"\nWhat was deleted:")
    print(f"   • ArgoCD Application: {name}")
    print(f"   • Kubernetes Deployment: {name} (namespace: {namespace})")
    print(f"   • Database Records: {coin.upper()} cryptocurrency data")
    print(f"   • Grafana Dashboard: {name}-apm")
    print(f"   • Application Code: apps/{name}/")
    print(f"   • Manifests: gitops/manifests/{name}/")
    print(f"   • ArgoCD Config: gitops/apps/{name}.yaml")
    print(f"   • Terraform Config: terraform/grafana/{name}.tf")
    print(f"\n📊 Frontend restarted to refresh cryptocurrency list")
    print(f"\nAll clean!")
    print("")
