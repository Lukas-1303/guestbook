# ==============================================================================
# ECS Task Definition & Service (Web / WAS)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. WAS (Node.js) Task Definition & Service
# ------------------------------------------------------------------------------
resource "aws_ecs_task_definition" "was" {
  family                   = "${var.project_name}-was-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256 # 0.25 vCPU
  memory                   = 512 # 0.5 GB

  # Fargate가 AWS 리소스(CloudWatch 등)에 접근하기 위한 역할
  execution_role_arn = aws_iam_role.ecs_execution_role.arn
  # WAS 앱(DynamoDB SDK)이 DynamoDB에 접근하기 위한 역할
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "was-container"
      image     = "${data.aws_ecr_repository.was.repository_url}:latest" # 초기엔 latest, 이후 깃액션이 해시로 변경
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "TABLE_NAME"
          value = aws_dynamodb_table.memos.name
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.project_name}-was"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "was" {
  name            = "${var.project_name}-was-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.was.arn
  desired_count   = 2 # 고가용성을 위해 2대 유지
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_groups  = [aws_security_group.was.id]
    assign_public_ip = false
  }

  # Service Discovery (Cloud Map) 연결
  service_registries {
    registry_arn = aws_service_discovery_service.was.arn
  }
}

# WAS용 Cloud Map 서비스 레코드 (was.local)
resource "aws_service_discovery_service" "was" {
  name = "was"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.internal.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE" # 라운드 로빈 로드밸런싱
  }
  health_check_custom_config {
    failure_threshold = 1
  }
}

# ------------------------------------------------------------------------------
# 2. Web (Nginx) Task Definition & Service
# ------------------------------------------------------------------------------
resource "aws_ecs_task_definition" "web" {
  family                   = "${var.project_name}-web-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512

  execution_role_arn = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "web-container"
      image     = "${data.aws_ecr_repository.web.repository_url}:latest"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.project_name}-web"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "web" {
  name            = "${var.project_name}-web-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.web.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_groups  = [aws_security_group.web.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.web.arn
    container_name   = "web-container"
    container_port   = 80
  }
}

# ------------------------------------------------------------------------------
# 3. ECS 실행 및 태스크 역할 (IAM Roles)
# ------------------------------------------------------------------------------
# Fargate가 컨테이너를 띄우고 로그를 남길 수 있는 기본 역할 (Execution Role)
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.project_name}-ecs-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 컨테이너 안의 앱(Node.js)이 AWS 리소스(DynamoDB)를 만질 수 있는 역할 (Task Role)
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

# WAS 컨테이너에게 DynamoDB 접근 권한 부여
resource "aws_iam_role_policy" "dynamodb_access" {
  name   = "${var.project_name}-dynamodb-access"
  role   = aws_iam_role.ecs_task_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:Scan",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem"
      ]
      Effect   = "Allow"
      Resource = aws_dynamodb_table.memos.arn
    }]
  })
}

# CloudWatch 로그 그룹 생성
resource "aws_cloudwatch_log_group" "was_logs" {
  name              = "/ecs/${var.project_name}-was"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "web_logs" {
  name              = "/ecs/${var.project_name}-web"
  retention_in_days = 7
}
