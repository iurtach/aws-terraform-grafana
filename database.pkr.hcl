packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "database" {
  ami_name      = "postgresql-vector-db-{{timestamp}}"
  instance_type = "t3.small" 
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
    Role = "database"
    Build = "packer"
  }
}

build {
  sources = ["source.amazon-ebs.database"]

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      # Install PostgreSQL and build essentials for pgvector
      "sudo apt-get install -y postgresql postgresql-contrib postgresql-server-dev-all make gcc",
      
      # Clone and install pgvector
      "git clone --branch v0.5.1 https://github.com/pgvector/pgvector.git",
      "cd pgvector && make && sudo make install",
      
      # Install Prometheus Exporter for PostgreSQL
      "sudo apt-get install -y prometheus-postgres-exporter",
      "sudo systemctl enable prometheus-postgres-exporter"
    ]
  }
}