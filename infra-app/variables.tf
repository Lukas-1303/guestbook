variable "aws_region" {
  description = "AWS Region to deploy resources"
  type        = string
  default     = "ap-northeast-1" # 도쿄 리전으로 기본 설정 (포트폴리오 어필 포인트)
}

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "guestbook-portfolio"
}

variable "domain_name" {
  description = "The root domain name (e.g., example.com)"
  type        = string
  # 이 값은 github에 올리지 않을 terraform.tfvars에서 주입받습니다.
}
