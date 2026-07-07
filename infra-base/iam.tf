# ==============================================================================
# GitHub Actions용 IAM User (파이프라인별 권한 분리 - 최소 권한의 원칙)
# ==============================================================================

# 1. GitHub Actions용 IAM User
resource "aws_iam_user" "github_actions" {
  name = "${var.project_name}-github-actions"
}

# 2. ECR Push 및 ECS Deploy 권한 부여 (기존 앱 배포용)
resource "aws_iam_user_policy_attachment" "ecr_power_user" {
  user       = aws_iam_user.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_user_policy_attachment" "ecs_full_access" {
  user       = aws_iam_user.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
}

