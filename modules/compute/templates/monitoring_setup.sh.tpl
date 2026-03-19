#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
apt-get update

until apt-get update; do
  echo "Waiting for apt lock..."
  sleep 5
done

apt-get install -y docker.io

systemctl start docker
systemctl enable docker

sleep 10

docker pull prom/prometheus:latest
docker pull prom/alertmanager:latest
docker pull grafana/grafana:latest
docker pull prom/blackbox-exporter:latest
docker pull prom/cloudwatch-exporter:latest
docker pull ghcr.io/open-webui/open-webui:main

docker network create monitoring-network || true

mkdir -p /etc/prometheus /etc/alertmanager /etc/blackbox
mkdir -p /etc/grafana/provisioning/datasources /etc/grafana/provisioning/dashboards
mkdir -p /var/lib/grafana/dashboards

cat <<'EOT' > /etc/prometheus/prometheus.yml
${prometheus_config}
EOT
cat <<'EOT' > /etc/blackbox/blackbox.yml
${blackbox_config}
EOT
cat <<'EOT' > /etc/prometheus/alert_rules.yml
${alert_rules}
EOT
cat <<'EOT' > /etc/alertmanager/alertmanager.yml
${alertmanager_config}
EOT
cat <<'EOT' > /etc/prometheus/cloudwatch_exporter.yml
${cloudwatch_exporter}
EOT

curl -L https://grafana.com/api/dashboards/9628/revisions/7/download -o /var/lib/grafana/dashboards/postgres-exporter.json
curl -sL https://grafana.com/api/dashboards/1860/revisions/37/download -o /var/lib/grafana/dashboards/node-exporter.json

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
  - name: 'node-exporter-dash'
    orgId: 1
    folder: 'System Metrics'
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /var/lib/grafana/dashboards
EOT

chown -R 472:472 /etc/grafana /var/lib/grafana
chown -R 472:472 /etc/grafana/provisioning

docker rm -f prometheus alertmanager cloudwatch_exporter blackbox-exporter grafana open-webui || true

docker run -d --name blackbox-exporter --network monitoring-network --network-alias blackbox-exporter \
  -v /etc/blackbox/blackbox.yml:/etc/blackbox_exporter/config.yml -p 9115:9115 prom/blackbox-exporter:latest

docker run -d -p 80:8080 --name open-webui --network monitoring-network --restart always \
  -e OLLAMA_BASE_URL=http://${llm_private_ip}:11434 ghcr.io/open-webui/open-webui:main

docker run -d --name prometheus --network monitoring-network -p 9090:9090 \
  -v /etc/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
  -v /etc/prometheus/alert_rules.yml:/etc/prometheus/alert_rules.yml \
  --restart always prom/prometheus:latest

docker run -d --name alertmanager --network monitoring-network -p 9093:9093 \
  -v /etc/alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml \
  --restart always prom/alertmanager:latest

docker run -d -p 3000:3000 --name grafana --network monitoring-network --restart always \
  -v /etc/grafana/provisioning/datasources/datasource.yml:/etc/grafana/provisioning/datasources/datasource.yml \
  -v /etc/grafana/provisioning/dashboards/dashboard_provider.yml:/etc/grafana/provisioning/dashboards/dashboard_provider.yml \
  -v /var/lib/grafana/dashboards:/var/lib/grafana/dashboards grafana/grafana:latest

docker run -d --name cloudwatch_exporter --network monitoring-network -p 9106:9106 \
  -v /etc/prometheus/cloudwatch_exporter.yml:/config.yml \
  --restart always prom/cloudwatch-exporter:latest /config.yml