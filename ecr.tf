# ECS Repository作成
resource "aws_ecr_repository" "main" {
  name = "${var.project_name}-repository"

  #　タグの上書きを許可
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name ="${var.project_name}_ecr"
  }
}