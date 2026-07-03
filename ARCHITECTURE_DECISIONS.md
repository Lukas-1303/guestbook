# Architecture Decision Records (ADR)

본 프로젝트를 진행하며 결정한 주요 인프라 아키텍처 및 CI/CD 파이프라인 설계의 의사결정 기록입니다.

## 1. 인프라 상태(State)의 분리 설계
* **Context:** 개인 프로젝트 환경의 특성상 비용 최적화를 위해 매일 컴퓨팅 리소스를 생성 및 제거(`terraform apply/destroy`)해야 하는 요구사항이 존재함.
* **Problem:** ECS 클러스터를 파괴할 때 컨테이너 이미지가 저장된 ECR 레포지토리까지 함께 삭제되면, 다음 생성 시 배포 파이프라인(CI/CD)을 처음부터 다시 구동해야 하는 의존성 문제가 발생.
* **Decision:** 인프라 자원을 수명(Lifecycle)에 따라 두 그룹으로 분리 관리함.
  * **Persistent Resources (수동 관리):** 과금이 거의 발생하지 않는 자원(Route53, ACM, IAM, ECR, S3 Backend)은 Terraform 코드에서 제외하고 수동으로 영구 보존.
  * **Ephemeral Resources (Terraform 관리):** 과금이 발생하는 컴퓨팅 자원(VPC, ALB, ECS, DynamoDB)만 Terraform에 포함시켜 일일 단위로 생성 및 파괴.

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
