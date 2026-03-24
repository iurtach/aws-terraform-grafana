variable "vpc_id"              { type = string }
variable "public_subnet_ids"  { type = list(string) }
variable "private_subnet_ids" { type = list(string) }
variable "key_name"           { type = string }

variable "bastion_sg_id"    { type = string }
variable "monitoring_sg_id" { type = string }
variable "alb_sg_id"        { type = string }
variable "llm_sg_id"        { type = string }
variable "db_sg_id"         { type = string }

variable "bastion_ami_id" {
  description = "Packer-built AMI for bastion host"
  type        = string
}

variable "llm_ami_id" {
  description = "Packer-built AMI for LLM (Ollama) host"
  type        = string
}

variable "monitoring_ami_id" {
  description = "Packer-built AMI for monitoring host"
  type        = string
}

variable "db_ami_id" {
  description = "Packer-built AMI for database host"
  type        = string
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
