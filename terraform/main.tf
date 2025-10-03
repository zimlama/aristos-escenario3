terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Usa el profile local (configurado en ~/.aws/credentials)
variable "aws_profile" {
  type        = string
  description = "llave profile"
  default     = "web-app"
}

# Este módulo asume que en variables.tf existen:
# - project_name (string)          # ej: "aristos-escenario3"
# - region (string)                # ej: "us-east-1"
# - vpc_cidr (string)              # ej: "10.20.0.0/16"
# - public_subnets (list(string))  # ej: ["10.20.1.0/24","10.20.2.0/24"]
# - block_ip (string)              # ej: "1.2.3.4/32"

provider "aws" {
  region  = var.region
  profile = var.aws_profile
}

# AZs disponibles (para distribuir subnets)
data "aws_availability_zones" "available" {
  state = "available"
}

# ---------------- Networking ----------------
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

resource "aws_subnet" "public" {
  for_each                = toset(var.public_subnets)
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = each.value
  map_public_ip_on_launch = true

  # Asegura AZs distintas según el índice en la lista original
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

# ---------------- Security Groups ----------------
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-s_
