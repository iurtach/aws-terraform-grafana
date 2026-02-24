groups:
  - name: llm_test_alerts
    rules:
      - alert: "[llm]-[test]-[ec2]-[low]-[memory]"
        expr: (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 < 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Low level of free RAM {{ \$labels.instance }}"
          description: "Less then 10% free Ram"

      - alert: "[llm]-[test]-[db]-[high]-[storage]"
        expr: 100 - (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} * 100) > 85
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High level of disk usage"
          description: "Utilized 85% of storage on {{ $labels.instance }}."

      - alert: "[llm]-[test]-[ollama]-[down]"
        expr: up{job="ollama"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Service Ollama is down"
          description: "Ollama on instance {{ $labels.instance }} stop responding."

      - alert: "[llm]-[test]-[ec2]-[high]-[cpu]"
        expr: avg by(instance) (rate(node_cpu_seconds_total{mode!="idle"}[5m])) * 100 > 90
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage is above 90% for more than 5 minutes on {{ $labels.instance }}."
      
      - alert: "[llm]-[test]-[alb]-[high]-[4xx]"
        expr: sum by(LoadBalancer) (rate(HTTPCode_Target_4XX_Count{job="cloudwatch_exporter"}[5m])) > 100
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High number of 4xx errors on {{ $labels.LoadBalancer }}"
          description: "More than 100 4xx errors per minute on {{ $labels.LoadBalancer }} for more than 5 minutes."
      
      - alert: "[llm]-[test]-[alb]-[high]-[5xx]"
        expr: sum by(LoadBalancer) (rate(HTTPCode_Target_5XX_Count{job="cloudwatch_exporter"}[5m])) > 50
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High number of 5xx errors on {{ $labels.LoadBalancer }}"
          description: "More than 50 5xx errors per minute on {{ $labels.LoadBalancer }} for more than 5 minutes."
      
      - alert: "[llm]-[test]-[alb]-[unhealthy]-[targets]"
        expr: avg by(LoadBalancer) (HealthyHostCount{job="cloudwatch_exporter"}) < 2
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Unhealthy targets on {{ $labels.LoadBalancer }}"
          description: "Less than 2 healthy targets on {{ $labels.LoadBalancer }} for more than 5 minutes." 
