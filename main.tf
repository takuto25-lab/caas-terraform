# vpc用の設定
# mainはterraform内で使う名前
resource "aws_vpc" "main" {
  # アドレス空間を指定
  cidr_block = "10.0.0.0/16"

  # DNS解決を有効化
  enable_dns_support = true

  # VPC内のリソースにDNS名を付与できる
  enable_dns_hostnames = true

  tags = {
    # variables.tfから参照
    Name = "${var.project_name}_vpc"
  }
}


# subnet
resource "aws_subnet" "public_a" {
  # どこのVPCに入るか指定
  vpc_id = aws_vpc.main.id

  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-northeast-1a"

  tags = {
    Name = "${var.project_name}_subnet_public_a"
  }
}

resource "aws_subnet" "public_c" {
  # どこのVPCに入るか指定
  vpc_id = aws_vpc.main.id

  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-northeast-1c"

  tags = {
    Name = "${var.project_name}_subnet_public_c"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-northeast-1a"

  tags = {
    Name = "${var.project_name}_private_public_a"
  }
}

resource "aws_subnet" "private_c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "ap-northeast-1c"

  tags = {
    Name = "${var.project_name}_private_public_c"
  }
}


# IGW作成
resource "aws_internet_gateway" "main"{
  vpc_id = aws_vpc.main.id

  tags ={
    Name = "${var.project_name}_igw"
  }
}


# Public Route Table
resource "aws_route_table" "public"{
  vpc_id = aws_vpc.main.id

  #ルートの設定
  route{
    #0.0.0.0/0宛の通信をIGWに送る
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "${var.project_name}_public_rt"
  }
}


# PublicRouteTableをPublicSubnetと紐付ける
resource "aws_route_table_association" "public_a"{
  subnet_id = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public_c"{
  subnet_id = aws_subnet.public_c.id
  route_table_id = aws_route_table.public.id
}


# NAT Gateway用のElasticIP作成
resource "aws_eip" "nat_a"{
  domain ="vpc"

  tags = {
    Name = "${var.project_name}_nat_a_eip"
  }
}

resource "aws_eip" "nat_c"{
  domain ="vpc"

  tags = {
    Name = "${var.project_name}_nat_c_eip"
  }
}


# NAT GW作成
resource "aws_nat_gateway" "nat_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id = aws_subnet.public_a.id

  tags = {
    Name = "${var.project_name}_nat_a"
  }
}

resource "aws_nat_gateway" "nat_c" {
  allocation_id = aws_eip.nat_c.id
  subnet_id = aws_subnet.public_c.id

  tags = {
    Name = "${var.project_name}_nat_c"
  }
}

# Private Route Table
resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_a.id
  }

  tags = {
    Name = "${var.project_name}_private_a_rt"
  }
}
resource "aws_route_table" "private_c" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_c.id
  }

  tags = {
    Name = "${var.project_name}_private_c_rt"
  }
}


# PrivateRouteTableをPrivateSubnetと紐付ける
resource "aws_route_table_association" "private_a" {
  subnet_id = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table_association" "private_c" {
  subnet_id = aws_subnet.private_c.id
  route_table_id = aws_route_table.private_c.id
}


# SG作成
# ALB用
resource "aws_security_group" "alb" {
  name = "${var.project_name}_alb_sg"
  description = "Security group for ALB"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "Allow HTTP from Internet"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS from Internet"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}_alb_sg"
  }

}

# ECS用
resource "aws_security_group" "ecs" {
  name = "${var.project_name}_ecs_sg"
  description = "Security group for ECS tasks"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "Allow app traffic from ALB"
    from_port = 3001
    to_port = 3001
    protocol = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}_ecs_sg"
  }
}

# RDS用
resource "aws_security_group" "rds" { 
  name = "${var.project_name}_rds_sg"
  description = "Security group for RDS"
  vpc_id = aws_vpc.main.id

  ingress { 
    description = "Allow MySQL from ECS"
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  tags = {
    Name ="${var.project_name}_rds_sg"
  }
}

# ECS Task Execution Role作成
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}_ecs_task_exection_role"

  # 使えるロール
  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          # ECS Taskだけ
          Service = "ecs-tasks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Execution Roleへポリシー付与
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}