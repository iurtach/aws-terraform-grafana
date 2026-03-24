packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "monitoring" {
  ami_name      = "monitoring-host-{{timestamp}}"
  instance_type = "t3.medium"
  region        = "eu-north-1"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"] # Canonical
  }
  subnet_id                   = "subnet-08776b4ee365bf258"
  associate_public_ip_address = true
  ssh_username                = "ubuntu"
  tags = {
    Role    = "monitoring"
    Project = "llm-test"
  }
}

build {
  sources = ["source.amazon-ebs.monitoring"]

  # Install Docker — all monitoring services (Prometheus, Grafana, Alertmanager, etc.)
  # are configured and started via user_data using Docker containers.
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y docker.io",
      "sudo systemctl enable docker",
      "sudo systemctl start docker",

      # Pre-pull monitoring stack images to speed up instance startup
      # open-webui is intentionally excluded (pulls at runtime) — it is ~8GB
      "sudo docker pull prom/prometheus:latest",
      "sudo docker pull prom/alertmanager:latest",
      "sudo docker pull grafana/grafana:latest",
      "sudo docker pull prom/blackbox-exporter:latest",
      "sudo docker pull prom/cloudwatch-exporter:latest"
    ]
  }
}
