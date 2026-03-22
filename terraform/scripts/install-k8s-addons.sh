#!/usr/bin/env bash
# terraform apply 후: AWS LB Controller, ingress-nginx, Argo CD (Helm)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${TF_DIR}"

export HELM_CONFIG_HOME="${TF_DIR}/.helm-bootstrap/config"
export HELM_CACHE_HOME="${TF_DIR}/.helm-bootstrap/cache"
export HELM_DATA_HOME="${TF_DIR}/.helm-bootstrap/data"
mkdir -p "${HELM_CONFIG_HOME}" "${HELM_CACHE_HOME}" "${HELM_DATA_HOME}"
cat > "${HELM_CONFIG_HOME}/repositories.yaml" << 'EOF'
apiVersion: v1
generated: "2025-03-22T00:00:00Z"
repositories: []
EOF

command -v terraform >/dev/null || { echo "terraform 필요"; exit 1; }
command -v helm >/dev/null || { echo "helm 필요"; exit 1; }
command -v aws >/dev/null || { echo "aws CLI 필요"; exit 1; }

CLUSTER_NAME="$(terraform output -raw cluster_name)"
AWS_REGION="$(terraform output -raw aws_region)"
ROLE_ARN="$(terraform output -raw aws_lb_controller_role_arn)"
VPC_ID="$(terraform output -raw vpc_id)"
ACM_ARN="$(terraform output -raw acm_certificate_arn)"

aws eks update-kubeconfig --region "${AWS_REGION}" --name "${CLUSTER_NAME}"

INGRESS_VALUES="$(mktemp)"
trap 'rm -f "${INGRESS_VALUES}"' EXIT
sed "s|ACM_ARN_PLACEHOLDER|${ACM_ARN}|g" "${SCRIPT_DIR}/helm-values-ingress-nginx.yaml" > "${INGRESS_VALUES}"

echo "=== AWS Load Balancer Controller ==="
helm upgrade --install aws-load-balancer-controller \
  "https://aws.github.io/eks-charts/aws-load-balancer-controller-1.9.2.tgz" \
  --namespace kube-system \
  --set "clusterName=${CLUSTER_NAME}" \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=${ROLE_ARN}" \
  --set "region=${AWS_REGION}" \
  --set "vpcId=${VPC_ID}" \
  --wait --timeout 10m

echo "=== ingress-nginx ==="
helm upgrade --install ingress-nginx \
  "https://github.com/kubernetes/ingress-nginx/releases/download/helm-chart-4.15.1/ingress-nginx-4.15.1.tgz" \
  --namespace ingress-nginx \
  --create-namespace \
  --values "${INGRESS_VALUES}" \
  --wait --timeout 10m

echo "=== Argo CD ==="
helm upgrade --install argocd \
  "https://github.com/argoproj/argo-helm/releases/download/argo-cd-7.7.16/argo-cd-7.7.16.tgz" \
  --namespace argocd \
  --create-namespace \
  --values "${SCRIPT_DIR}/helm-values-argocd.yaml" \
  --wait --timeout 10m

echo "완료."
