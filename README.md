# autoenv

Create automated environments from PRs.

## Setup

For a local test environment, we suggest using
[kind](https://kind.sigs.k8s.io/), that will spin up your k8s cluster in your
local Docker. According to our tests, at least 4 CPUs and 8 GB of memory should
be allocated for the Docker engine to spin up the clusters.

The following tools will need to be installed:
* [`clusterctl`](https://cluster-api.sigs.k8s.io/user/quick-start#install-clusterctl)
* [`kind`](https://kind.sigs.k8s.io/#installation-and-usage)

Now we need to configure CAPI (Cluster API) that will be responsible for
managing the virtual clusters.

1. Create the configuration file for the cluster with the correct Docker mounts:

```shell
cat > kind-cluster-with-extramounts.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  ipFamily: dual
nodes:
- role: control-plane
  extraMounts:
    - hostPath: /var/run/docker.sock
      containerPath: /var/run/docker.sock
EOF
```

2. Execute the command to create the management cluster:

```shell
kind create cluster --config kind-cluster-with-extramounts.yaml
```

That will change your `kubectl` context to this new cluster.

3. Initialize the cluster with the desired infrastructure:

```shell
export CLUSTER_TOPOLOGY=true
clusterctl init --infrastructure vcluster
```

4. Create the required namespaces:
```shell
kubectl create namespace argocd
kubectl create namespace autoenvs
```

5. (optional) If you want to test it, you can execute the following command,
creating a workload cluster.

```shell
export HELM_VALUES=""
clusterctl generate cluster example \
    --infrastructure vcluster \
    --kubernetes-version v1.28.0 \
    --target-namespace autoenvs | kubectl apply -f -
```

This could take some time to spin up, but you can monitor if it's provisioned
already with the command:

```shell
kubectl get cluster -n autoenvs
```

And finally, retrieve the `kubeconfig` information to access the virtual
cluster:

```shell
clusterctl get kubeconfig example -n autoenvs
```

After you're happy with your test, you can remove the example cluster with the
command:

```shell
kubectl delete cluster example -n autoenvs
```

6. Install ArgoCD:
```shell
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.8.0/manifests/install.yaml
```

7. Patch the ArgoCD repository server to fix the GPG issue:
```shell
kubectl patch deployment argocd-repo-server --patch-file ./argocd-fix/repo.yaml -n argocd
```

8. Port-forward ArgoCD to access the web UI:
```shell
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

9. Retrieve the `admin` password:
```shell
argocd admin initial-password -n argocd
```

10. Log into the web UI: https://localhost:8080 (user `admin`).

11. Log into ArgoCD CLI:
```shell
argocd login localhost:8080 --username admin --password <password>
```

12. Generate a GitHub token for the repository (avoid rate limit issues). It
    needs to have at least Pull Request permissions.
```shell
kubectl create secret generic github-token --from-literal=token=<token> -n argocd
```

13. (optional) Create a basic application (default staging):
```shell
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

14. Create the application set responsible for detecting pull requests:
```shell
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

15. Create your Pull Request with the `preview` tag.

## References

This repository uses the following contents as a reference:
* https://cluster-api.sigs.k8s.io/user/quick-start
* https://github.com/loft-sh/cluster-api-provider-vcluster
* https://github.com/mtougeron/hundreds-of-clusters-demo