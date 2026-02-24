variable "db_sg_id" {type = string}
variable "public_subnet_ids"  { type = list(string) }
variable "private_subnet_ids" { type = list(string) }
variable "bastion_sg_id"     { type = string }
variable "monitoring_sg_id"  { type = string }
variable "alb_sg_id" { type = string}
variable "llm_sg_id"         { type = string }
variable "key_name"          { type = string }
variable "vpc_id" { type = string }

variable "telegram_bot_token" {
  description = "Telegram token for Alertmanager"
  type        = string
  sensitive   = true
}
variable "telegram_chat_id" {
  description = "Telegram ID for notifications"
  type        = string
}

variable "db_password" {
  description = "Database password for PostgreSQL"
  type        = string
  sensitive   = true
}