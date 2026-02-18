output "bastion_sg_id" {
  value = aws_security_group.bastion_sg.id
}

output "llm_sg_id" {
  value = aws_security_group.llm_sg.id
}

output "monitoring_sg_id" {
  value = aws_security_group.monitoring_sg.id
}

output "db_sg_id" {
  value = aws_security_group.db_sg.id
}

output "alb_sg_id" {
  value = aws_security_group.alb.id
}