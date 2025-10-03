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
