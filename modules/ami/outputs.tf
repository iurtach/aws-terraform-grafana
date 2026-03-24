output "llm_ami_id" {
  description = "Packer-built AMI for LLM (Ollama) hosts"
  value       = data.aws_ami.llm.id
}

output "bastion_ami_id" {
  description = "Packer-built AMI for bastion host"
  value       = data.aws_ami.bastion.id
}

output "monitoring_ami_id" {
  description = "Packer-built AMI for monitoring host (Docker pre-installed)"
  value       = data.aws_ami.monitoring.id
}

output "db_ami_id" {
  description = "Packer-built AMI for database host (PostgreSQL + pgvector pre-installed)"
  value       = data.aws_ami.database.id
}
