#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting user_data script..."

apt-get update

until apt-get update; do
  echo "Waiting for apt lock..."
  sleep 5
done

apt-get install -y docker.io

systemctl start docker
systemctl enable docker

sleep 10 # Wait for Docker to be fully up and running

echo "Pulling docker images..."
docker pull postgres:latest
docker pull prometheuscommunity/postgres-exporter:latest
docker pull prom/node-exporter:latest

# Run Postgres container
docker run -d --name postgres --network host \
  -e POSTGRES_PASSWORD=${db_password} \
  -e POSTGRES_USER=admin \
  -e POSTGRES_DB=llm_test_db \
  --restart always \
  postgres:latest

# Run Postgres Exporter
docker run -d --name postgres_exporter --network host \
  -e DATA_SOURCE_NAME="postgresql://admin:${db_password}@localhost:5432/llm_test_db?sslmode=disable" \
  --restart always \
  prometheuscommunity/postgres-exporter:latest

# Run Node Exporter
docker run -d --name node_exporter --network host \
  --restart always \
  prom/node-exporter:latest