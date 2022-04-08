# https://piotrminkowski.com/2021/12/03/create-kubernetes-clusters-with-cluster-api-and-argocd/
# Create the management cluster
kind create cluster --config mgmt-cluster-config.yaml --name mgmt

# Install Cluster API into the cluster
export CLUSTER_TOPOLOGY=true
clusterctl init --infrastructure docker

# Install Argo CD
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Copy the admin password secret
kubectl get secrets/argocd-initial-admin-secret --context kind-mgmt --template={{.data.password}} | base64 -D | pbcopy

kubectl port-forward svc/argocd-server 8080:80

# Load Argo CD UI in a browser
https://localhost:8080/

# Create a workload cluster manifest
# Just to look at the structure
clusterctl generate cluster c1 --flavor development \
  --infrastructure docker \
  --kubernetes-version v1.23.3 \
  --control-plane-machine-count=3 \
  --worker-machine-count=3 \
  > c1-clusterapi.yaml

clusterctl generate cluster c1 --flavor development-topology \
  --infrastructure docker \
  --kubernetes-version v1.23.3 \
  --control-plane-machine-count=3 \
  --worker-machine-count=3 \
  > c1-clusterapi_clusterclass.yaml

# Delete c1-clusterapi.yaml, we'll use Helm charts in mgmt/ instead
rm c1-clusterapi.yaml

kubectl apply -f argo-cluster-role.yaml
kubectl apply -f argoapp-c1-cluster-create.yaml
kubectl apply -f argoapp-c2-cluster-create.yaml

kind export kubeconfig --name c1
sed -i '' 's/0.0.0.0:/127.0.0.1:/' ~/.kube/config
# Point the kubeconfig to the exposed port of the load balancer, rather than the inaccessible container IP.
sed -i -e "s/server:.*/server: https:\/\/$(docker port c1-lb 6443/tcp | sed "s/0.0.0.0/127.0.0.1/")/g" ./capi-quickstart.kubeconfig

kubectl apply -f https://docs.projectcalico.org/v3.21/manifests/calico.yaml --context kind-c1
kubectl --kubeconfig=./capi-quickstart.kubeconfig \
  apply -f https://docs.projectcalico.org/v3.21/manifests/calico.yaml

kubectl create -f https://projectcalico.docs.tigera.io/manifests/tigera-operator.yaml
kubectl create -f https://projectcalico.docs.tigera.io/manifests/custom-resources.yaml

argocd login localhost:8080

kubectl delete cluster c1
kind delete clusters mgmt