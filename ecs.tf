resource "aws_ecs_cluster" "main"{
    name = "${var.project_name}-cluster"

    tags = {
        Name = "${var.project_name}_cluster"
    }
}

resource "aws_cloudwatch_log_group" "ecs"{
    name = "/ecs/${var.project_name}"

    # 保存期間
    retention_in_days = 7

    tags = {
        Name = "${var.project_name}_ecs_logs"
    }
}

resource "aws_ecs_task_definition" "main" {
    family = "${var.project_name}-task"
    
    # TaskごとにIPアドレスとSGを持たせる(Fargateで動かすなら必須)
    network_mode = "awsvpc"

    # Fargateで動かす
    requires_compatibilities = ["FARGATE"]

    cpu = 256
    memory = 512

    execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
    task_role_arn = aws_iam_role.ecs_task_role.arn

    container_definitions = jsonencode([
        {
            name = "app"
            image = "${aws_ecr_repository.main.repository_url}:latest"

            # コンテナが止まったらtaskも止まる
            essential = true
            portMappings = [
                {
                    containerPort = 3001
                    hostPort = 3001
                    protocol = "tcp"
                }
            ]

            logConfiguration = {
                # logの送り先
                logDriver = "awslogs"

                options = {
                    awslogs-group = aws_cloudwatch_log_group.ecs.name
                    awslogs-region = "ap-northeast-1"
                    # ログストリーム名
                    awslogs-stream-prefix = "ecs"
                }
            }

            # 環境変数
            environment = [
                {
                    name = "NODE_ENV"
                    value = "production"
                },
                {
                    name = "PORT"
                    value = "3001"
                },
                {
                    name  = "DB_HOST"
                    value = aws_db_instance.main.address
                },
                {
                    name  = "DB_NAME"
                    value = "sample"
                },
                {
                    name  = "DB_PORT"
                    value = "3306"
                }                
            ]

            secrets = [
                {
                    name      = "DB_USER"
                    valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:DB_USER::"
                },
                {
                    name      = "DB_PASSWORD"
                    valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:DB_PASSWORD::"
                }
            ]
        }
    ])
}

# ECS Service
resource "aws_ecs_service" "main" {
  name    = "${var.project_name}-service"
  cluster = aws_ecs_cluster.main.id

  enable_execute_command = true
  # 起動するTask Definition
  task_definition = aws_ecs_task_definition.main.arn

  # 起動数
  desired_count = 1

  # Fargateを使用
  launch_type = "FARGATE"

  # ALBとの紐付け
  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "app"
    container_port   = 3001
  }

  # ネットワーク設定
  network_configuration {
    subnets = [
      aws_subnet.private_a.id,
      aws_subnet.private_c.id
    ]

    security_groups = [
      aws_security_group.ecs.id
    ]

    assign_public_ip = false
  }

  depends_on = [
    aws_lb_listener.http
  ]
}