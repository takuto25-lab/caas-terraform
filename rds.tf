# DBのSubnet Groupを作成
resource "aws_db_subnet_group" "main"{
  name = "${var.project_name}-db-subnet-group"

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_c.id
  ]

  tags = {
    Name = "${var.project_name}aws_db_subnet_group"
  }
}

# RDS作成
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-db"

  engine = "mysql"
  engine_version = "8.0"

  instance_class = "db.t4g.micro"

  # 20GBの確保とストレージの種類
  allocated_storage = 20
  storage_type = "gp3"

  db_name = "sample"
  username = "admin"
  password = "Password123!"

  db_subnet_group_name = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible = false
  multi_az = false

  # バックアップ設定(今はなし)
  backup_retention_period = 0

  skip_final_snapshot = true
  
  tags = {
    Name = "${var.project_name}_rds"
  }
}

# Secrets Manager作成
resource "aws_secretsmanager_secret" "db_credentials" {
  name = "${var.project_name}-db--db_credentials"

  tags = {
    Name = "${var.project_name}_db_secret"
  }
}

# Secretの値を登録
resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    DB_USER = "admin"
    DB_PASSWORD = "Password123!"
  })
}
   