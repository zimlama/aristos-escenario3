variable "aws_profile" {
  type        = string
  description = "llave profile"
  default     = "web-app"
}

variable "project_name" {
  type    = string
  default = "aristos-escenario3"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "block_ip" {
  type        = string
  default     = "1.2.3.4/32"
  description = "IP/CIDR a bloquear con WAF"
}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate ARN for your domain (same region as ALB)."
  default     = "arn:aws:acm:us-east-1:064625181580:certificate/ccf638af-6cc7-4f25-9362-a0e5e93bda44"
}

