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

# TaskRole作成
resource "aws_iam_role" "ecs_task_role"{
  name = "${var.project_name}_ecs_task_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "ecs_secret_policy" {
  name = "${var.project_name}-ecs-secret-policy"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "secretsmanager:GetSecretValue"
        ]

        Resource = aws_secretsmanager_secret.db_credentials.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_secret_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_secret_policy.arn
}

resource "aws_iam_role_policy" "ecs_exec" {
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}