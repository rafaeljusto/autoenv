# autoenv

Create automated environments from PRs.

## Setup

1. Create a virtual cluster at https://cloudev.stg.teamworkops.com/.

2. Change `kubectl` to use the new virtual cluster context:
```
export KUBECONFIG=/path/to/location/kubeconfig-vcluster-<name>.yaml
```

3. Create the ArgoCD namespace:
```
kubectl create namespace argocd
```

4. Install ArgoCD:
```
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.8.0/manifests/install.yaml
```

5. Patch the ArgoCD repository server to fix the GPG issue:
```
kubectl patch deployment argocd-repo-server --patch-file ./argocd-fix/repo.yaml -n argocd
```

6. Port-forward ArgoCD to access the web UI:
```
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

7. Retrieve the `admin` password:
```
argocd admin initial-password -n argocd
```

8. Log into the web UI: https://localhost:8080 (user `admin`).

9. Log into ArgoCD CLI:
```
argocd login localhost:8080 --username admin --password <password>
```

10. Generate a Github token for the repository (avoid rate limit issues). It
    needs to have at least Pull Request permissions.
```
kubectl create secret generic github-token --from-literal=token=<token> -n argocd
```

10. Create basic application (default staging):
```
argocd app create base-app \
  --project default \
  --sync-policy automatic \
  --auto-prune --self-heal \
  --repo "https://github.com/rafaeljusto/autoenv" \
  --revision HEAD \
  --path helm \
  --dest-name in-cluster \
  --dest-namespace staging
```

11. Create the application set responsible for detecting pull requests:
```
argocd app create appset \
  --project default \
  --sync-policy automatic \
  --auto-prune --self-heal \
  --repo "https://github.com/rafaeljusto/autoenv" \
  --revision HEAD \
  --path argocd \
  --dest-name in-cluster \
  --dest-namespace argocd
```