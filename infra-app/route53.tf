# ==============================================================================
# Route 53 (도메인) 및 ACM (HTTPS 인증서) - [수동 생성된 리소스 가져오기]
# ==============================================================================
# 주의: 매일 destroy/apply를 반복하면 네임서버(NS)가 매일 바뀌어 가비아 연동이 끊어집니다.
# 따라서 Hosted Zone과 ACM 인증서는 AWS 콘솔에서 '영구적으로' 1회 수동 생성해 두어야 합니다.

# 1. 이미 존재하는 Hosted Zone 정보 가져오기 (Data Source)
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# 2. 이미 발급받은 ACM 인증서 정보 가져오기 (Data Source)
data "aws_acm_certificate" "main" {
  domain   = var.domain_name
  statuses = ["ISSUED"]
}

# 3. 도메인(A 레코드)과 매일 새로 생기는 ALB 연결
# ALB는 매일 새로 생기지만, 도메인 이름은 고정이므로 A 레코드만 동적으로 갈아끼워줍니다.
resource "aws_route53_record" "alb" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
