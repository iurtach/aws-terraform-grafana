global:
  scrape_interval: 15s
  evaluation_interval: 15s

# Alerting configuration
rule_files:
  - "alert_rules.yml"

# Alertmanager configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  - job_name: 'node-exporter'
    ec2_sd_configs:
      - region: 'eu-north-1'
    relabel_configs:
      # Filter instances by the Monitoring and ServiceType tags (keep only those with Monitoring=prometheus and ServiceType=node)
      - source_labels: [__meta_ec2_tag_Monitoring, __meta_ec2_tag_ServiceType]
        regex: 'prometheus;.*node.*'
        action: keep

      # Create the __address__ label by combining the private IP and the node_exporter port (9100)
      - source_labels: [__meta_ec2_private_ip]
        regex: '(.*)'
        replacement: '$$1:9100'
        target_label: __address__ 
      # set the instance label to the Name tag for easier identification in Grafana
      - source_labels: [__meta_ec2_tag_Name]
        target_label: instance

  - job_name: 'postgres-exporter'
    ec2_sd_configs:
      - region: 'eu-north-1'
    relabel_configs:
      - source_labels: [__meta_ec2_tag_Monitoring, __meta_ec2_tag_ServiceType]  
        regex: 'prometheus;postgres'
        action: keep
      - source_labels: [__meta_ec2_private_ip]
        regex: '(.*)'
        replacement: '$$1:9187'
        target_label: __address__

  - job_name: 'db-node-exporter'
    static_configs:
      - targets: ['${db_host_ip}:9100']
      
  #- job_name: 'ollama'
   # ec2_sd_configs:
    #  - region: 'eu-north-1'
    #relabel_configs:
      # Looking for servers with ServiceType 'ollama'
     # - source_labels: [__meta_ec2_tag_Monitoring, __meta_ec2_tag_ServiceType]
      #  regex: 'prometheus;.*ollama.*'
       # action: keep
      # Redirect on Ollama port (11434)
      #- source_labels: [__meta_ec2_private_ip]
       # regex: '(.*)'
        #replacement: '$${1}:11434'
        #target_label: __address__

  - job_name: 'prometheus-self'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'cloudwatch_exporter'
    static_configs:
      - targets: ['cloudwatch_exporter:9106']
  
  - job_name: 'ollama_exporter'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
        - http://${llm_host_ip}:11434/api/tags
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: '${blackbox_exporter_host}:9115'