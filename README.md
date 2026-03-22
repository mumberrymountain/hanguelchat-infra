# 한글챗 (Hangeul Chat)

![Image](https://github.com/user-attachments/assets/430cdd3d-f717-4d32-9eab-5137ae5b32f1)

## 1. 개요

### About

**한글 문서(HWP/HWPX) 기반 AI 채팅 서비스**

- 국내 공공기관과 기업에서 널리 사용되는 HWP/HWPX 문서를 AI와 대화하며 분석할 수 있는 서비스
- 문서를 업로드하면 AI가 자동으로 내용을 요약하고, 이후 문서 기반 Q&A 채팅이 가능
- HWP/HWPX 텍스트 추출 라이브러리(hwplib, hwpxlib)와 Spring AI를 결합하여 구현
- 실시간 스트리밍 응답으로 자연스러운 대화 경험 제공
- 다국어(한국어, 영어, 아랍어) 및 다크/라이트 테마 지원

### Tech Stack

```
┌─────────────────────────────────────────────────────────────────┐
│                          Frontend                               │
│  ┌───────────┐  ┌────────────┐  ┌────────────┐  ┌─────────────┐ │
│  │ Next.js 15│  │ React 19   │  │ TypeScript │  │Tailwind CSS │ │
│  └───────────┘  └────────────┘  └────────────┘  └─────────────┘ │
│  ┌────────────┐  ┌───────────┐  ┌────────────┐  ┌────────────┐  │
│  │  Zustand   │  │ next-intl │  │next-themes │  │   Sonner   │  │
│  └────────────┘  └───────────┘  └────────────┘  └────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼ REST API + SSE Streaming
┌─────────────────────────────────────────────────────────────────┐
│                          Backend                                │
│  ┌───────────┐  ┌────────────┐  ┌───────────┐  ┌─────────────┐  │
│  │  Java 21  │  │Spring Boot │  │ Spring AI │  │   WebFlux   │  │
│  │           │  │    3.5     │  │   1.0.1   │  │ (Reactive)  │  │
│  └───────────┘  └────────────┘  └───────────┘  └─────────────┘  │
│  ┌────────────────┐  ┌─────────────────────────────────────────┐│
│  │ hwplib/hwpxlib │  │        Spring Data JPA + Redis          ││
│  └────────────────┘  └─────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Infrastructure                            │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   Docker        │  │  Kubernetes     │  │   Terraform     │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         DB                                      │
│  ┌─────────────────┐  ┌─────────────────┐                       │
│  │  MariaDB 10     │  │  Redis 7        │                       │
│  └─────────────────┘  └─────────────────┘                       │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. 주요 기능

### 문서 업로드 및 AI 요약

- **드래그 앤 드롭** 또는 클릭으로 HWP/HWPX 파일 업로드
- 문서 업로드 시 **hwplib/hwpxlib**를 통해 텍스트 자동 추출
- **GPT API**를 활용한 문서 내용 자동 요약
- 실시간 **SSE(Server-Sent Events) 스트리밍**으로 타이핑 효과 제공

### 문서 기반 Q&A 채팅

- 업로드된 문서 내용을 기반으로 자유로운 질의응답 가능
- 대화 히스토리 유지로 맥락을 이해한 연속 대화 지원
- 친근한 구어체로 자연스러운 대화 경험 제공

### 사용자 경험

<img width="920" height="401" alt="Image" src="https://github.com/user-attachments/assets/b6cd0151-dc22-49c8-8c83-ae7dc6f48388" />

- **다크/라이트 테마**: IDE 스타일의 세련된 다크 테마와 밝은 라이트 테마 지원

<img width="920" height="401" alt="Image" src="https://github.com/user-attachments/assets/873fa60e-c43f-4984-8ccd-99657aab20db" />

- **다국어 지원**: 한국어, 영어, 아랍어 3개 언어 지원 (next-intl)
- **회원 관리**: 로그인/회원가입으로 대화 기록 영구 저장 <br>
- **사이드바**: 이전 채팅 스레드 목록 관리 (이름 변경, 삭제)

---

## 3. Terraform IaC 구성

### 아키텍처 개요

<img width="434" height="920" alt="Image" src="https://github.com/user-attachments/assets/d36161d0-5d47-454b-b81c-f0b1a5a0d315" />

### 구성 요소 및 역할

| 구분 | 구성 요소 | 설명 | Terraform 리소스 |
|------|-----------|------|------------------|
| **입구** | Route 53 (DNS) | 도메인 요청 및 DNS 라우팅 | AWS 콘솔로 생성 및 관리 |
| | ACM | SSL/TLS 인증서 (ALB에 적용) | AWS 콘솔로 생성 및 관리, `var.acm_certificate_arn`에서 참고 |
| **네트워크** | VPC | 가상 프라이빗 클라우드, 다중 AZ 기반 | `aws_vpc.main` |
| | Internet Gateway | VPC ↔ 인터넷 통신 | `aws_internet_gateway.main` |
| | 퍼블릭 서브넷 (AZ-A, AZ-B) | ALB 배치, 외부 접근 가능 | `aws_subnet.public`, `aws_subnet.public_2` |
| | 프라이빗 서브넷 | EC2·NAT 배치, 직접 외부 접근 차단 | `aws_subnet.private` |
| **로드 밸런싱** | ALB (HTTP/HTTPS) | - 다중 AZ 트래픽 분산 <br/> - 80→443 리다이렉트 <br/> - ACM 인증서 적용 | `aws_lb.main`, `aws_lb_listener.*` |
| **애플리케이션** | EC2 인스턴스 (메인 서버) | - 프라이빗 서브넷에서 앱 실행 <br/> - IMDSv2·EBS 암호화 적용 | `aws_instance.main` |
| **아웃바운드** | NAT 인스턴스 + EIP | - 프라이빗 서브넷의 아웃바운드 인터넷 접근을 위한 NAT 인스턴스 | `aws_instance.nat`, `aws_eip.nat_instance` |
| **관리 접근** | VPC Endpoints (SSM, SSM Messages, EC2 Messages) | 프라이빗 서브넷에서 SSM 세션 매니저 등 AWS 서비스 접근 | `aws_vpc_endpoint.*` |
| **보안** | Security Groups | 리소스별 트래픽 인/아웃바운드 제어 | `security_groups.tf` |

### 트래픽 흐름

1. **인바운드**: 도메인 요청 → Route 53 → IGW → **ALB**(퍼블릭 서브넷) → 프라이빗 서브넷의 **EC2** (타깃 그룹).
2. **아웃바운드**: 프라이빗 서브넷 EC2 → **NAT 인스턴스** → 인터넷.
3. **관리**: EC2 ↔ **VPC 엔드포인트(SSM)** 를 통한 SSM 접근 (퍼블릭 IP 불필요).

### Terraform 파일 구성

| 파일 | 역할 |
|------|------|
| `main.tf` | Provider, 버전 |
| `vpc.tf` | VPC, 서브넷, IGW, 라우트, NAT EIP |
| `alb.tf` | ALB, 타깃 그룹, HTTP/HTTPS 리스너 |
| `ec2.tf` | EC2 (프라이빗, EBS 암호화, IMDSv2) |
| `nat_instance.tf` | NAT 인스턴스 (iptables, 퍼블릭) |
| `security_groups.tf` | 보안 그룹 (ALB, EC2, NAT, 엔드포인트) |
| `vpc_endpoints.tf` | VPC 엔드포인트 (SSM, SSM Messages, EC2 Messages) |
| `variables.tf` | 변수 (리전, CIDR, AMI, ACM, IAM 등) |
| `backend.tf` | Terraform State S3 백엔드 관리 |

### 실행

- **유의사항**: `terraform.tfvars` 파일이 없으면 실행이 불가함.

```bash
cd infrastructure/terraform
terraform init
terraform plan
terraform apply
```

---

## 4. CI/CD

<img width="2356" height="445" alt="Image" src="https://github.com/user-attachments/assets/e7472588-5584-4ca5-8ce5-f2e78c5ab108" />

### CI (GitHub Actions)

- **트리거**: `main` 브랜치 push (경로별)
  - `frontend/**` 또는 워크플로 변경 시 → 프론트엔드 이미지 빌드·푸시
  - `backend/**` 또는 워크플로 변경 시 → 백엔드 이미지 빌드·푸시
- **흐름**: Checkout → AWS 인증 → ECR 로그인 → Docker 빌드·태그(`github.sha`) → ECR 푸시
- **워크플로**: `.github/workflows/frontend-ecr-push.yml`, `.github/workflows/backend-ecr-push.yml`
- **필요 시크릿**: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`

### CD (ArgoCD)

<img width="864" height="474" alt="Image" src="https://github.com/user-attachments/assets/1fb154bb-f7f5-4967-b2c7-ad173b549190" />

- Argo CD로 prod 매니페스트 동기화. 애플리케이션을 `hangeul-chat-frontend`, `hangeul-chat-backend`, `hangeul-chat-infra`(MySQL·Redis·Ingress·batch, 다중 `sources`)로 분리.

---

## 5. 쿠버네티스 구조

<img width="770" height="392" alt="Image" src="https://github.com/user-attachments/assets/ffa1fee6-3893-4968-bf1b-755996ac5a98" />

- EC2 위에 Kubernetes 클러스터 직접 구축. Backend/Frontend는 Deployment로 각 3 replicas 배포해 단일 파드 장애에 대비.
- startupProbe, livenessProbe, readinessProbe로 파드 헬스체크.
- NGINX Ingress Controller로 경로 기반 라우팅.
- 매니페스트는 환경별로 `infrastructure/k8s/dev/`, `infrastructure/k8s/prod/` 아래에 컴포넌트 단위 폴더(`frontend/`, `backend/`, `mysql/`, `redis/`, `ingress/`, `batch/` 등)로 분리. Argo CD는 `infrastructure/k8s/argocd/`의 Application 매니페스트로 프론트·백·인프라를 각각 동기화.

| 구분 | 리소스 | 설명 |
|------|--------|------|
| Deployment | `prod/frontend`, `prod/backend` 등 | 백엔드/프론트엔드 (ReplicaSet → Pod) |
| StatefulSet 등 | `prod/mysql`, `prod/redis` | MariaDB 복제, Redis+Sentinel |
| | nginx-ingress-controller | 인그레스 컨트롤러 |
| Service | backend-service, frontend-service, mysql, redis | 클러스터 내부 서비스 |
| Ingress | hangeul-chat-ingress | 경로 기반 HTTP/HTTPS 라우팅 |
| ConfigMap | nginx-ingress-controller-config | NGINX 인그레스 설정 |

---

## 6. 겪은 문제

### 스레드와 채팅이 많을 때 렌더링 성능 문제 

<img width="818" height="451" alt="Image" src="https://github.com/user-attachments/assets/e9b35925-fffe-48c3-bcad-cf020338ff60" />


**문제**
- 스레드와 채팅이 많을 때 렌더링 성능이 저하되어 초기 데이터 로드, 테마 전환, 언어 전환 시 사용자 경험 저하 발생

**해결**
- 모든 스레드와 채팅을 DOM에 렌더링하여 발생하는 문제로 확인

```js
import React from 'react'
import { useThreadStore } from '@/store/dataStore';
import ListItem from './ListItem';
import { Virtuoso } from 'react-virtuoso';

const SidebarList = () => {
    const { threads } = useThreadStore();

    return (
        <div className="flex-1 min-h-0">
            <Virtuoso
                className='mt-2'
                style={{ height: '100%' }}
                data={threads}
                itemContent={(index, thread) => (
                    <div className="mb-1">
                        <ListItem 
                            key={thread.id} 
                            threadId={thread.id} 
                            fileName={thread.fileName}
                        />
                    </div>
                )}
            />
        </div>
    )
``` 

- react-virtuoso 라이브러리를 활용한 가상스크롤 적용
- 화면에 보이는 영역의 컴포넌트만 렌더링하도록 최적화
- 성능 개선 결과는 아래와 같음 (스레드 200개, 개별 스레드 당 챗이 200개 있는 경우 기준 테스트)

#### 테스트 결과

| 테스트 회차 | 적용 전 | 적용 후 | 개선율 |
|------------|---------|---------|--------|
| 1차 | 4.791200초 | 0.521800초 | 89.1% |
| 2차 | 4.153800초 | 0.717700초 | 82.7% |
| 3차 | 3.243800초 | 0.260400초 | 92.0% |
| 4차 | 5.549000초 | 0.429000초 | 92.3% |
| 5차 | 2.977400초 | 0.140400초 | 95.3% |

#### 성능 개선 요약

| 구분 | 개선 전 | 개선 후 | 개선 효과 |
|------|---------|---------|-----------|
| 평균 로드 시간 | 4.143040초 | 0.413860초 | **90.0% 개선** |
| 최소 로드 시간 | 2.977400초 | 0.140400초 | 95.3% 개선 |
| 최대 로드 시간 | 5.549000초 | 0.717700초 | 87.1% 개선 |

### 라이트 테마에서 스크롤 시 테마 깜빡임 문제

<img width="818" height="451" alt="Image" src="https://github.com/user-attachments/assets/f867bc24-3fe4-475b-912c-13caafaed822" />

**문제**
- react-virtuoso로 가상 스크롤 적용 이후 라이트 테마 상태에서 채팅 영역 스크롤시 새로 렌더링되는 Message 컴포넌트가 잠깐 다크 테마로 표시되었다가 라이트 테마로 전환되는 깜빡임 현상 발생

**해결**
- 모듈 레벨에서 테마를 캐싱, 새 컴포넌트 마운트 시 올바른 테마를 초기값으로 사용하도록 수정

### MySQL 파드 미준비로 인한 백엔드 파드 생성 실패 문제

**문제**
- 쿠버네티스에서 백엔드 파드를 띄울 때 MySQL 파드가 아직 생성되지 않았거나 준비되지 않은 상태에서 백엔드 파드가 시작되면서 간헐적으로 파드 생성이 실패함
- 백엔드 애플리케이션이 시작할 때 MySQL에 연결을 시도하지만 MySQL이 준비되지 않아 연결 실패로 파드 재시작 루프 발생

**해결**
- 백엔드 Deployment에 `initContainers`를 추가하여 MySQL 파드가 준비될 때까지 대기 처리

```yml
      initContainers:
        - name: wait-for-mysql
          image: busybox:1.35
          command: ['sh', '-c']
          args:
            - |
              until nc -z mysql-service 3306; do
                echo "Waiting for MySQL to be ready..."
                sleep 2
              done
              echo "MySQL is ready!"
```

- `initContainers`를 사용하여 MySQL 서비스(`mysql-service:3306`)가 응답할 때까지 주기적으로 헬스체크를 수행
- MySQL이 준비된 후에만 백엔드 컨테이너가 시작되도록 보장하여 파드 생성 실패 문제 해결

### 쿠버네티스 백엔드 파드 생성이 느리게 이뤄지는 문제 

**문제**
- 쿠버네티스 환경에서 백엔드 파드가 Ready 상태가 되기까지 100초 이상의 긴 시간 소요됨
- 개발/테스트 환경에서 배포 후 서비스 가용까지 대기 시간이 길어 생산성 저하

**해결**
- DB 이미지를 MySQL에서 초기화 시간이 더 빠른 MariaDB로 전환하여 대기 시간 10~20초 가량 단축
- `initialDelaySeconds`가 90초로 설정되어 있어 앱이 시작할 준비가 되어도 무조건 90초를 대기해서 낭비가 발생함
  * `initialDelaySeconds`를 제거하고 `startupProbe`로 앱 시작시 헬스 체크를 하도록 하여 불필요한 대기시간 제거

#### 테스트 결과

| 테스트 회차 | 적용 전 | 적용 후 | 개선율 |
|------------|---------|---------|--------|
| 1차 | 147초 | 50초 | 66.0% |
| 2차 | 134초 | 57초 | 57.5% |
| 3차 | 122초 | 39초 | 68.0% |

#### 파드 생성 시간 개선 요약

| 구분 | 개선 전 | 개선 후 | 개선 효과 |
|------|---------|---------|-----------|
| 평균 생성 시간 | 134.3초 | 48.7초 | **63.7% 개선** |
| 최소 생성 시간 | 122초 | 39초 | 68.0% 개선 |
| 최대 생성 시간 | 147초 | 57초 | 61.2% 개선 |

### 파일 업로드 시 요약 API 성능 문제

**문제**
- HWPX/HWP 파일 업로드 시 파일을 AI로 요약하는 `/summarize/stream` API의 성능이 텍스트 10000자 기준으로 (3회 테스트 기준) 평균 5분 29.42초 소요되어 매우 느림

**해결**
- 텍스트가 10000자를 넘어가지 않는 경우는 토큰 비용이 그렇게 크지 않다 판단하여 전체 텍스트를 프롬프트로 전송하도록 처리

```java
@Component
@RequiredArgsConstructor
public class SummarizeFileCache {

    private final StringRedisTemplate redisTemplate;
    private static final String CACHE_KEY_PREFIX = "file:filtered:text:";
    private static final Duration CACHE_TTL = Duration.ofDays(7);

    public String get(String fileHash) {
        return redisTemplate.opsForValue().get(CACHE_KEY_PREFIX + fileHash);
    }

    public void put(String fileHash, String filteredText) {
        redisTemplate.opsForValue().set(CACHE_KEY_PREFIX + fileHash, filteredText, CACHE_TTL);
    }
}
```

- 사용자가 동일한 파일 재업로드하는 경우 대응
  * 파일 해시(SHA-256)를 키로 사용해 필터링 텍스트를 Redis에 캐싱, 동일 파일 재업로드시 중복 필터링 프로세스 건너뛰고 캐싱 결과 반환하도록 처리

- 벡터 기반 유사성 비교에서는 각 `Document` 비교마다 `vectorStore.similaritySearch()` OpenAI Embedding API 를 호출하여 극심한 성능 저하 발생
  * 임베딩 데이터는 문서 데이터 기준으로 한 번에 배치 호출로 생성, `vectorStore.similaritySearch()`를 호출하는 대신 로컬에서 코사인 유사도 계산하도록 변경

## 테스트 결과

| 테스트 회차 | 적용 전 | 적용 후 | 개선율 |
|------------|----------------|----------------|--------|
| 1차 | 327.7초 | 8.9초 | 97.3% |
| 2차 | 346.3초 | 4.9초 | 98.6% |
| 3차 | 314.2초 | 3.8초 | 98.8% |

## 요약 처리 시간 개선 요약

| 구분 | 개선 전 | 개선 후 | 개선 효과 |
|------|---------|---------|-----------|
| 평균 처리 시간 | 329.4초 (5분 29초) | 5.9초 | 98.2% 개선 |
| 최소 처리 시간 | 314.2초 (5분 14초) | 3.8초 | 98.8% 개선 |
| 최대 처리 시간 | 346.3초 (5분 46초) | 8.9초 | 97.3% 개선 |

---

## 8. 아쉬운 점 및 추후 보완점

**테이블, 차트 등 구조화된 데이터 인식 개선 필요**
- 현재 한글 문서(.hwpx) 데이터 추출 시 `hwpxlib`의 `TextExtractor`를 사용 중이나, 테이블과 차트의 구조 정보가 정확히 추출되지 않아 AI가 컨텍스트를 정확히 파악하기 어려운 한계 존재
- 향후 개선 방향:
  - 커스텀 추출 유틸리티 구현을 통해 테이블, 차트 등의 데이터 유형을 명시적으로 태깅
  - 구조화된 메타데이터와 함께 추출하여 AI의 문서 이해도 및 답변 정확도 향상
 
**모바일 반응형 구현 필요**
- 현재 데스크톱 환경에 최적화되어 있어 모바일 기기에서의 사용성이 제한적임. 반응형 웹 디자인 구현 필요함.

**데이터베이스 고가용성 구성 필요**
- 현재 MySQL과 Redis가 Deployment로 구성되어 있고, replicas가 1로 설정되어 단일 장애점이 존재함. 향후 StatefulSet으로 전환하고, replicas를 확장하여 고가용성을 확보할 필요가 있음. 

**EC2 고가용성 구성 필요**
- AutoScaling을 이용해 EC2 인스턴스를 고가용성으로 구성할 필요가 있음. 다만 이를 해결하려면 위의 데이터베이스 고가용성 문제를 먼저 선행하여 해결해야.

**카나리아 배포 도입**
- 향후 Kubernetes 네이티브 방식으로 카나리아 배포를 먼저 도입하고, 이후 Istio를 활용한 가중치 기반 트래픽 분산으로 고도화할 예정.

---
