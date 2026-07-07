# ==============================================================================
# 유료 네트워크 리소스 (NAT Gateway & Private Routing)
# ==============================================================================
# 이 파일은 과금이 발생하는 NAT Gateway와 이에 의존하는 프라이빗 라우팅 테이블을 정의합니다.
# infra-app 철거 시 함께 삭제되어 과금을 방지합니다.

# 1. Elastic IP (EIP) for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

# 2. NAT Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = data.aws_ssm_parameter.public_subnet_1.value
  
  tags = {
    Name = "${var.project_name}-nat"
  }
}

# 3. Private Route Table
resource "aws_route_table" "private" {
  vpc_id = data.aws_ssm_parameter.vpc_id.value
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# 4. Private Route Table Associations
resource "aws_route_table_association" "private_1" {
  subnet_id      = data.aws_ssm_parameter.private_subnet_1.value
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "private_2" {
  subnet_id      = data.aws_ssm_parameter.private_subnet_2.value
  route_table_id = aws_route_table.private.id
}
