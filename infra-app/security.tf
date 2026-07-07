# ==============================================================================
# AWS Security Groups (방화벽) - Least Privilege (최소 권한의 원칙) 적용
# ==============================================================================
# 3-Tier 아키텍처의 핵심인 '보안 그룹 체이닝(Security Group Chaining)'을 구현합니다.
# 외부 인터넷 -> ALB -> Web -> WAS 순으로만 통신이 가능하도록 소스(Source)를 제한합니다.

# ------------------------------------------------------------------------------
# 1. ALB (Application Load Balancer) 보안 그룹
# ------------------------------------------------------------------------------
# 인터넷에서 들어오는 사용자의 트래픽(HTTP/HTTPS)을 가장 먼저 맞이하는 방패입니다.
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security Group for Public ALB"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value

  # HTTP (80) 인바운드 허용: 외부 모든 IP에서 접속 가능하도록 열어둡니다. (나중에 HTTPS 리다이렉트용)
  ingress {
    description = "Allow HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS (443) 인바운드 허용: 안전한 암호화 통신을 위해 열어둡니다.
  ingress {
    description = "Allow HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 아웃바운드 허용: ALB가 Web 서버로 트래픽을 넘겨야 하므로 모든 방향으로 길을 열어줍니다.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# ------------------------------------------------------------------------------
# 2. Web 서버 (Nginx) 보안 그룹
# ------------------------------------------------------------------------------
# Private Subnet에 위치하며, 오직 ALB를 통해서 들어온 트래픽만 허용합니다.
resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "Security Group for Web (Nginx) Servers"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value

  # HTTP (80) 인바운드 허용: Source를 '0.0.0.0/0'이 아닌 'ALB 보안 그룹'으로 지정합니다. (체이닝)
  ingress {
    description     = "Allow HTTP ONLY from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-web-sg"
  }
}

# ------------------------------------------------------------------------------
# 3. WAS 서버 (Node.js) 보안 그룹
# ------------------------------------------------------------------------------
# 가장 깊숙한 곳에 위치하며, 오직 Web 서버가 던져주는 API 트래픽만 허용합니다.
resource "aws_security_group" "was" {
  name        = "${var.project_name}-was-sg"
  description = "Security Group for WAS (Node.js) Servers"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value

  # Custom TCP (8080) 인바운드 허용: Source를 'Web 보안 그룹'으로 지정합니다. (체이닝)
  ingress {
    description     = "Allow 8080 ONLY from Web Servers"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-was-sg"
  }
}

# ==============================================================================
# AWS WAF (Web Application Firewall) - ALB용 웹 방화벽
# ==============================================================================
# 해킹 공격(SQL Injection 등)과 악성 봇을 차단하는 기본 WAF 룰셋을 세팅합니다.

resource "aws_wafv2_web_acl" "main" {
  name        = "${var.project_name}-waf"
  description = "WAF for ALB to block malicious traffic"
  scope       = "REGIONAL" # ALB에 붙이기 때문에 REGIONAL 사용 (CloudFront는 CLOUDFRONT 사용)

  default_action {
    allow {} # 기본적으로 모든 트래픽을 허용하되, 아래 규칙에 걸리면 차단함
  }

  # AWS 관리형 기본 규칙 1: 일반적인 웹 공격(SQLi, XSS 등) 차단
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # AWS 관리형 기본 규칙 2: 알려진 악성 IP 차단
  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesAmazonIpReputationListMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf-metric"
    sampled_requests_enabled   = true
  }
}
