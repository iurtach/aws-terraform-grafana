# Bastion Security Group: Only allows SSH from your specific IP
resource "aws_security_group" "bastion_sg" {
  name        = "llm-test-bastion-sg"
  description = "Allow SSH from Admin IP"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["213.109.232.90/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Monitoring Security Group: For Prometheus, Grafana, and Ollama Web UI
resource "aws_security_group" "monitoring_sg" {
  name        = "llm-test-monitoring-sg"
  description = "Allow Monitoring and Web UI access"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 3000 # Grafana UI
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["213.109.232.90/32"] # My IP for Grafana access
  }

  ingress {
    from_port   = 80 # Web interface for Ollama
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 9090 # Prometheus scraping port
    to_port         = 9090
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow Prometheus to be scraped from my IP for testing
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]

  }
}

resource "aws_security_group" "alb" {
  name        = "llm-test-alb-sg"
  description = "Allow incoming traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9093 # Alertmanager UI
    to_port     = 9093
    protocol    = "tcp"
    cidr_blocks = ["213.109.232.90/32"] 
  }


}


# LLM Security Group: Internal communication for Models and Metrics
resource "aws_security_group" "llm_sg" {
  name        = "llm-test-compute-sg"
  description = "Security group for LLM hosts"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id] # Access via Bastion only
  }

  ingress {
    from_port       = 11434 # Ollama API
    to_port         = 11434
    protocol        = "tcp"
    security_groups = [aws_security_group.monitoring_sg.id, aws_security_group.alb.id] # Access from Web UI/Monitoring
  }

  ingress {
    from_port       = 9100 # Node Exporter / Grafana Agent
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [aws_security_group.monitoring_sg.id] # Scraped by Prometheus
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Database Security Group: For PostgreSQL Vector DB
resource "aws_security_group" "db_sg" {
  name        = "llm-test-db-sg"
  description = "Allow Database access from LLM hosts"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432 # PostgreSQL port
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.llm_sg.id] # Only LLM hosts can talk to DB
  }

  ingress {
    from_port       = 9187 # pgvector extension port
    to_port         = 9187
    protocol        = "tcp"
    security_groups = [aws_security_group.monitoring_sg.id] # Allow monitoring of DB metrics
  }
  ingress {
    from_port       = 9100 # Node Exporter port
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [aws_security_group.monitoring_sg.id] # Allow monitoring of DB host metrics
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id] # Access via Bastion only
  }
}
