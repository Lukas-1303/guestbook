variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Project Name"
  type        = string
  default     = "guestbook"
}

variable "domain_name" {
  description = "The domain name (e.g., example.com)"
  type        = string
}
