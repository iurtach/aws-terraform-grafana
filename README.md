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

## 🏗️ Technical Architecture & Service Discovery
This project implements a dynamic monitoring ecosystem that automatically adapts to your AWS environment. ☁️

EC2 Service Discovery (SD): Prometheus 🔍 does not rely on static IP lists. It integrates directly with the AWS API to dynamically discover targets based on their metadata.

Tag-Based Filtering: I use a specific relabeling logic to ensure only the right instances are monitored. Prometheus only scrapes targets where:

The Monitoring tag is set to prometheus.

The ServiceType tag matches the expected exporter (e.g., node, postgres).

Grafana Auto-Provisioning: The entire Grafana 📊 setup is "Configuration as Code." Upon startup, it automatically:

Connects to the Prometheus Data Source.

Imports pre-defined JSON Dashboards for Linux and PostgreSQL.

IAM Security & Stability: The monitoring instance uses an IAM role with AmazonEC2ReadOnlyAccess to safely query AWS tags. The file permissions (chown 472:472) was granted to ensure the Grafana Docker container can reliably read its configuration from mounted volumes. 🛡️

## Monitoring & Metrics Overview
I use a multi-exporter approach to provide a 360-degree view of the infrastructure:
<img width="780" height="171" alt="image" src="https://github.com/user-attachments/assets/f8e9ebd1-8f55-47f3-baaa-af68e815e42d" />

## 🚦 Getting Started
Clone the repository.

Configure terraform.tfvars with your specific variables (VPC IDs, Telegram Bot Token, Chat ID).
