output "alb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.llm_alb.dns_name
}

output "bastion_public_ip" {
  description = "Public IP address of the Bastion host"
  value       = aws_instance.bastion.public_ip
}

output "monitoring_public_ip" {
  value = aws_instance.monitoring.public_ip
}

output "llm_instance_private_ip" {
  description = "Private IP address of the LLM host"
  value       = aws_instance.llm
}

