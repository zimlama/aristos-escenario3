variable "project_name" {
  type    = string
  default = "aws-ci-cd-sec-app"
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

variable "certificate_arn" {
  type        = string
  description = "ACM certificate ARN for your domain (same region as ALB)."
}

variable "block_ip" {
  type        = string
  default     = "1.2.3.4/32"
  description = "IP/CIDR to block with AWS WAF."
}
