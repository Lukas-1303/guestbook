# 1. Route53 Hosted Zone 생성
resource "aws_route53_zone" "main" {
  name = var.domain_name
}

# 2. ACM 인증서 발급 요청
resource "aws_acm_certificate" "main" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# 3. ACM 검증용 DNS 레코드 생성
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id
}

# 4. ACM 인증서 발급 대기 
# (주의: apply 도중 여기서 멈추면, AWS 콘솔의 Route53에 들어가서 생성된 4개의 NS 레코드 주소를 가비아 홈페이지에 입력해야 합니다!)
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
