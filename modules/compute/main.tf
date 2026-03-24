# ---------------------------------------------------------------------------
# IAM — Prometheus / CloudWatch read access for monitoring instance
# ---------------------------------------------------------------------------

resource "aws_iam_role" "prometheus_read_role" {
  name = "prometheus-ec2-read-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "prometheus_ec2_read" {
  role       = aws_iam_role.prometheus_read_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "prometheus_cloudwatch_read" {
  role       = aws_iam_role.prometheus_read_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}

resource "aws_iam_instance_profile" "prometheus_profile" {
  name = "prometheus-instance-profile"
  role = aws_iam_role.prometheus_read_role.name
}

# ---------------------------------------------------------------------------
# EC2 Instances
# ---------------------------------------------------------------------------

resource "aws_instance" "bastion" {
  ami                    = var.bastion_ami_id
  instance_type          = "t3.micro"
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [var.bastion_sg_id]
  key_name               = var.key_name
  tags                   = { Name = "bastion-host" }
}

resource "aws_instance" "llm" {
  ami                    = var.llm_ami_id
  instance_type          = "t3.large"
  subnet_id              = var.private_subnet_ids[1]
  vpc_security_group_ids = [var.llm_sg_id]
  key_name               = var.key_name

  tags = {
    Name        = "llm-host"
    Monitoring  = "prometheus"
    ServiceType = "node-ollama"
  }

  # Configures node_exporter (pre-installed by Packer) and sets OLLAMA_HOST=0.0.0.0
  user_data = templatefile("${path.module}/templates/llm_setup.sh.tpl", {})
}

resource "aws_instance" "monitoring" {
  ami                    = var.monitoring_ami_id
  instance_type          = "t3.medium"
  subnet_id              = var.public_subnet_ids[1]
  vpc_security_group_ids = [var.monitoring_sg_id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.prometheus_profile.name
  tags                   = { Name = "monitoring-host" }

  # Writes configs and starts all monitoring containers (Docker pre-installed by Packer)
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

resource "aws_instance" "db" {
  ami                    = var.db_ami_id
  instance_type          = "t3.small"
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [var.db_sg_id]
  key_name               = var.key_name

  tags = {
    Name        = "llm-test-db"
    Monitoring  = "prometheus"
    ServiceType = "postgres"
  }

  # Creates PostgreSQL user/database and starts exporters (all pre-installed by Packer)
  user_data = templatefile("${path.module}/templates/db_setup.sh.tpl", {
    db_password = var.db_password
  })
}

# ---------------------------------------------------------------------------
# Config locals — assembled here and injected into monitoring user_data
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# Application Load Balancer
# ---------------------------------------------------------------------------

resource "aws_lb" "llm_alb" {
  name               = "llm-test-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids
  tags               = { Name = "llm-test-alb" }
}

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

resource "aws_lb_listener" "llm_http" {
  load_balancer_arn = aws_lb.llm_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.llm_tg.arn
  }
}

resource "aws_lb_target_group_attachment" "llm_attachment" {
  target_group_arn = aws_lb_target_group.llm_tg.arn
  target_id        = aws_instance.llm.id
  port             = 11434
}

# ---------------------------------------------------------------------------
# SNS → Lambda → Slack
# Follows: https://docs.aws.amazon.com/prometheus/latest/userguide/
#   AMP-alertmanager-SNS-otherdestinations.html#AMP-alertmanager-SNS-otherdestinations-Slack
# ---------------------------------------------------------------------------

resource "aws_sns_topic" "monitoring_alerts" {
  name = "monitoring-alerts-topic"
}

# IAM role for Lambda
resource "aws_iam_role" "sns_to_slack_lambda" {
  name = "sns-to-slack-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.sns_to_slack_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Package Lambda function code
data "archive_file" "sns_to_slack" {
  type = "zip"
  source {
    filename = "lambda_function.py"
    content  = <<-EOF
      import json
      import os
      import urllib.request

      def lambda_handler(event, context):
          webhook_url = os.environ["SLACK_WEBHOOK_URL"]
          sns_message = event["Records"][0]["Sns"]["Message"]

          try:
              alarm  = json.loads(sns_message)
              name   = alarm.get("AlarmName", "Unknown")
              state  = alarm.get("NewStateValue", "UNKNOWN")
              reason = alarm.get("NewStateReason", "")
              emoji  = "\U0001f525" if state == "ALARM" else "\u2705" if state == "OK" else "\u26a0\ufe0f"
              text   = f"{emoji} *{name}*\nState: {state}\n{reason}"
          except Exception:
              text = sns_message

          payload = json.dumps({"text": text}).encode("utf-8")
          req = urllib.request.Request(
              webhook_url,
              data=payload,
              headers={"Content-Type": "application/json"},
          )
          urllib.request.urlopen(req)
    EOF
  }
  output_path = "${path.module}/sns_to_slack.zip"
}

resource "aws_lambda_function" "sns_to_slack" {
  filename         = data.archive_file.sns_to_slack.output_path
  source_code_hash = data.archive_file.sns_to_slack.output_base64sha256
  function_name    = "sns-to-slack"
  role             = aws_iam_role.sns_to_slack_lambda.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }
}

# Allow SNS to invoke the Lambda function
resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sns_to_slack.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.monitoring_alerts.arn
}

# Subscribe Lambda to SNS topic
resource "aws_sns_topic_subscription" "lambda_subscription" {
  topic_arn = aws_sns_topic.monitoring_alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.sns_to_slack.arn
}

# ---------------------------------------------------------------------------
# CloudWatch Alarms → SNS
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "[llm]-[test]-[elb]-[high]-[host-count]"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "One or more ALB target hosts are failing health checks"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.llm_alb.arn_suffix
    TargetGroup  = aws_lb_target_group.llm_tg.arn_suffix
  }

  alarm_actions = [aws_sns_topic.monitoring_alerts.arn]
  ok_actions    = [aws_sns_topic.monitoring_alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "ec2_status_check" {
  alarm_name          = "[llm]-[test]-[ec2]-[status-check-failed]"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "EC2 instance status check failed"

  dimensions = {
    InstanceId = aws_instance.llm.id
  }

  alarm_actions = [aws_sns_topic.monitoring_alerts.arn]
  ok_actions    = [aws_sns_topic.monitoring_alerts.arn]
}
