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