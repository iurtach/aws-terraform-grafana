# Find AMI for Bastion & Monitoring
data "aws_ami" "ubuntu" {
  most_recent = true
  filter { name = "name", values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"] }
  owners = ["099720109477"] # Canonical
}

# Looking for LLM  (Packer)
data "aws_ami" "llm_gpu" {
  most_recent = true
  filter { name = "tag:Role", values = ["llm"] }
  owners      = ["self"]
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [var.bastion_sg_id]
  key_name               = var.key_name
  tags                   = { Name = "bastion-host" }
}

resource "aws_instance" "llm" {
  ami                    = data.aws_ami.llm_gpu.id
  instance_type          = "g4dn.xlarge"
  subnet_id              = var.private_subnet_ids[1]
  vpc_security_group_ids = [var.llm_sg_id, var.bastion_sg_id]
  key_name               = var.key_name
  tags                   = {
    Name = "llm-host"
    Monitoring = "prometheus"
    ServiceType = "node"
  }
}

resource "aws_instance" "monitoring" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.medium"
  subnet_id              = var.public_subnet_ids[1]
  vpc_security_group_ids = [var.monitoring_sg_id, var.bastion_sg_id]
  key_name               = var.key_name
  tags                   = { Name = "monitoring-host" }
  iam_instance_profile = aws_iam_instance_profile.monitoring_profile.name

user_data = <<-EOF
    #!/bin/bash
  
    mkdir -p /etc/prometheus

    # Load the generated Prometheus configuration from Terraform
    cat <<EOT > /etc/prometheus/prometheus.yml
    ${local.prometheus_config}
    EOT

    # restart Prometheus to apply the new configuration
    systemctl restart prometheus
  EOF

lifecycle {
    create_before_destroy = true
  }

}

resource "aws_instance" "db" {
  ami           = data.aws_ami.ubuntu.id 
  instance_type = "t3.small"
  subnet_id     = var.private_subnet_ids[0]
  key_name      = var.key_name


  vpc_security_group_ids = [var.db_sg_id, var.bastion_sg_id]

  tags = {
    Name = "llm-test-db"
    Monitoring = "prometheus"
    ServiceType = "postgres"
    }
}

# Application Load Balancer Listener
resource "aws_lb_listener" "llm_http" {
  load_balancer_arn = aws_lb.llm_alb.arn
  port              = "80"
  protocol          = "HTTP"

  # Default action to forward traffic
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.llm_tg.arn
  }
}

# Application Load Balancer
resource "aws_lb" "llm_alb" {
  name               = "llm-test-alb"
  internal           = false # Accessible from the internet
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  tags = {
    Name = "llm-test-alb"
  }
}

# Target Group for LLM requests
resource "aws_lb_target_group" "llm_tg" {
  name     = "llm-target-group"
  port     = 11434
  protocol = "HTTP"
  vpc_id   = var.vpc_id # Ensure vpc_id is passed to this module

  health_check {
    path                = "/api/tags" # Standard Ollama health check endpoint
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Attach LLM instance to the Target Group
resource "aws_lb_target_group_attachment" "llm_attachment" {
  target_group_arn = aws_lb_target_group.llm_tg.arn
  target_id        = aws_instance.llm.id
  port             = 11434
}


locals {
  prometheus_config = templatefile("${path.module}/templates/prometheus.yml.tpl", {
    region = "eu-north-1"
  })
}