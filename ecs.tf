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
s
    # Fargateで動かす
    requires_copatibilities = ["FARGATE"]

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
            port_Mappings = [
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
                }
            ]

            secrets = [
                {
                    name = "DB_CREDENTIALS"
                    valueFrom = aws_secretsmanager_secret.db_credentials.arn
                }
            ]
        }
    ])
}