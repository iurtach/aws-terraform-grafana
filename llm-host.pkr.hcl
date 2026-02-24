packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "llm_gpu" {
  ami_name      = "llm-gpu-node-{{timestamp}}"
  instance_type = "t3.large" 
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
    Role    = "llm"
    Project = "llm-test"
  }
}

build {
  sources = ["source.amazon-ebs.llm_gpu"]

  # Provisioner to install Ollama
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "curl -fsSL https://ollama.com/install.sh | sh",               # Ollama
      "sudo systemctl enable ollama"
    ]
  }
}