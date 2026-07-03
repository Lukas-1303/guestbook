# ==============================================================================
# AWS Network Infrastructure (VPC)
# ==============================================================================
# 이 파일은 3-Tier 아키텍처의 뼈대가 되는 네트워크(VPC, Subnet, Routing)를 정의합니다.
# 보안을 위해 Public/Private 망을 분리하고, 비용 최적화를 위해 단일 NAT GW를 사용합니다.

# 1. VPC (Virtual Private Cloud) 생성
# 모든 인프라 리소스가 격리되어 실행될 거대한 가상 네트워크 공간입니다.
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true # ECS Service Discovery(Cloud Map)를 위해 필수
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# ==============================================================================
# 서브넷 (Subnets) - 고가용성을 위해 2개의 가용 영역(AZ)에 분산 배치
# ==============================================================================

# 2-1. Public Subnet 1 (AZ: a)
# 사용자의 트래픽을 최초로 맞이하는 ALB(로드밸런서)와 NAT GW가 위치할 퍼블릭 공간입니다.
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true # 퍼블릭 IP 자동 할당

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
# 외부 인터넷에서 직접 접근할 수 없는 안전한 공간. ECS(Web, WAS) 컨테이너가 띄워집니다.
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

# 3. Internet Gateway (IGW)
# VPC 내부의 Public Subnet 리소스들이 인터넷과 통신할 수 있게 해주는 대문입니다.
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# 4. Elastic IP (EIP) for NAT Gateway
# NAT Gateway가 사용할 고정 퍼블릭 IP 주소를 할당받습니다.
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

# 5. NAT Gateway
# Private Subnet의 리소스(ECS 컨테이너 등)가 외부(ECR, 외부 API)로 나갈 때 사용하는 통로입니다.
# 비용 최적화(FinOps)를 위해 AZ 하나(public_1)에 단일 NAT GW만 배치합니다.
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "${var.project_name}-nat"
  }
  depends_on = [aws_internet_gateway.igw]
}

# ==============================================================================
# 라우팅 테이블 (Route Tables) - 트래픽 이정표 설정
# ==============================================================================

# 6-1. Public Route Table
# Public Subnet의 트래픽이 인터넷(0.0.0.0/0)으로 가려면 IGW를 타도록 안내합니다.
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

# 6-2. Private Route Table
# Private Subnet의 트래픽이 인터넷(0.0.0.0/0)으로 가려면 NAT GW를 타도록 안내합니다.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# ==============================================================================
# 라우팅 테이블 연결 (Route Table Associations)
# ==============================================================================

# Public Subnet들을 Public Route Table에 연결
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Private Subnet들을 Private Route Table에 연결
resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}
