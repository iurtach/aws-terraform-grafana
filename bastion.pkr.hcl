

source "amazon-ebs" "bastion" {
  ami_name      = "bastion-host-{{timestamp}}"
  instance_type = "t3.nano" # Minimal resources needed
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
    Role    = "bastion"
    Project = "llm-test"
    Build   = "packer"
  }
}

build {
  sources = ["source.amazon-ebs.bastion"]

  # Provisioner to harden the system and install monitoring agents
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      
      # Install Node Exporter for infrastructure monitoring 
      "sudo apt-get install -y prometheus-node-exporter",
      "sudo systemctl enable prometheus-node-exporter",
      
      # Basic security: Fail2Ban to prevent brute-force attacks
      "sudo apt-get install -y fail2ban",
      "sudo systemctl enable fail2ban"
    ]
  }
}