output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.llm_alb.dns_name
}

output "bastion_public_ip" {
  description = "Public IP address of the bastion host"
  value       = aws_instance.bastion.public_ip
}

output "monitoring_public_ip" {
  description = "Public IP address of the monitoring host"
  value       = aws_instance.monitoring.public_ip
}

output "llm_instance_private_ip" {
  description = "Private IP address of the LLM host"
  value       = aws_instance.llm.private_ip
}
