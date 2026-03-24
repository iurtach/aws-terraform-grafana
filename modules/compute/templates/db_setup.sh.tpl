#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# PostgreSQL, pgvector, postgres-exporter, and node-exporter are
# pre-installed by the Packer AMI. This script only configures them.

systemctl enable postgresql
systemctl start postgresql

# Wait for PostgreSQL to accept connections
until sudo -u postgres psql -c '\q' 2>/dev/null; do
  echo "Waiting for PostgreSQL to start..."
  sleep 2
done

# Create application user, database, and enable pgvector extension
sudo -u postgres psql -c "CREATE USER admin WITH PASSWORD '${db_password}';"
sudo -u postgres psql -c "CREATE DATABASE llm_test_db OWNER admin;"
sudo -u postgres psql -d llm_test_db -c "CREATE EXTENSION IF NOT EXISTS vector;"

# Configure postgres-exporter with the connection string
mkdir -p /etc/systemd/system/prometheus-postgres-exporter.service.d
cat > /etc/systemd/system/prometheus-postgres-exporter.service.d/override.conf <<'EOT'
[Service]
Environment="DATA_SOURCE_NAME=postgresql://admin:${db_password}@localhost:5432/llm_test_db?sslmode=disable"
EOT

systemctl daemon-reload
systemctl enable prometheus-postgres-exporter
systemctl start prometheus-postgres-exporter

systemctl enable prometheus-node-exporter
systemctl start prometheus-node-exporter
