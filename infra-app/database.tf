# ==============================================================================
# AWS DynamoDB (서버리스 NoSQL 데이터베이스)
# ==============================================================================
# 방명록 데이터를 저장할 완전 관리형 데이터베이스입니다.
# EC2나 RDS처럼 켜져있는 시간에 비례해 요금이 부과되지 않고, 
# '요청한 만큼만' 과금되는 On-Demand 방식을 사용하여 유지보수와 비용을 극단적으로 낮춥니다.

resource "aws_dynamodb_table" "memos" {
  name         = "${var.project_name}-memos"
  billing_mode = "PAY_PER_REQUEST" # 온디맨드 과금 (요청이 없으면 0원!)
  hash_key     = "id"              # 파티션 키 (기본 식별자)

  attribute {
    name = "id"
    type = "S" # String 타입 (UUID를 저장할 예정)
  }

  tags = {
    Name = "${var.project_name}-dynamodb"
  }
}
