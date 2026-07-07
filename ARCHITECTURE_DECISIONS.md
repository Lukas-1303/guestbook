# Architecture Decision Records (ADR)

본 프로젝트를 진행하며 결정한 주요 인프라 아키텍처 및 CI/CD 파이프라인 설계의 의사결정 기록입니다.

## 1. 비용 최적화(FinOps)를 위한 Terraform State 디커플링
* **Context:** 주말이나 야간 등 유휴 시간에 서버를 종료하여 클라우드 과금을 방지(`terraform destroy`)해야 하는 강한 비용 최적화 요구사항이 존재함.
* **Problem:** 하나의 Terraform State에서 인프라를 전체 관리할 경우, 서버(ECS)를 내릴 때마다 영구 보존되어야 할 데이터베이스(DynamoDB)의 데이터까지 함께 날아가는 데이터 유실 문제가 발생.
* **Decision:** 인프라 자원을 과금 여부와 수명주기에 따라 두 개의 독립된 상태(`infra-base`, `infra-app`)로 완벽하게 분리하고, SSM Parameter Store를 통해 의존성을 연결함.
  * **`infra-base` (비과금 및 영구 보존 구역):** 과금이 없는 기본 네트워크(VPC, Subnet, IGW)와 영구 보존해야 할 데이터베이스(DynamoDB)를 배치하여 절대 삭제되지 않도록 보호.
  * **`infra-app` (과금 및 유동적 컴퓨팅 구역):** 시간당 과금이 발생하는 고비용 자원(NAT Gateway, ALB, ECS Fargate)만 배치하여, 원할 때 언제든 독립적으로 파괴 및 재생성이 가능하도록 비용 방어 아키텍처 구현.
  * **Data Bridge (SSM Parameter Store):** 두 인프라 간의 리소스 ID(VPC ID 등)를 하드코딩하지 않고, SSM Parameter Store의 Export/Import 기능을 사용하여 느슨한 결합(Loose Coupling)을 완성함.

## 2. CI/CD 이중 태깅 (Dual Tagging) 전략
* **Context:** ECR에 도커 이미지를 푸시할 때 버전 관리가 필요함.
* **Problem:** `latest` 태그만 사용할 경우 이전 버전 추적 및 롤백이 불가능하며, 고유한 Git SHA 태그만 사용할 경우 ECS Task Definition의 이미지 태그를 매번 갱신해 주어야 하는 자동화의 어려움이 존재함.
* **Decision:** GitHub Actions 파이프라인에서 이미지 빌드 시 두 가지 태그를 동시에 부여.
  * `Git SHA`: 버전 추적, 롤백, 무결성 보장을 위한 고유 식별자.
  * `latest`: ECS가 테라폼 코드 변경 없이 항상 최신 이미지를 참조하도록 돕는 유동적 식별자.

## 3. 파이프라인의 물리적 분리 (Infra vs App)
* **Context:** 일반적인 팀 프로젝트 환경에서는 인프라와 애플리케이션 파이프라인을 모두 중앙 CI/CD 시스템(Jenkins 등)에서 자동화함.
* **Problem:** 인프라 제어권을 CI/CD에 위임할 경우, 개인 프로젝트 환경에서 원하는 시점에 즉각적으로 인프라를 껐다 켜기(비용 관리) 번거로움.
* **Decision:** 애플리케이션 배포 파이프라인은 GitHub Actions로 자동화하되, 인프라의 생성 및 파괴(`terraform apply/destroy`)는 로컬 환경의 터미널에 수동으로 남겨두어 인프라 제어의 주도권을 직접 확보.

## 4. 네트워크 및 보안 아키텍처
* **Bastion Host 생략:** Bastion EC2 운영에 따른 비용 및 보안 유지보수 오버헤드를 제거하기 위해, AWS Systems Manager(SSM) 기반의 ECS Exec 기능을 사용하여 컨테이너에 직접 접근.
* **단일 NAT Gateway:** 멀티 AZ를 구성하였으나, 개인 테스트 환경의 NAT Gateway 비용 최적화를 위해 Public Subnet-1에 단일 NAT Gateway를 배치하여 사용.
* **Service Discovery (Cloud Map):** 프론트엔드(Nginx)가 동적 IP 환경의 백엔드(Node.js)를 안정적으로 호출할 수 있도록 AWS Cloud Map을 활용하여 내부 도메인(`was.local`) 기반의 서비스 디스커버리 구현.

## 5. Nginx 리버스 프록시 트러블슈팅 (무중단 배포 타임아웃 해결)
* **Context:** GitHub Actions를 통해 WAS(Node.js) 컨테이너가 롤링 업데이트될 때, 일시적으로 프론트엔드(Nginx)에서 504 Gateway Timeout 에러가 간헐적으로 발생하는 이슈를 발견함.
* **Problem:** Nginx의 `proxy_pass`에 백엔드 주소(`was.local`)를 정적으로 할당할 경우, Nginx가 최초 기동 시점에만 IP를 DNS 리졸빙하여 캐싱하는 고질적인 문제가 있음. 이로 인해 WAS 컨테이너 교체로 새 IP가 할당되어도, Nginx는 캐싱된 죽은 IP로 트래픽을 계속 전송하여 타임아웃 에러를 유발함.
* **Decision:** `nginx.conf`에서 백엔드 주소를 변수(`set $backend`)로 할당하고, AWS VPC 기본 DNS 리졸버 주소(`10.0.0.2`)를 명시하여 10초 주기(`valid=10s`)로 동적 DNS 리졸빙을 수행하도록 강제함으로써 무중단 배포 시 타임아웃 에러를 완벽히 해결함.
