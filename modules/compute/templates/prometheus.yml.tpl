global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'node-exporter'
      ec2_sd_configs:
      region: 'eu-north-1'
      relabel_configs:
      # Filter instances by the Monitoring and ServiceType tags (keep only those with Monitoring=prometheus and ServiceType=node)
      - source_labels: [__meta_ec2_tag_Monitoring, __meta_ec2_tag_ServiceType]
        regex: 'prometheus;node'
        action: keep

      # Create the __address__ label by combining the private IP and the node_exporter port (9100)
      - source_labels: [__meta_ec2_private_ip]
        replacement: '$${1}:9100'
        target_label: __address__ 

    job_name: 'postgres-exporter'
      ec2_sd_configs:
      region: 'eu-north-1'
      relabel_configs:

      - source_labels: [__meta_ec2_tag_Monitoring, __meta_ec2_tag_ServiceType]  
        regex: 'prometheus;postgres'
        action: keep

      - source_labels: [__meta_ec2_private_ip]
        replacement: '$${1}:9187'
        target_label: __address__

      
