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
  instance_type = "t3.micro" # Minimal resources needed for monitoring
  region        = "eu-north-1"
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"] # Canonical
  }
  ssh_username = "ubuntu"
  tags = {
    Role    = "monitoring"
    Project = "llm-test"
  }
}

build {
  sources = ["source.amazon-ebs.monitoring"]

  # Provisioner to install Prometheus and Grafana
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y apt-transport-https software-properties-common wget",
      
      # Install Prometheus
      "sudo apt-get install -y prometheus",
      
      # Install Grafana
      "wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null",
      "echo \"deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main\" | sudo tee /etc/apt/sources.list.d/grafana.list",
      "sudo apt-get update",
      "sudo apt-get install -y grafana",
      
      # Enable services
      "sudo systemctl enable prometheus",
      "sudo systemctl enable grafana-server"
    ]
  }
}