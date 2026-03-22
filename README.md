# 한글챗 인프라 (hanguelchat-infra)

![Image](https://github.com/user-attachments/assets/430cdd3d-f717-4d32-9eab-5137ae5b32f1)

## 1. 개요

**한글챗** 서비스의 AWS·Kubernetes 인프라와 배포 매니페스트를 관리하는 저장소입니다. 예전에는 프론트·백엔드와 한 저장소에 있었으나, **인프라만 별도 repo로 분리**했습니다. 애플리케이션 코드·CI(이미지 빌드) 워크플로는 각 앱 저장소에서 진행하고, 여기서는 **Terraform(EKS)·`k8s/`·Argo CD**만 다룹니다.

---

## 2. Terraform IaC 구성 (EKS)

### 아키텍처 개요

<img width="546" height="874" alt="Image" src="https://github.com/user-attachments/assets/6f831611-6ca0-49ff-a2f1-ad33ccb3f178" />

### 구성 요소 및 역할

| 구분 | 구성 요소 | 설명 | Terraform 리소스 |
|------|-----------|------|------------------|
| **입구** | Route 53, ACM | DNS, TLS(NLB·ingress 연동) | 콘솔 관리, `var.acm_certificate_arn` |
| **네트워크** | VPC, IGW, 퍼블릭/프라이빗 서브넷 | NLB·NAT·EKS 노드 배치 | `aws_vpc.main`, `aws_subnet.*`, `aws_internet_gateway.main` |
| **클러스터** | EKS, 노드 그룹 | 관리형 컨트롤 플레인, OIDC(IRSA) | `aws_eks_cluster.main`, `aws_eks_node_group.main` |
| **스토리지** | EBS CSI, StorageClass `gp3` | PVC·EBS | `aws_eks_addon.ebs_csi`, `kubernetes_storage_class_v1.ebs_gp3` |
| **로드밸런싱** | AWS LB Controller (Helm) | Ingress용 NLB | `helm_release.aws_lb_controller` |
| **애드온** | vpc-cni, CoreDNS, kube-proxy | EKS 애드온 | `aws_eks_addon.*` |
| **기타** | NAT+EIP, SG, VPC 엔드포인트 | 아웃바운드, SSM 등 | `nat_instance.tf`, `security_groups.tf`, `vpc_endpoints.tf` |

### 트래픽 흐름

1. **인바운드**: Route 53 → **NLB**(ACM) → **ingress-nginx** → Service → Pod.
2. **아웃바운드**: 프라이빗 서브넷 → **NAT** → 인터넷.
3. **관리**: **VPC 엔드포인트(SSM)** 등.

### Terraform 파일

| 파일 | 역할 |
|------|------|
| `main.tf` | Provider, EKS `exec` 인증 |
| `backend.tf` | State S3 |
| `variables.tf`, `outputs.tf` | 변수·출력 |
| `vpc.tf`, `nat_instance.tf`, `security_groups.tf`, `vpc_endpoints.tf` | 네트워크 |
| `eks.tf` | 클러스터·노드·OIDC·애드온·EBS CSI IRSA |
| `aws_lb_controller.tf` | LB Controller Helm·IRSA |
| `kubernetes_storage.tf` | `gp3` 기본 StorageClass |

---

## 3. CI/CD

<img width="2356" height="445" alt="Image" src="https://github.com/user-attachments/assets/e7472588-5584-4ca5-8ce5-f2e78c5ab108" />

### CI (앱 저장소)

- **트리거**: 앱 repo `main` push, 경로별 `frontend/**` 또는 `backend/**`.
- **흐름**: ECR 로그인 → Docker 빌드·태그(`github.sha`) → ECR 푸시.
- **시크릿**: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` 등.

### CD (이 저장소 + Argo CD)

<img width="864" height="474" alt="Image" src="https://github.com/user-attachments/assets/1fb154bb-f7f5-4967-b2c7-ad173b549190" />

- Argo CD는 클러스터에 Helm으로 설치, **`k8s/argocd/`** Application으로 Git 동기화.
- `hangeul-chat-frontend` → `k8s/prod/frontend`, `hangeul-chat-backend` → `k8s/prod/backend`, `hangeul-chat-infra` → 다중 sources(`mysql`, `redis`, `ingress`).
- Argo UI: `helm-values-argocd.yaml`에서 `/argoCD` 서브패스.

---

## 4. 쿠버네티스 구조

<img width="720" height="756" alt="Image" src="https://github.com/user-attachments/assets/62d47f9b-837a-415f-9d02-1708bf819f61" />


- **EKS**에서 워크로드 실행. 프론트·백은 Deployment **replicas 3**, `startupProbe` / liveness / readiness로 헬스체크.
- **ingress-nginx**(`IngressClass: nginx`), 앞단 **NLB**(ACM). 매니페스트는 **`k8s/dev/`**, **`k8s/prod/`**, Argo는 **`k8s/argocd/`**.

| 구분 | 리소스 | 설명 |
|------|--------|------|
| Deployment | `prod/frontend`, `prod/backend` | 앱 Pod |
| StatefulSet | `prod/mysql`, `prod/redis`(마스터·Sentinel) | DB·캐시 |
| Ingress | `hangeul-chat-ingress`, `argocd-ingress` | 경로·호스트 라우팅 |
| Service | frontend/backend, MySQL·Redis 등 | 클러스터 내부 통신 |
| 스토리지 | PVC, `gp3` | EBS CSI |

---

## 5. 겪은 문제 (인프라)

### MySQL 준비 전에 백엔드 기동

백엔드가 MySQL보다 먼저 뜨면 연결 실패·재시작 루프. **initContainer**로 `mysql-service:3306` 대기 후 기동.

### 백엔드 Pod Ready 지연

DB 초기화 지연·`initialDelaySeconds` 고정 대기로 Ready까지 100초 이상 소요. **MariaDB**로 전환·**startupProbe**로 실제 기동에 맞춰 대기 시간 축소(평균 약 60%대 단축).

---

## 6. 추후 보완 (인프라)

- **DB·Redis 고가용성**: 복제·페일오버·백업 전략 고도화.
- **노드·워크로드 오토스케일**: Cluster Autoscaler, HPA 등.
- **카나리아 배포**: Argo Rollouts 또는 트래픽 분산 단계적 도입.

---
