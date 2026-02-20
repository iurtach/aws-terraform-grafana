EC2 Infrastructure Monitoring with Prometheus & Terraform
This project demonstrates the deployment of an automated monitoring system within AWS using Infrastructure as Code (IaC) and Dynamic Service Discovery.

🛠 Tech Stack
Terraform: Infrastructure provisioning (VPC, Subnets, EC2, IAM).

Prometheus: Metric collection and storage (deployed via Docker).

AWS EC2 Service Discovery: Automated target discovery.

Node Exporter: System-level metrics collection.

🏗 Key Accomplishments
1. Automated Infrastructure & Security
Provisioned dedicated Monitoring and LLM hosts using Terraform.

Implemented IAM Instance Profiles with AmazonEC2ReadOnlyAccess policies, allowing Prometheus to securely query the AWS EC2 API.

2. Dynamic Service Discovery (EC2 SD)
Replaced static target configurations with ec2_sd_configs.

Configured real-time filtering of instances based on AWS Tags:

Monitoring: prometheus

ServiceType: node / ollama

3. Advanced Relabeling Configuration
Dynamic Addressing: Automated target mapping using __meta_ec2_private_ip.

Metric Enrichment: Implemented relabeling rules to map the AWS Name tag to the instance label for improved observability in dashboards.

Target Filtering: Used regex-based keep actions to ensure only relevant tagged instances are scraped.
