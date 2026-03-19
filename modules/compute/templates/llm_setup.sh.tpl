#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

wget https://github.com/prometheus/node_exporter/releases/download/v1.10.2/node_exporter-1.10.2.linux-amd64.tar.gz
tar xvf node_exporter-1.10.2.linux-amd64.tar.gz
cp node_exporter-1.10.2.linux-amd64/node_exporter /usr/local/bin/

cat <<'EOT' > /etc/systemd/system/node_exporter.service
[Unit]
  Description=Node Exporter
  After=network.target

[Service]
  User=ubuntu
  ExecStart=/usr/local/bin/node_exporter
  Restart=always

[Install]
  WantedBy=multi-user.target
EOT


mkdir -p /etc/systemd/system/ollama.service.d
cat <<'EOT' > /etc/systemd/system/ollama.service.d/override.conf
[Service]
  Environment="OLLAMA_HOST=0.0.0.0"
EOT

systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter
systemctl restart ollama