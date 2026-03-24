variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnets_cidr" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets_cidr" {
  type    = list(string)
  default = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "key_name" {
  description = "Name of the existing EC2 Key Pair"
  default     = "wordpress-key"
}

variable "db_password" {
  description = "PostgreSQL admin password"
  type        = string
  sensitive   = true
}

variable "slack_webhook_url" {
  description = "Slack Incoming Webhook URL for CloudWatch alarm notifications"
  type        = string
  sensitive   = true
}
