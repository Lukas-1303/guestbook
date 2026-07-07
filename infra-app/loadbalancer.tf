# ==============================================================================
# Application Load Balancer (ALB) 및 Target Group
# ==============================================================================
# 사용자의 트래픽을 가장 먼저 받아 Nginx(Web) 컨테이너들로 고르게 분산해줍니다.

# 1. ALB (로드밸런서) 본체 생성
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [
    data.aws_ssm_parameter.public_subnet_1.value,
    data.aws_ssm_parameter.public_subnet_2.value
  ]

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# 2. Target Group (타겟 그룹)
resource "aws_lb_target_group" "web" {
  name        = "${var.project_name}-web-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value
  target_type = "ip" # 매우 중요: Fargate 전용 설정

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 10
    path                = "/" 
    matcher             = "200"
  }
}

# 3. HTTP Listener (80포트 접속 시 HTTPS로 강제 리다이렉트)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# 4. HTTPS Listener (443포트 접속 시 Web TG로 트래픽 전달)
# 수동으로 발급받은 ACM 인증서 정보를 불러와서(Data Source) 연결합니다.
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = data.aws_acm_certificate.main.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
