# 1. Web (Nginx) 이미지 저장소
resource "aws_ecr_repository" "web" {
  name                 = "${var.project_name}-web-repo"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # 테라폼 destroy 시 이미지가 들어있어도 강제 삭제 허용
}

# 2. WAS (Node.js) 이미지 저장소
resource "aws_ecr_repository" "was" {
  name                 = "${var.project_name}-was-repo"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}
