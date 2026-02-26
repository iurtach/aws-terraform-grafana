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
  
  until apt-get update; do
      echo "Waiting for apt lock..."
      sleep 5
    done
  
  apt-get install -y docker.io
  
  systemctl start docker
  systemctl enable docker

  sleep 10 # Wait for Docker to be fully up and running

  docker pull prom/prometheus:latest
  docker pull prom/alertmanager:latest
  docker pull grafana/grafana:latest
  docker pull prom/blackbox-exporter:latest
  docker pull prom/cloudwatch-exporter:latest
  docker pull ghcr.io/open-webui/open-webui:main

  docker network create monitoring-network || true
  mkdir -p /etc/prometheus /etc/alertmanager /etc/blackbox
  mkdir -p /etc/grafana/provisioning/datasources /etc/grafana/provisioning/dashboards
  mkdir -p /var/lib/grafana/dashboards

  curl -L https://grafana.com/api/dashboards/9628/revisions/7/download -o /var/lib/grafana/dashboards/postgres-exporter.json
  curl -sL https://grafana.com/api/dashboards/1860/revisions/37/download -o /var/lib/grafana/dashboards/node-exporter.json
  
cat <<EOT > /etc/grafana/provisioning/datasources/datasource.yml
  apiVersion: 1
  datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus:9090
      access: proxy
      isDefault: true
EOT

cat <<EOT > /etc/grafana/provisioning/dashboards/dashboard_provider.yml
  apiVersion: 1
  providers:
    - name: 'node-exporter-dash'
      orgId: 1
      folder: 'System Metrics'
      type: file
      disableDeletion: false
      editable: true
      options:
        path: /var/lib/grafana/dashboards
EOT

  chown -R 472:472 /etc/grafana /var/lib/grafana
  chown -R 472:472 /etc/grafana/provisioning

  # Load the generated Prometheus configuration from Terraform
  cat <<EOT > /etc/prometheus/prometheus.yml
${local.prometheus_config}
EOT

  cat <<EOT > /etc/blackbox/blackbox.yml
${local.blackbox_config}
EOT

docker rm -f prometheus alertmanager cloudwatch_exporter blackbox-exporter grafana open-webui || true

# Run Blackbox Exporter for monitoring LLM
  docker run -d \
    --name blackbox-exporter \
    --network monitoring-network \
    --network-alias blackbox-exporter \
    -v /etc/blackbox/blackbox.yml:/etc/blackbox_exporter/config.yml \
    -p 9115:9115 \
    prom/blackbox-exporter:latest

  docker run -d -p 80:8080 \
    --name open-webui \
    --network monitoring-network \
    --restart always \
    -e OLLAMA_BASE_URL=http://${aws_instance.llm.private_ip}:11434 \
    ghcr.io/open-webui/open-webui:main

  

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
    --network monitoring-network \
    --restart always \
    -v /etc/grafana/provisioning/datasources/datasource.yml:/etc/grafana/provisioning/datasources/datasource.yml \
    -v /etc/grafana/provisioning/dashboards/dashboard_provider.yml:/etc/grafana/provisioning/dashboards/dashboard_provider.yml \
    -v /var/lib/grafana/dashboards:/var/lib/grafana/dashboards \
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
    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

    echo "Starting user_data script..."

    apt-get update
    
    until apt-get update; do
      echo "Waiting for apt lock..."
      sleep 5
    done

    apt-get install -y docker.io

    systemctl start docker
    systemctl enable docker

    sleep 10 # Wait for Docker to be fully up and running

    echo "Pulling docker images..."
    docker pull postgres:latest
    docker pull prometheuscommunity/postgres-exporter:latest
    docker pull prom/node-exporter:latest

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
    db_host_ip             = aws_instance.db.private_ip
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

  blackbox_config = templatefile("${path.module}/templates/blackbox.yml.tpl", {})
}
