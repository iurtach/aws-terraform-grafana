# AWS Infrastructure for LLM, Database & Monitoring with Terraform 

This repository contains Terraform code to deploy a production-ready infrastructure on AWS. It is designed to host an **LLM (Ollama)**, a **PostgreSQL (pgvector)** database, and a comprehensive monitoring stack (**Prometheus, Grafana, Alertmanager**).

## 🏗️ System Architecture

The following diagram illustrates the VPC logic and the secure traffic flow between components.

```mermaid
graph TD
    subgraph Public_Subnet [Public Subnet]
        Bastion[Bastion Host]
        ALB[Application Load Balancer]
    end

    subgraph Private_Subnet_Monitoring [Private Subnet: Monitoring]
        Monitoring[Monitoring Host: Prometheus, Grafana, Alertmanager]
    end

    subgraph Private_Subnet_Compute [Private Subnet: Compute]
        LLM[LLM Host: Ollama]
    end

    subgraph Private_Subnet_DB [Private Subnet: Database]
        DB[(PostgreSQL + pgvector)]
    end

    %% Interactions
    Admin((Admin IP)) -->|SSH:22| Bastion
    Admin -->|UI:3000/9093| ALB
    Bastion -->|Internal SSH:22| LLM
    Bastion -->|Internal SSH:22| DB
    Bastion -->|Internal SSH:22| Monitoring

    ALB -->|HTTP:11434| LLM
    Monitoring -->|Scrape:9100/11434| LLM
    Monitoring -->|Scrape:9187/5432| DB
    LLM -->|Vector Search:5432| DB
    
    style Public_Subnet fill:#f9f,stroke:#333,stroke-width:2px
    style Private_Subnet_Compute fill:#bbf,stroke:#333,stroke-width:2px
    style DB fill:#dfd,stroke:#333,stroke-width:4px
```
## 🛠️ Technology Stack

IaC: Terraform

Cloud: AWS (VPC, EC2, ALB, Security Groups)

Machine Learning: Ollama API (Port 11434)

Database: PostgreSQL with pgvector

Monitoring:

Prometheus: Metrics collection & time-series storage.

Grafana: Advanced visualization and dashboards.

Alertmanager: Incident management with Telegram notifications.

Blackbox & Node Exporters: External probing and system-level metrics.

## 📁 Project Structure
The project follows a modular approach for better maintainability:

modules/vpc: Network configuration, including public/private subnets and NAT gateways.

modules/security: Fine-grained Security Groups following the Principle of Least Privilege.

modules/compute: EC2 instance definitions and Cloud-init automation.

modules/compute/templates: Dynamic .tpl files for automated service configuration (Prometheus, Alertmanager).

## 🔒 Security & Connectivity
Bastion SG: Restricts SSH access strictly to the Administrator's IP.

LLM SG: Accepts traffic on port 11434 only from the ALB and the Monitoring host.

DB SG: Allows PostgreSQL connections exclusively from the LLM compute layer.

Monitoring SG: Limits access to Grafana (3000) and Prometheus (9090) to authorized IPs.

## 🚦 Getting Started
Clone the repository.

Configure terraform.tfvars with your specific variables (VPC IDs, Telegram Bot Token, Chat ID).
