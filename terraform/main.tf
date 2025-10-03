terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# --- Variable solicitada ---
variable "aws_profile" {
  type        = string
  description = "llave profile"
  default     = "web-app"
}

# NOTA: Este main.tf asume que el resto de variables están definidas en variables.tf:
# - project_name (string)
# - region (string)
# - vpc_cidr (string)
# - public_subnets (list(string))  # e.g. ["10.20.1.0/24", "10.20.2.0/24"]
# - certificate_arn (string)
# - block_ip (string)

provider "aws" {
  region  = var.region
  profile = var.aws_profile
}

# Descubrimos AZs disponibles para repartir subnets en AZs distintas
data "aws_availability_zones" "available" {
  state = "available"
}

# ---------- Networking ----------
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Asignamos una AZ distinta a cada subnet según su índice en la lista var.public_subnets
resource "aws_subnet" "public" {
  for_each                = toset(var.public_subnets)
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = each.value
  map_public_ip_on_launch = true

  # Usa el índice de la CIDR en la lista original para seleccionar AZ por posición
  availability_zone = element(
    data.aws_availability_zones.available.names,
    index(var.public_subnets, each.value)
  )

  tags = {
    Name = "${var.project_name}-public-${replace(each.value, "/","-")}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
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

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ecs-sg"
  }
}

# ---------- ECR ----------
resource "aws_ecr_repository" "repo" {
  name = var.project_name

  image_scanning_configuration {
    scan_on_push = true
  }

  force_delete = true

  tags = {
    Name = var.project_name
  }
}

# ---------- ECS ----------
resource "aws_ecs_cluster" "cluster" {
  name = "${var.project_name}-cluster"
}

data "aws_iam_policy_document" "task_exec_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task_exec_role" {
  name               = "${var.project_name}-task-exec"
  assume_role_policy = data.aws_iam_policy_document.task_exec_assume.json
}

resource "aws_iam_role_policy_attachment" "task_exec_attach" {
  role       = aws_iam_role.task
