# AWS ECS Fargate 3-Tier Serverless Architecture

본 프로젝트는 AWS 클라우드 환경에서 ECS Fargate와 DynamoDB를 활용하여 구축된 3-Tier 서버리스 아키텍처입니다. 
인프라는 Terraform을 통해 코드로 관리(IaC)되며, 애플리케이션 배포는 GitHub Actions를 통해 자동화(CI/CD)되어 있습니다.

## 아키텍처 흐름
사용자 -> [Route 53] -> [ALB + WAF] -> [Web (Nginx)] -> [WAS (Node.js)] -> [DynamoDB]

1. **Security:** AWS WAF를 통한 악성 트래픽 차단 및 ALB -> Web -> WAS로 이어지는 Security Group Chaining 적용.
2. **Compute:** 관리 오버헤드를 줄이기 위해 서버리스 컨테이너인 ECS Fargate 사용.
3. **Database:** RDBMS(MySQL) 대신 서버리스 NoSQL인 DynamoDB(On-Demand)를 사용하여 유지 비용 최적화.

## 기술 스택
- **Infrastructure as Code:** Terraform (v5.0+)
- **CI/CD Pipeline:** GitHub Actions
- **Containerization:** Docker, Amazon ECR, Amazon ECS (Fargate)
- **Backend / Frontend:** Node.js, Nginx
- **Database:** Amazon DynamoDB

## 배포 파이프라인 (CI/CD)
GitHub Repository의 `app/` 디렉토리에 변경 사항이 발생하여 `main` 브랜치에 푸시되면 다음 작업이 자동 수행됩니다:
1. 최신 코드로 Docker Image 빌드 (Web, WAS)
2. Amazon ECR에 새로운 태그(Git SHA)와 함께 Push
3. Amazon ECS 서비스에 롤링 배포 (Force New Deployment)

## 로컬 실행 방법 (Terraform)
1. `infra/terraform.tfvars.example` 파일을 복사하여 `terraform.tfvars`를 생성하고 도메인 주소 입력.
2. AWS Route53 Hosted Zone 및 ACM 인증서 수동 생성 및 확인.
3. 테라폼 프로비저닝 실행:
   ```bash
   cd infra
   terraform init
   terraform apply
   ```
4. 인프라 정리:
   ```bash
   terraform destroy
   ```
