# ==============================================================================
# AWS Network Infrastructure (VPC & Subnets) - 영구 보존 리소스
# ==============================================================================
# 이 파일은 전체 아키텍처의 뼈대가 되는 네트워크(VPC, Subnet, IGW)를 정의합니다.
# 이곳에 정의된 리소스들은 과금이 발생하지 않으며, infra-base에서 영구적으로 관리됩니다.

# 1. VPC (Virtual Private Cloud)
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# ==============================================================================
# 서브넷 (Subnets)
# ==============================================================================

# 2-1. Public Subnet 1 (AZ: a)
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-1a"
  }
}

# 2-2. Public Subnet 2 (AZ: c)
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}c"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-2c"
  }
}

# 2-3. Private Subnet 1 (AZ: a)
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${var.project_name}-private-1a"
  }
}

# 2-4. Private Subnet 2 (AZ: c)
resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "${var.aws_region}c"

  tags = {
    Name = "${var.project_name}-private-2c"
  }
}

# ==============================================================================
# 게이트웨이 (Gateways) - 인터넷과의 연결 통로
# ==============================================================================

# 3. Internet Gateway (IGW) - 과금 없음
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# ==============================================================================
# 퍼블릭 라우팅 테이블 (Route Tables)
# ==============================================================================

# 4-1. Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# 4-2. Public Route Table Associations
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}
