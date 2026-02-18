output "application_url" {
  description = "The URL to access the Ollama Web UI"
  value       = "http://${module.compute.alb_dns_name}"
}

output "bastion_ssh_command" {
  description = "Command to connect to the Bastion host"
  value       = "ssh -i ${var.key_name}.pem ubuntu@${module.compute.bastion_public_ip}"
}