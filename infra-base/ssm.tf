# ==============================================================================
# AWS Systems Manager (SSM) Parameter Store
# ==============================================================================
# infra-app(앱 인프라)이 infra-base(기초 인프라)의 리소스를 참조할 수 있도록
# 생성된 리소스의 ID들을 파라미터 스토어에 "이름표(이정표)"로 등록합니다.

resource "aws_ssm_parameter" "vpc_id" {
  name  = "/${var.project_name}/vpc_id"
  type  = "String"
  value = aws_vpc.main.id
}

resource "aws_ssm_parameter" "public_subnet_1" {
  name  = "/${var.project_name}/public_subnet_1"
  type  = "String"
  value = aws_subnet.public_1.id
}

resource "aws_ssm_parameter" "public_subnet_2" {
  name  = "/${var.project_name}/public_subnet_2"
  type  = "String"
  value = aws_subnet.public_2.id
}

resource "aws_ssm_parameter" "private_subnet_1" {
  name  = "/${var.project_name}/private_subnet_1"
  type  = "String"
  value = aws_subnet.private_1.id
}

resource "aws_ssm_parameter" "private_subnet_2" {
  name  = "/${var.project_name}/private_subnet_2"
  type  = "String"
  value = aws_subnet.private_2.id
}

resource "aws_ssm_parameter" "dynamodb_table_name" {
  name  = "/${var.project_name}/dynamodb_table_name"
  type  = "String"
  value = aws_dynamodb_table.memos.name
}
