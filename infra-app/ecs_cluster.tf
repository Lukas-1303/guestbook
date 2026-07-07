# ==============================================================================
# ECS Cluster & ECR & Service Discovery (Cloud Map)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. ECR (Elastic Container Registry) - [수동 생성된 리소스 가져오기]
# ------------------------------------------------------------------------------
# 주의: 매일 destroy를 하더라도 도커 이미지가 날아가면 안 되므로, 
# ECR 창고는 AWS 콘솔에서 수동으로 영구 생성해 두고(비용 거의 0원) Data Source로 불러옵니다.

data "aws_ecr_repository" "web" {
  name = "${var.project_name}-web-repo"
}

data "aws_ecr_repository" "was" {
  name = "${var.project_name}-was-repo"
}

# ------------------------------------------------------------------------------
# 2. ECS Cluster (컨테이너 오케스트레이션 클러스터)
# ------------------------------------------------------------------------------
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled" # 컨테이너 상태 모니터링 활성화
  }

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

# ------------------------------------------------------------------------------
# 3. AWS Cloud Map (Service Discovery) - 내부 도메인 서비스
# ------------------------------------------------------------------------------
resource "aws_service_discovery_private_dns_namespace" "internal" {
  name        = "local" 
  description = "Private DNS namespace for internal ECS service discovery"
  vpc         = data.aws_ssm_parameter.vpc_id.value

  tags = {
    Name = "${var.project_name}-cloudmap"
  }
}
