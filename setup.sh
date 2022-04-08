# Create the management cluster
kind create cluster --config mgmt-cluster-config.yaml --name mgmt

# Install Cluster API into the cluster
clusterctl init --infrastructure docker

# Install Argo CD
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Copy the admin password secret
kubectl get secrets/argocd-initial-admin-secret --template={{.data.password}} | base64 -D | pbcopy

kubectl port-forward svc/argocd-server 8080:80

# Load Argo CD UI in a browser
https://localhost:8080/

# Create a workload cluster manifest
clusterctl generate cluster c1 --flavor development \
  --infrastructure docker \
  --kubernetes-version v1.21.1 \
  --control-plane-machine-count=3 \
  --worker-machine-count=3 \
  > c1-clusterapi.yaml

# Delete c1-clusterapi.yaml, we'll use Helm charts in mgmt/ instead
rm c1-clusterapi.yaml