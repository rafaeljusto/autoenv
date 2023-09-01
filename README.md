# autoenv

Create automated environments from PRs.

DUMMY!

## Setup

The following tools will need to be installed:
* [`clusterctl`](https://cluster-api.sigs.k8s.io/user/quick-start#install-clusterctl)
* [`minikube`](https://minikube.sigs.k8s.io/docs/start/)

1. Spin up `minikube` using your local Docker as the driver (creating the
management cluster). According to our tests, at least 4 CPUs and 8 GB of memory
should be allocated for the Docker engine to spin up the clusters:

```shell
minikube start --memory=8g --cpus=4 --driver=docker
```

This will change your `kubectl` context to this new cluster. Check the network
`minikube` is running with the following commands:

```shell
minikube ip
docker network inspect minikube
```

Enable `metallb` to easily access virtual clusters, configuring with the correct
IP network:

```shell
minikube addons enable metallb
cat > metallb-ip-config.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 192.168.49.1-192.168.49.254
EOF
kubectl edit -f metallb-ip-config.yaml --namespace=metallb-system
```

Now we need to configure CAPI (Cluster API) that will be responsible for
managing the virtual clusters.

2. Initialize the cluster with the desired infrastructure:

```shell
export CLUSTER_TOPOLOGY=true
clusterctl init --infrastructure vcluster
```

3. Create the required namespaces:
```shell
kubectl create namespace argo
kubectl create namespace argocd
kubectl create namespace argo-events
kubectl create namespace autoenvs
```

4. (optional) If you want to test it, you can execute the following command,
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

5. Install ArgoCD:
```shell
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.8.0/manifests/install.yaml
```

6. Patch the ArgoCD repository server to fix the GPG issue:
```shell
kubectl patch deployment argocd-repo-server --patch-file ./argocd-fix/repo.yaml -n argocd
```

7. Port-forward ArgoCD to access the web UI:
```shell
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

8. Retrieve the `admin` password:
```shell
argocd admin initial-password -n argocd
```

9. Log into the web UI: https://localhost:8080 (user `admin`).

10. Log into ArgoCD CLI:
```shell
argocd login localhost:8080 --username admin --password <password>
```

11. Generate a GitHub token for the repository (avoid rate limit issues). It
    needs to have at least Pull Request permissions.
```shell
kubectl create secret generic github-token --from-literal=token=<token> -n argocd
```

12. Add ArgoCD secret into k8s secrets for internal scripts:
```shell
kubectl create secret generic argocd-login --from-literal=password=<password> --from-literal=username=admin -n argo
```

13. Install Argo workflows, also apply a patch to allow the use of ArgoCD login.
```shell
kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.4.10/install.yaml
kubectl patch deployment \
  argo-server \
  --namespace argo \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": [
  "server",
  "--auth-mode=server"
]}]'
```

14. Install Argo events:
```shell
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml
```

15. Port-forward ArgoCD Workflows to access the web UI:
```shell
kubectl -n argo port-forward deployment/argo-server 2746:2746
```

16. Log into the web UI: https://localhost:2746

17. Install workflow components:
```shell
kubectl apply -n argocd -f argocd/cluster-workflows.yaml
kubectl apply -n argocd -f argocd/rollouts.yaml
```

18. Create the application set responsible for detecting pull requests:
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

19. Create your Pull Request with the `preview` tag.

## References

This repository uses the following contents as a reference:
* https://cluster-api.sigs.k8s.io/user/quick-start
* https://github.com/loft-sh/cluster-api-provider-vcluster
* https://github.com/mtougeron/hundreds-of-clusters-demo
* https://kubebyexample.com/learning-paths/metallb/install
