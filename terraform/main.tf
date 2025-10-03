terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "aws_profile" {
  type        = string
  description = "llave profile"
  default     = "web-app"
}


# ---------- Networking ----------
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "${var.project_name}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = { Name = "${var.project_name}-igw" }
}

resource "aws_subnet" "public" {
  for_each = toset(var.public_subnets)
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = each.value
  map_public_ip_on_launch = true
  availability_zone       = element(data.aws_availability_zones.available.names, index(var.public_subnets, each.value))
  tags = { Name = "${var.project_name}-public-${replace(each.value, "/","-")}" }
}

data "aws_availability_zones" "available" {}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# ---------- Security Groups ----------
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "ALB SG"
  vpc_id      = aws_vpc.vpc.id
  ingress { from_port = 80  to_port = 80  protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] }
  ingress { from_port = 443 to_port = 443 protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] }
  egress  { from_port = 0   to_port = 0   protocol = "-1"  cidr_blocks = ["0.0.0.0/0"] }
  tags = { Name = "${var.project_name}-alb-sg" }
}

resource "aws_security_group" "ecs_sg" {
  name        = "${var.project_name}-ecs-sg"
  description = "ECS tasks SG"
  vpc_id      = aws_vpc.vpc.id
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  egress { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }
  tags = { Name = "${var.project_name}-ecs-sg" }
}

# ---------- ECR ----------
resource "aws_ecr_repository" "repo" {
  name                 = var.project_name
  image_scanning_configuration { scan_on_push = true }
  force_delete         = true
  tags = { Name = var.project_name }
}

# ---------- ECS ----------
resource "aws_ecs_cluster" "cluster" {
  name = "${var.project_name}-cluster"
}

data "aws_iam_policy_document" "task_exec_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { type = "Service" identifiers = ["ecs-tasks.amazonaws.com"] }
  }
}

resource "aws_iam_role" "task_exec_role" {
  name               = "${var.project_name}-task-exec"
  assume_role_policy = data.aws_iam_policy_document.task_exec_assume.json
}

resource "aws_iam_role_policy_attachment" "task_exec_attach" {
  role       = aws_iam_role.task_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Optional task role (least-privilege; empty by default)
data "aws_iam_policy_document" "task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { type = "Service" identifiers = ["ecs-tasks.amazonaws.com"] }
  }
}

resource "aws_iam_role" "task_role" {
  name               = "${var.project_name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
}

resource "aws_lb" "app_alb" {
  name               = "${var.project_name}-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [for s in aws_subnet.public : s.id]
  idle_timeout       = 60
  tags = { Name = "${var.project_name}-alb" }
}

resource "aws_lb_target_group" "tg" {
  name        = "${var.project_name}-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id
  target_type = "ip"
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http_80" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https_443" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

resource "aws_ecs_task_definition" "task" {
  family                   = "${var.project_name}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.task_exec_role.arn
  task_role_arn            = aws_iam_role.task_role.arn
  container_definitions = jsonencode([{
    name      = "web"
    image     = "${aws_ecr_repository.repo.repository_url}:latest"
    essential = true
    portMappings = [{ containerPort = 8080, protocol = "tcp" }]
    environment = [{ name = "APP_VERSION", value = "v1" }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "/ecs/${var.project_name}"
        awslogs-region        = var.region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

resource "aws_cloudwatch_log_group" "lg" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 14
}

resource "aws_ecs_service" "service" {
  name            = "${var.project_name}-svc"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = [for s in aws_subnet.public : s.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.tg.arn
    container_name   = "web"
    container_port   = 8080
  }
  depends_on = [aws_lb_listener.https_443]
}

# ---------- WAF (bloqueo de IP) ----------
resource "aws_wafv2_ip_set" "blocked" {
  name               = "${var.project_name}-blocked-ipset"
  description        = "IPs bloqueadas"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = [var.block_ip]
}

resource "aws_wafv2_web_acl" "webacl" {
  name  = "${var.project_name}-webacl"
  scope = "REGIONAL"
  default_action { allow {} }
  visibility_config {
    cloudwatch_metrics_enabled = true
    sampled_requests_enabled   = true
    metric_name                = "${var.project_name}-waf"
  }
  rule {
    name     = "BlockSpecificIP"
    priority = 1
    action { block {} }
    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.blocked.arn
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "block-specific-ip"
    }
  }
}

resource "aws_wafv2_web_acl_association" "assoc" {
  resource_arn = aws_lb.app_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.webacl.arn
}

# ---------- IAM (rol "admin de servicios ECS" personalizado) ----------
data "aws_iam_policy_document" "ecs_services_admin" {
  statement {
    sid     = "ECSServiceMgmt"
    actions = [
      "ecs:Describe*",
      "ecs:List*",
      "ecs:UpdateService",
      "ecs:UpdateServicePrimaryTaskSet",
      "ecs:CreateService",
      "ecs:DeleteService",
      "ecs:RegisterTaskDefinition",
      "ecs:DeregisterTaskDefinition",
      "iam:PassRole"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ecs_services_admin" {
  name        = "${var.project_name}-ecs-services-admin"
  description = "Permite gestionar únicamente servicios de ECS y task definitions (similar a run.admin)."
  policy      = data.aws_iam_policy_document.ecs_services_admin.json
}

data "aws_iam_policy_document" "ecs_admin_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { type = "AWS" identifiers = ["*"] } # Ajusta al principal real (usuario/grupo/role)
  }
}

resource "aws_iam_role" "ecs_services_admin_role" {
  name               = "${var.project_name}-ecs-services-admin-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_admin_assume.json
}

resource "aws_iam_role_policy_attachment" "ecs_admin_attach" {
  role       = aws_iam_role.ecs_services_admin_role.name
  policy_arn = aws_iam_policy.ecs_services_admin.arn
}
