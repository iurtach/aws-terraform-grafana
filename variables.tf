variable "public_subnets_cidr" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets_cidr" {
  type    = list(string)
  default = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
} 

variable "key_name" {
  description = "Name of the existing EC2 Key Pair to use for SSH access"
  default     = "wordpress-key" 
}

variable "my_ip" {
  description = "My IP address"
  default = "213.109.232.90"
}

variable "telegram_bot_token" {
  description = "Token Telegram bot"
  type        = string
  sensitive   = true
}

variable "telegram_chat_id" {
  description = "ID Telegram chat"
  type        = string
}

variable "db_password" {
  type      = string
  sensitive = true
}
