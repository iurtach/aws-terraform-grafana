output "alb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.llm_alb.dns_name
}

output "bastion_public_ip" {
  description = "Public IP address of the Bastion host"
  value       = aws_instance.bastion.public_ip
}