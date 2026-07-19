# ALBを作成
resource "aws_lb" "main" {
  name = "${var.project_name}-alb"
  load_balancer_type = "application"

  # インターネット公開を許可する
  internal = false

  security_groups = [
    aws_security_group.alb.id
  ]

  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_c.id
  ]

  tags = {
    Name = "${var.project_name}_alb"
  }
}

# Target Groupを作成
resource "aws_lb_target_group" "main" {
  name = "${var.project_name}-tg"

  port = 3001
  protocol = "HTTP"
  vpc_id = aws_vpc.main.id

  # FargateはENIを持つからIPを指定
  target_type = "ip"

  health_check {
    path = "/login"
    protocol = "HTTP"
    # 200なら正常
    matcher = "200"
    # ヘルスチェックの間隔
    interval = 30
    # 何秒返ってこなかったら失敗扱いとするか
    timeout = 5
    # 何回連続成功・失敗でHealthy・Unhealthy
    healthy_threshold = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project_name}_tg"
  }
}

# HTTP Listenerを作成
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn

  port = 80
  protocol = "HTTP"

  # リクエストの転送について
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}