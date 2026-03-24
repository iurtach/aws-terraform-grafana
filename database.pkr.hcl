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
  subnet_id                   = "subnet-08776b4ee365bf258"
  associate_public_ip_address = true
  ssh_username                = "ubuntu"
  tags = {
    Role    = "database"
    Project = "llm-test"
  }
}

build {
  sources = ["source.amazon-ebs.database"]

  provisioner "shell" {
    inline = [
      # Switch to the eu-north-1 AWS Ubuntu mirror for reliable access from EC2
      "sudo sed -i 's|http://archive.ubuntu.com/ubuntu|http://eu-north-1.ec2.archive.ubuntu.com/ubuntu|g' /etc/apt/sources.list",
      "sudo sed -i 's|http://security.ubuntu.com/ubuntu|http://eu-north-1.ec2.archive.ubuntu.com/ubuntu|g' /etc/apt/sources.list",
      "sudo apt-get update --allow-releaseinfo-change",

      # PostgreSQL 14 (explicit version to avoid meta-package conflicts) + pgvector build deps
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql-14 postgresql-server-dev-14 build-essential git prometheus-node-exporter",

      # Build and install pgvector extension
      "git clone --branch v0.5.1 https://github.com/pgvector/pgvector.git",
      "cd pgvector && make && sudo make install",

      # Download postgres_exporter binary from GitHub (not in standard Ubuntu repos)
      "curl -sL https://github.com/prometheus-community/postgres_exporter/releases/download/v0.15.0/postgres_exporter-0.15.0.linux-amd64.tar.gz | tar xz -C /tmp",
      "sudo mv /tmp/postgres_exporter-0.15.0.linux-amd64/postgres_exporter /usr/local/bin/postgres_exporter",
      "sudo useradd --system --no-create-home --shell /bin/false postgres_exporter || true",
      "sudo touch /etc/default/prometheus-postgres-exporter",

      # Create systemd service for postgres_exporter
      "printf '[Unit]\\nDescription=PostgreSQL Metrics Exporter\\nAfter=network.target postgresql.service\\n\\n[Service]\\nUser=postgres_exporter\\nEnvironmentFile=/etc/default/prometheus-postgres-exporter\\nExecStart=/usr/local/bin/postgres_exporter\\nRestart=on-failure\\n\\n[Install]\\nWantedBy=multi-user.target\\n' | sudo tee /etc/systemd/system/prometheus-postgres-exporter.service",

      "sudo systemctl daemon-reload",
      "sudo systemctl enable prometheus-postgres-exporter",
      "sudo systemctl enable prometheus-node-exporter"
    ]
  }
}
