# ==============================================================================
# 데이터 소스 (Data Sources) - 외부 리소스 참조
# ==============================================================================
# infra-base 폴더에서 생성 후 SSM 주소록에 적어둔 이름표(ID)들을 불러옵니다.

# 현재 AWS 계정 ID를 가져오기 위한 데이터 소스 (ARN 조합용)
data "aws_caller_identity" "current" {}

data "aws_ssm_parameter" "vpc_id" {
  name = "/${var.project_name}/vpc_id"
}

data "aws_ssm_parameter" "public_subnet_1" {
  name = "/${var.project_name}/public_subnet_1"
}

data "aws_ssm_parameter" "public_subnet_2" {
  name = "/${var.project_name}/public_subnet_2"
}

data "aws_ssm_parameter" "private_subnet_1" {
  name = "/${var.project_name}/private_subnet_1"
}

data "aws_ssm_parameter" "private_subnet_2" {
  name = "/${var.project_name}/private_subnet_2"
}

data "aws_ssm_parameter" "dynamodb_table_name" {
  name = "/${var.project_name}/dynamodb_table_name"
}
