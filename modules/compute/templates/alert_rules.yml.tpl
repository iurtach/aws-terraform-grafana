groups:
  - name: infrastructure_alerts
    rules:
      # --- DB Alerts ---
      - alert: "[llm]-[test]-[db]-[high]-[storage]"
        expr: 100 - (node_filesystem_avail_bytes{instance=~".*db.*", mountpoint="/"} / node_filesystem_size_bytes{instance=~".*db.*", mountpoint="/"} * 100) > 85
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "DB: High level of disk usage"

      - alert: "[llm]-[test]-[db]-[high]-[cpu]"
        expr: avg by(instance) (rate(node_cpu_seconds_total{instance=~".*db.*", mode!="idle"}[5m])) * 100 > 85
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "DB: High CPU usage"

      - alert: "[llm]-[test]-[db]-[high]-[memory]"
        expr: (1 - (node_memory_MemAvailable_bytes{instance=~".*db.*"} / node_memory_MemTotal_bytes{instance=~".*db.*"})) * 100 > 90
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "DB: High Memory usage"

      # --- EC2 Alerts ---
      - alert: "[llm]-[test]-[ec2]-[high]-[cpu]"
        expr: avg by(instance) (rate(node_cpu_seconds_total{instance!~".*db.*", mode!="idle"}[5m])) * 100 > 90
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "EC2: High CPU usage"

      - alert: "[llm]-[test]-[ec2]-[low]-[cpu]"
        expr: avg by(instance) (rate(node_cpu_seconds_total{instance!~".*db.*", mode!="idle"}[5m])) * 100 < 5
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "EC2: Low CPU usage (Instance underutilized)"

      - alert: "[llm]-[test]-[ec2]-[high]-[memory]"
        expr: (1 - (node_memory_MemAvailable_bytes{instance!~".*db.*"} / node_memory_MemTotal_bytes{instance!~".*db.*"})) * 100 > 90
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "EC2: High Memory usage"

      - alert: "[llm]-[test]-[ec2]-[low]-[memory]"
        expr: (node_memory_MemAvailable_bytes{instance!~".*db.*"} / node_memory_MemTotal_bytes{instance!~".*db.*"}) * 100 < 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "EC2: Low Free Memory"

      - alert: "[llm]-[test]-[ec2]-[high]-[disk-space]"
        expr: 100 - (node_filesystem_avail_bytes{instance!~".*db.*", mountpoint="/"} / node_filesystem_size_bytes{instance!~".*db.*", mountpoint="/"} * 100) > 85
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "EC2: High disk space usage"

      - alert: "[llm]-[test]-[ec2]-[low]-[disk-space]"
        expr: (node_filesystem_avail_bytes{instance!~".*db.*", mountpoint="/"} / node_filesystem_size_bytes{instance!~".*db.*", mountpoint="/"}) * 100 < 15
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "EC2: Low free disk space"

      - alert: "[llm]-[test]-[ec2]-[service]-[ollama]"
        expr: probe_success{job="ollama_exporter"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Service Ollama is down"

      # --- ELB / CloudWatch Alerts ---
      - alert: "[llm]-[test]-[elb]-[high]-[host-count]"
        expr: aws_applicationelb_un_healthy_host_count_maximum > 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "ALB: High Unhealthy Host Count"
          description: "One or more target hosts attached to the ALB are failing health checks."

      - alert: "[llm]-[test]-[elb]-[medium]-[4XX-errors]"
        expr: sum by(LoadBalancer) (rate(aws_applicationelb_httpcode_target_4_xx_count_sum[5m])) > 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "ALB: Frequent 4XX Errors"

      - alert: "[llm]-[test]-[elb]-[medium]-[5XX-errors]"
        expr: sum by(LoadBalancer) (rate(aws_applicationelb_httpcode_target_5_xx_count_sum[5m])) > 5
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "ALB: Frequent 5XX Errors"