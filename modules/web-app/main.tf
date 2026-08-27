# ============================================================================
# MODULE WEB-APP — ALB (publik) + ECS Fargate (privat)
# Internet -> ALB -> ECS task (container) di subnet privat
# ============================================================================

locals {
  name = "${var.project}-${var.environment}-web"
}

data "aws_region" "current" {}

# --- Security groups --------------------------------------------------------
resource "aws_security_group" "alb" {
  name_prefix = "${local.name}-alb-"
  description = "ALB ${local.name}"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP dari internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Forward to targets in the private subnets"
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  lifecycle { create_before_destroy = true }
  tags = { Name = "${local.name}-alb-sg" }
}

resource "aws_security_group" "service" {
  name_prefix = "${local.name}-svc-"
  description = "ECS service ${local.name}"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Dari ALB saja"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  # Tasks need outbound HTTPS to pull images from ECR, reach Secrets Manager
  # and ship logs. Narrowing this further requires VPC endpoints for each of
  # those services.
  #checkov:skip=CKV_AWS_382:Outbound HTTPS is required for ECR, Secrets Manager and CloudWatch. Replacing it with VPC endpoints is tracked as future work.
  egress {
    description = "Outbound HTTPS for image pulls, secrets and log delivery"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  lifecycle { create_before_destroy = true }
  tags = { Name = "${local.name}-svc-sg" }
}

# --- Application Load Balancer ----------------------------------------------
resource "aws_lb" "this" {
  name               = substr("${local.name}-alb", 0, 32)
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection

  # Reject requests carrying headers the ALB cannot parse, rather than
  # forwarding them for the application to misinterpret.
  drop_invalid_header_fields = true

  dynamic "access_logs" {
    for_each = var.enable_access_logs ? [1] : []

    content {
      bucket  = aws_s3_bucket.logs[0].bucket
      prefix  = "alb"
      enabled = true
    }
  }

  depends_on = [aws_s3_bucket_policy.logs]

  tags = { Name = "${local.name}-alb" }
}

resource "aws_lb_target_group" "this" {
  name        = substr("${local.name}-tg", 0, 32)
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = var.health_check_path
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

# --- ECS cluster, IAM, log, task, service -----------------------------------
resource "aws_ecs_cluster" "this" {
  name = "${local.name}-cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${local.name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name_prefix        = "${var.environment}-web-exec-"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name_prefix        = "${var.environment}-web-task-"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_ecs_task_definition" "this" {
  family                   = local.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([{
    name         = "app"
    image        = var.container_image
    essential    = true
    portMappings = [{ containerPort = var.container_port, protocol = "tcp" }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.this.name
        "awslogs-region"        = data.aws_region.current.region
        "awslogs-stream-prefix" = "app"
      }
    }
  }])
}

resource "aws_ecs_service" "this" {
  name            = "${local.name}-svc"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # A failing deployment rolls itself back instead of sitting half-broken.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Lets `aws ecs execute-command` open a shell in a task for debugging,
  # without an SSH path into the subnet.
  enable_execute_command = true

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.http]

  # Auto scaling owns desired_count after the first deploy.
  lifecycle {
    ignore_changes = [desired_count]
  }
}
