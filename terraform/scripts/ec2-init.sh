#!/bin/bash
set -euo pipefail

export KUBECONFIG=/etc/kubernetes/admin.conf

# ==========================================
# EBS 볼륨 마운트
# ==========================================
setup_ebs() {
  local EBS_MOUNT_PATH="/mnt/data"
  
  find_ebs_device() {
    for device in /dev/nvme[0-9]n[0-9] /dev/sdf /dev/xvdf /dev/xvdg /dev/xvdh; do
      if [ -e "$device" ] && [ "$(lsblk -n -o MOUNTPOINT "$device" 2>/dev/null)" = "" ]; then
        if [ "$(lsblk -n -o TYPE "$device" 2>/dev/null)" = "disk" ]; then
          echo "$device"
          return 0
        fi
      fi
    done
    return 1
  }

  local EBS_DEVICE=""
  for i in {1..30}; do
    EBS_DEVICE=$(find_ebs_device)
    if [ -n "$EBS_DEVICE" ]; then
      break
    fi
    echo "Waiting for EBS volume to attach... ($i/30)"
    sleep 2
  done

  if [ -z "$EBS_DEVICE" ]; then
    echo "ERROR: EBS volume not found after 60 seconds"
    exit 1
  fi

  echo "Found EBS device: $EBS_DEVICE"

  if ! blkid "$EBS_DEVICE" >/dev/null 2>&1; then
    echo "Formatting $EBS_DEVICE as ext4..."
    mkfs.ext4 -F "$EBS_DEVICE"
  fi

  mkdir -p "$EBS_MOUNT_PATH"
  if ! mountpoint -q "$EBS_MOUNT_PATH"; then
    mount "$EBS_DEVICE" "$EBS_MOUNT_PATH"
  fi

  if ! grep -q "$EBS_MOUNT_PATH" /etc/fstab; then
    local UUID=$(blkid -s UUID -o value "$EBS_DEVICE")
    echo "UUID=$UUID $EBS_MOUNT_PATH ext4 defaults,nofail 0 2" >> /etc/fstab
  fi

  df -h "$EBS_MOUNT_PATH"
  echo "EBS 볼륨 마운트 완료"
}

# ==========================================
# Docker 설치
# ==========================================
setup_docker() {
  echo "Docker 설치 시작..."

  apt-get update

  apt-get install -y git curl ca-certificates gnupg lsb-release

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

  apt-get update

  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  systemctl enable docker
  systemctl start docker

  usermod -aG docker ubuntu

  echo "Docker 설치 완료"
}

# ==========================================
# AWS CLI v2 설치 (공식 설치 패키지)
# https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
# ==========================================
setup_aws_cli() {
  echo "AWS CLI 설치 시작..."

  apt-get install -y unzip

  curl -sS "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  unzip -q /tmp/awscliv2.zip -d /tmp
  /tmp/aws/install
  rm -rf /tmp/aws /tmp/awscliv2.zip

  aws --version
  echo "AWS CLI 설치 완료"
}

# ==========================================
# Kubernetes 사전 요구사항 설정
# ==========================================
setup_k8s_prereqs() {
  echo "Kubernetes 사전 요구사항 설정 시작..."

  # Swap 비활성화 (Kubernetes 필수)
  swapoff -a
  sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

  # 커널 모듈 로드
  cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

  modprobe overlay
  modprobe br_netfilter

  # sysctl 네트워크 설정 (Kubernetes 필수)
  cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

  sysctl --system

  echo "Kubernetes 사전 요구사항 설정 완료"
}

# ==========================================
# Kubernetes 설치 및 초기화
# ==========================================
setup_k8s() {
  echo "Kubernetes 설치 및 초기화 시작..."

  local KUBERNETES_VERSION="${KUBERNETES_VERSION:-1.30.0-00}"

  # containerd 설정 (Kubernetes가 사용)
  mkdir -p /etc/containerd
  containerd config default | tee /etc/containerd/config.toml
  sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
  systemctl restart containerd

  # Kubernetes 패키지 설치
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

  apt-get update
  apt-get install -y kubelet kubeadm kubectl
  apt-mark hold kubelet kubeadm kubectl

  # Kubernetes 클러스터 초기화 (단일 노드)
  # Calico 사용 시 pod-network-cidr=192.168.0.0/16 권장
  kubeadm init --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-address=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4) --ignore-preflight-errors=NumCPU

  # kubectl 설정 (root)
  mkdir -p /root/.kube
  cp -i /etc/kubernetes/admin.conf /root/.kube/config

  # kubectl 설정 (ubuntu 사용자)
  mkdir -p /home/ubuntu/.kube
  cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
  chown -R ubuntu:ubuntu /home/ubuntu/.kube

  # API 서버가 준비될 때까지 대기
  echo "API 서버 준비 대기 중..."
  until kubectl get nodes &>/dev/null; do
    echo "Waiting for API server..."
    sleep 5
  done
  echo "API 서버 준비 완료!"

  # Calico CNI 설치 (Flannel 대신 - 더 안정적)
  kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

  # Calico가 배포될 때까지 대기
  echo "Calico CNI 배포 대기 중..."
  kubectl -n kube-system wait --for=condition=Available deployment/calico-kube-controllers --timeout=300s || true
  sleep 30

  # 노드 상태 확인
  kubectl get nodes

  # 포트폴리오 제약으로 단일 노드 클러스터로 띄움
  # 컨트롤 플레인을 워커 노드로도 사용하기 위해 master 노드에 pod 스케줄링 허용
  kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true

  echo "Kubernetes 설치 및 초기화 완료"
}

# ==========================================
# 추가 도구 설치 (Helm, BuildKit, nerdctl, Ingress Controller 등)
# ==========================================
setup_tools() {
  echo "추가 도구 설치 시작..."

  # Helm 설치
  local HELM_VERSION="${HELM_VERSION:-v3.14.0}"
  curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  chmod 700 get_helm.sh
  ./get_helm.sh --version ${HELM_VERSION}
  rm -f get_helm.sh

  helm version

  # 클러스터가 완전히 준비될 때까지 대기
  echo "클러스터 노드가 Ready 상태가 될 때까지 대기 중..."
  kubectl wait --for=condition=Ready nodes --all --timeout=300s

  kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true

  # local-path-provisioner 설치
  kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

  kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

  echo "local-path-provisioner 준비 대기 중..."
  kubectl wait --for=condition=Ready pods -l app=local-path-provisioner -n local-path-storage --timeout=120s

  kubectl patch configmap local-path-config -n local-path-storage --type=merge -p '{"data":{"config.json":"{\"nodePathMap\":[{\"node\":\"DEFAULT_PATH_FOR_NON_LISTED_NODES\",\"paths\":[\"/mnt/data\"]}]}"}}'
  kubectl rollout restart deployment local-path-provisioner -n local-path-storage
  kubectl wait --for=condition=Ready pods -l app=local-path-provisioner -n local-path-storage --timeout=120s

  # BuildKit 설치
  local BUILDKIT_VERSION="0.13.0"
  curl -sSL "https://github.com/moby/buildkit/releases/download/v${BUILDKIT_VERSION}/buildkit-v${BUILDKIT_VERSION}.linux-amd64.tar.gz" | tar -xz -C /tmp
  mv /tmp/bin/buildctl /usr/local/bin/
  mv /tmp/bin/buildkitd /usr/local/bin/
  chmod +x /usr/local/bin/buildctl /usr/local/bin/buildkitd

  cat > /etc/systemd/system/buildkit.service << 'EOF'
[Unit]
Description=BuildKit
Documentation=https://github.com/moby/buildkit
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/buildkitd --oci-worker=false --containerd-worker=true --containerd-worker-namespace=k8s.io
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable buildkit.service
  systemctl start buildkit.service
  
  # nginx Ingress Controller 설치
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
  helm repo update

  # nginx Ingress Controller를 NodePort 타입으로 설치
  # ALB 뒤에서 실제 클라이언트 IP 인식: use-forwarded-headers, proxy-real-ip-cidr (VPC 대역)
  helm install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --create-namespace \
    --set controller.service.type=NodePort \
    --set controller.service.nodePorts.http=30080 \
    --set controller.config.use-forwarded-headers="true" \
    --set controller.config.proxy-real-ip-cidr="10.0.0.0/8" \
    --wait \
    --timeout 5m

  # 설치 확인
  kubectl get pods -n ingress-nginx
  kubectl get svc -n ingress-nginx

  # ArgoCD 설치
  echo "ArgoCD 설치 중..."
  kubectl create namespace argocd
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

  echo "ArgoCD 배포 대기 중..."
  kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=300s || true

  # 경로 기반 Ingress(/argoCD)용 설정: insecure + rootpath + basehref
  kubectl apply -f - <<'ARGOCD_CM'
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cmd-params-cm
  namespace: argocd
data:
  server.insecure: "true"
  server.rootpath: "/argoCD"
  server.basehref: "/argoCD"
ARGOCD_CM

  kubectl rollout restart deployment argocd-server -n argocd
  kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=300s || true

  echo "ArgoCD 설치 완료"

  echo "추가 도구 설치 완료"
}

# ==========================================
# 메인 실행
# ==========================================
main() {
  echo "=== EC2 초기화 시작 ==="

  echo "[1/6] EBS 볼륨 마운트 중..."
  setup_ebs

  echo "[2/6] Docker 설치 중..."
  setup_docker

  echo "[3/6] AWS CLI 설치 중..."
  setup_aws_cli

  echo "[4/6] Kubernetes 사전 요구사항 설정 중..."
  setup_k8s_prereqs

  echo "[5/6] Kubernetes 설치 및 초기화 중..."
  setup_k8s

  echo "[6/6] 추가 도구 설치 중..."
  setup_tools

  # 불필요한 캐시 정리 (디스크 공간 확보)
  echo "캐시 정리 중..."
  apt-get clean
  docker system prune -f
}

# 스크립트 실행
main
