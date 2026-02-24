# Find AMI for Bastion & Monitoring
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
	name = "name"
	values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  owners = ["099720109477"] # Canonical
}

# Looking for LLM  (Packer)
data "aws_ami" "llm_gpu" {
  most_recent = true
  filter {
	name = "tag:Role"
	values = ["llm"]
  }
  owners      = ["self"]
}

resource "aws_iam_role" "prometheus_read_role" {
  name = "prometheus-ec2-read-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "prometheus_read_attach" {
  role       = aws_iam_role.prometheus_read_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_attach" {
  role       = aws_iam_role.prometheus_read_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
  
}

resource "aws_iam_instance_profile" "prometheus_profile" {
  name = "prometheus-instance-profile"
  role = aws_iam_role.prometheus_read_role.name
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
  instance_type          = "t3.large"
  subnet_id              = var.private_subnet_ids[1]
  vpc_security_group_ids = [var.llm_sg_id, var.bastion_sg_id]
  key_name               = var.key_name
  tags                   = {
    Name = "llm-host"
    Monitoring = "prometheus"
    ServiceType = "node-ollama"
  }
  user_data = <<-EOF
    #!/bin/bash
    # node_exporter
    wget https://github.com/prometheus/node_exporter/releases/download/v1.10.2/node_exporter-1.10.2.linux-amd64.tar.gz
    tar xvf node_exporter-1.10.2.linux-amd64.tar.gz
    cp node_exporter-1.10.2.linux-amd64/node_exporter /usr/local/bin/  
    cat <<EOT > /etc/systemd/system/node_exporter.service
    [Unit]
      Description=Node Exporter
      After=network.target
      
    [Service]
      User=ubuntu
      ExecStart=/usr/local/bin/node_exporter
      Restart=always

    [Install]
      WantedBy=multi-user.target
    EOT

    mkdir -p /etc/systemd/system/ollama.service.d
    cat <<EOT > /etc/systemd/system/ollama.service.d/override.conf
    [Service]
      Environment="OLLAMA_HOST=0.0.0.0"
    EOT

    systemctl daemon-reload
    systemctl enable node_exporter
    systemctl start node_exporter
    systemctl restart ollama
  EOF
}

resource "aws_instance" "monitoring" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.medium"
  subnet_id              = var.public_subnet_ids[1]
  vpc_security_group_ids = [var.monitoring_sg_id, var.bastion_sg_id]
  key_name               = var.key_name
  tags                   = { Name = "monitoring-host" }
  iam_instance_profile = aws_iam_instance_profile.prometheus_profile.name

user_data = <<-EOF
#!/bin/bash

  apt-get update
  apt-get install -y docker.io
  docker network create monitoring-network || true
  mkdir -p /etc/prometheus /etc/alertmanager /etc/grafana
  
  # Run Blackbox Exporter for monitoring LLM
  docker run -d \
    --name blackbox-exporter \
    --network monitoring-network \
    --network-alias blackbox-exporter \
    -p 9115:9115 \
    prom/blackbox-exporter:latest
  
  docker rm -f prometheus alertmanager cloudwatch_exporter || true

  docker run -d -p 80:8080 \
    -e OLLAMA_BASE_URL=http://${aws_instance.llm.private_ip}:11434 \
    --name open-webui \
    --restart always \
    ghcr.io/open-webui/open-webui:main

  # Load the generated Prometheus configuration from Terraform
  cat <<EOT > /etc/prometheus/prometheus.yml
${local.prometheus_config}
EOT

  cat <<EOT > /etc/prometheus/alert_rules.yml
${local.alert_rules}
EOT
  
  docker run -d --name prometheus --network monitoring-network \
    -p 9090:9090 \
    -v /etc/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
    -v /etc/prometheus/alert_rules.yml:/etc/prometheus/alert_rules.yml \
    --restart always \
    prom/prometheus:latest    

  # Load alerting rules
  
  cat <<EOT > /etc/alertmanager/alertmanager.yml
${local.alertmanager_config}
EOT  

  docker run -d --name alertmanager --network monitoring-network \
    -p 9093:9093 \
    -v /etc/alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml \
    --restart always \
    prom/alertmanager:latest

  
  docker run -d -p 3000:3000 \
    --name grafana \
    --restart always \
    grafana/grafana:latest
  
  cat <<EOT > /etc/prometheus/cloudwatch_exporter.yml
${local.cloudwatch_exporter} 
EOT

  docker run -d --name cloudwatch_exporter --network monitoring-network \
  -p 9106:9106 \
  -v /etc/prometheus/cloudwatch_exporter.yml:/config.yml \
  --restart always \
  prom/cloudwatch-exporter:latest /config.yml

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

user_data = <<-EOF
    #!/bin/bash
    
    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
      echo "Waiting for other package manager to finish..."
      sleep 5
    done

    apt-get update
    apt-get install -y docker.io
    docker run -d --name postgres --network host \
      -e POSTGRES_PASSWORD=${var.db_password} \
      -e POSTGRES_USER=admin \
      -e POSTGRES_DB=llm_test_db \
      --restart always \
      postgres:latest
    
    docker run -d --name postgres_exporter --network host \
      -e DATA_SOURCE_NAME="postgresql://admin:${var.db_password}@localhost:5432/llm_test_db?sslmode=disable" \
      --restart always \
      prometheuscommunity/postgres-exporter:latest

    docker run -d --name node_exporter --network host \
      --restart always \
      prom/node-exporter:latest
  EOF
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
    llm_host_ip            = aws_instance.llm.private_ip
    blackbox_exporter_host = "blackbox-exporter"
    alertmanager_host      = "alertmanager"  
  })

  alertmanager_config = templatefile("${path.module}/templates/alertmanager.yml.tpl", {
    bot_token = var.telegram_bot_token
    chat_id   = var.telegram_chat_id
  })

  alert_rules = templatefile("${path.module}/templates/alert_rules.yml.tpl", {})

  cloudwatch_exporter = templatefile("${path.module}/templates/cloudwatch_exporter.yml.tpl", {
    region = "eu-north-1"
  })
}
