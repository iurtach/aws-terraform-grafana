#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Docker is pre-installed by the Packer AMI. Docker images are also pre-pulled.
# This script writes configs and starts all monitoring containers.

docker network create monitoring-network || true

mkdir -p /etc/prometheus /etc/alertmanager /etc/blackbox
mkdir -p /etc/grafana/provisioning/datasources /etc/grafana/provisioning/dashboards
mkdir -p /var/lib/grafana/dashboards

cat <<'EOT' > /etc/prometheus/prometheus.yml
${prometheus_config}
EOT

cat <<'EOT' > /etc/prometheus/alert_rules.yml
${alert_rules}
EOT

cat <<'EOT' > /etc/alertmanager/alertmanager.yml
${alertmanager_config}
EOT

cat <<'EOT' > /etc/blackbox/blackbox.yml
${blackbox_config}
EOT

cat <<'EOT' > /etc/prometheus/cloudwatch_exporter.yml
${cloudwatch_exporter}
EOT

# Download pre-built Grafana dashboards
curl -sL https://grafana.com/api/dashboards/1860/revisions/37/download \
  -o /var/lib/grafana/dashboards/node-exporter.json
curl -sL https://grafana.com/api/dashboards/9628/revisions/7/download \
  -o /var/lib/grafana/dashboards/postgres-exporter.json

cat <<'EOT' > /etc/grafana/provisioning/datasources/datasource.yml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    url: http://prometheus:9090
    access: proxy
    isDefault: true
EOT

cat <<'EOT' > /etc/grafana/provisioning/dashboards/dashboard_provider.yml
apiVersion: 1
providers:
  - name: 'system-metrics'
    orgId: 1
    folder: 'System Metrics'
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /var/lib/grafana/dashboards
EOT

chown -R 472:472 /etc/grafana /var/lib/grafana

# Remove any leftover containers from previous runs
docker rm -f prometheus alertmanager cloudwatch_exporter blackbox-exporter grafana open-webui 2>/dev/null || true

docker run -d --name blackbox-exporter --network monitoring-network \
  -v /etc/blackbox/blackbox.yml:/etc/blackbox_exporter/config.yml \
  -p 9115:9115 --restart always \
  prom/blackbox-exporter:latest

docker run -d --name prometheus --network monitoring-network \
  -v /etc/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
  -v /etc/prometheus/alert_rules.yml:/etc/prometheus/alert_rules.yml \
  -p 9090:9090 --restart always \
  prom/prometheus:latest

docker run -d --name alertmanager --network monitoring-network \
  -v /etc/alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml \
  -p 9093:9093 --restart always \
  prom/alertmanager:latest

docker run -d --name grafana --network monitoring-network \
  -v /etc/grafana/provisioning/datasources/datasource.yml:/etc/grafana/provisioning/datasources/datasource.yml \
  -v /etc/grafana/provisioning/dashboards/dashboard_provider.yml:/etc/grafana/provisioning/dashboards/dashboard_provider.yml \
  -v /var/lib/grafana/dashboards:/var/lib/grafana/dashboards \
  -p 3000:3000 --restart always \
  grafana/grafana:latest

docker run -d --name cloudwatch_exporter --network monitoring-network \
  -v /etc/prometheus/cloudwatch_exporter.yml:/config.yml \
  -p 9106:9106 --restart always \
  prom/cloudwatch-exporter:latest /config.yml

docker run -d --name open-webui --network monitoring-network \
  -e OLLAMA_BASE_URL=http://${llm_private_ip}:11434 \
  -p 80:8080 --restart always \
  ghcr.io/open-webui/open-webui:main
