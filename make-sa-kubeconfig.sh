#!/usr/bin/env bash
set -euo pipefail

NAMESPACE=dev
SA=jenkins-deployer
OUT=./kubeconfig-jenkins-deployer

echo "Creating token for ${NAMESPACE}/${SA}..."
TOKEN=$(kubectl -n ${NAMESPACE} create token ${SA} --duration=8760h)
echo "Token created (first 40 chars): ${TOKEN:0:40}..."

echo "Extracting cluster info..."
CLUSTER_NAME=$(kubectl config view -o jsonpath='{.clusters[0].name}')
SERVER=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}')
CA_DATA=$(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')

cat > ${OUT} <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: ${CA_DATA}
    server: ${SERVER}
  name: ${CLUSTER_NAME}
contexts:
- context:
    cluster: ${CLUSTER_NAME}
    user: ${SA}-${NAMESPACE}
    namespace: ${NAMESPACE}
  name: ${SA}-${NAMESPACE}-context
current-context: ${SA}-${NAMESPACE}-context
users:
- name: ${SA}-${NAMESPACE}
  user:
    token: ${TOKEN}
EOF

echo "Kubeconfig written to ${OUT}"
echo "Testing permissions with the new kubeconfig..."

KUBECONFIG=${OUT} kubectl auth can-i create deployments -n ${NAMESPACE}
KUBECONFIG=${OUT} kubectl auth can-i get pods -n ${NAMESPACE}
KUBECONFIG=${OUT} kubectl get ns || true
KUBECONFIG=${OUT} kubectl get deployments -n ${NAMESPACE} || true

echo "Done. Upload ${OUT} to Jenkins as a Secret file credential (see instructions)."

