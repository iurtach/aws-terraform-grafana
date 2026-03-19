# Find AMI for Bastion & Monitoring
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  owners = ["099720109477"] # Canonical
}

# Looking for LLM (Packer)
data "aws_ami" "llm_gpu" {
  most_recent = true
  filter {
    name   = "tag:Role"
    values = ["llm"]
  }
  owners = ["self"]
}

resource "aws_iam_role" "prometheus_read_role" {
  name = "prometheus-ec2-read-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
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
  tags = {
    Name        = "llm-host"
    Monitoring  = "prometheus"
    ServiceType = "node-ollama"
  }
  user_data = templatefile("${path.module}/templates/llm_setup.sh.tpl", {})
}



resource "aws_instance" "monitoring" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.medium"
  subnet_id              = var.public_subnet_ids[1]
  vpc_security_group_ids = [var.monitoring_sg_id, var.bastion_sg_id]
  key_name               = var.key_name
  tags                   = { Name = "monitoring-host" }
  iam_instance_profile   = aws_iam_instance_profile.prometheus_profile.name

user_data = templatefile("${path.module}/templates/monitoring_setup.sh.tpl", {
    prometheus_config   = local.prometheus_config
    alertmanager_config = local.alertmanager_config
    alert_rules         = local.alert_rules
    blackbox_config     = local.blackbox_config
    cloudwatch_exporter = local.cloudwatch_exporter
    llm_private_ip      = aws_instance.llm.private_ip
  })

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  prometheus_config = templatefile("${path.module}/templates/prometheus.yml.tpl", {
    region                 = "eu-north-1"
    llm_host_ip            = aws_instance.llm.private_ip
    db_host_ip             = aws_instance.db.private_ip
    blackbox_exporter_host = "blackbox-exporter"
    alertmanager_host      = "alertmanager"
  })

  alertmanager_config = templatefile("${path.module}/templates/alertmanager.yml.tpl", {
    slack_webhook_url = var.slack_webhook_url
  })

  alert_rules = templatefile("${path.module}/templates/alert_rules.yml.tpl", {})

  cloudwatch_exporter = templatefile("${path.module}/templates/cloudwatch_exporter.yml.tpl", {
    region = "eu-north-1"
  })

  blackbox_config = templatefile("${path.module}/templates/blackbox.yml.tpl", {})
}

resource "aws_instance" "db" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.small"
  subnet_id     = var.private_subnet_ids[0]
  key_name      = var.key_name

  vpc_security_group_ids = [var.db_sg_id, var.bastion_sg_id]

  user_data = templatefile("${path.module}/templates/db_setup.sh.tpl", {
    db_password = var.db_password
  })

  tags = {
    Name        = "llm-test-db"
    Monitoring  = "prometheus"
    ServiceType = "postgres"
  }

}

# Application Load Balancer
resource "aws_lb" "llm_alb" {
  name               = "llm-test-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  tags = {
    Name = "llm-test-alb"
  }
}

# Application Load Balancer Listener
resource "aws_lb_listener" "llm_http" {
  load_balancer_arn = aws_lb.llm_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.llm_tg.arn
  }
}

# Target Group for LLM requests
resource "aws_lb_target_group" "llm_tg" {
  name     = "llm-target-group"
  port     = 11434
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/api/tags"
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

resource "aws_sns_topic" "monitoring_alerts" {
  name = "monitoring-alerts-topic"
  
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.monitoring_alerts.arn
  protocol  = "email"
  endpoint  = "iur.tach@gmail.com"
  
}
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "ALB-Unhealthy-Hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnhealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"

  dimensions = {
    LoadBalancer = aws_lb.llm_alb.arn_suffix
    TargetGroup  = aws_lb_target_group.llm_tg.arn_suffix
  }

  alarm_description   = "Alarm when ALB has unhealthy hosts in the target group"
  actions_enabled     = true 

  
}

resource "aws_cloudwatch_metric_alarm" "ec2_status_check" {
  alarm_name          = "[llm]-[test]-[ec2]-[status-check-failed]"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "0"
  alarm_description   = "This alarm triggers if the EC2 instance status check fails."

  dimensions = {
    InstanceId = aws_instance.llm.id
  }

  alarm_actions = [aws_sns_topic.monitoring_alerts.arn]
  ok_actions    = [aws_sns_topic.monitoring_alerts.arn]
}