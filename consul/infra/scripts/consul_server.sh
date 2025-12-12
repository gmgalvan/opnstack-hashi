#!/bin/bash
set -e

# Update system
apt-get update
apt-get install -y unzip jq

# Install Consul
CONSUL_VERSION="${consul_version}"
cd /tmp
curl -O "https://releases.hashicorp.com/consul/$${CONSUL_VERSION}/consul_$${CONSUL_VERSION}_linux_amd64.zip"
unzip "consul_$${CONSUL_VERSION}_linux_amd64.zip"
mv consul /usr/local/bin/
chmod +x /usr/local/bin/consul

# Create Consul user
useradd --system --home /etc/consul.d --shell /bin/false consul

# Create directories
mkdir -p /opt/consul/data
mkdir -p /etc/consul.d
chown -R consul:consul /opt/consul /etc/consul.d

# Get instance metadata
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

# Create Consul server configuration
cat > /etc/consul.d/consul.hcl <<EOF
datacenter = "${datacenter}"
data_dir = "/opt/consul/data"
encrypt = "${encrypt_key}"
log_level = "INFO"
node_name = "$INSTANCE_ID"

# Server configuration
server = true
bootstrap_expect = ${server_count}

# Bind addresses
bind_addr = "$PRIVATE_IP"
client_addr = "0.0.0.0"
advertise_addr = "$PRIVATE_IP"

# UI
ui_config {
  enabled = true
}

# Performance
performance {
  raft_multiplier = 1
}

# Retry join using AWS cloud auto-join
retry_join = ["provider=aws tag_key=ConsulRole tag_value=server"]

# ACL (disabled for simplicity)
acl {
  enabled = false
  default_policy = "allow"
  enable_token_persistence = true
}
EOF

chown consul:consul /etc/consul.d/consul.hcl
chmod 640 /etc/consul.d/consul.hcl

# Create systemd service
cat > /etc/systemd/system/consul.service <<'EOF'
[Unit]
Description=Consul Service Discovery Agent
Documentation=https://www.consul.io/
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
User=consul
Group=consul
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d/
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
KillSignal=SIGTERM
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# Enable and start Consul
systemctl daemon-reload
systemctl enable consul
systemctl start consul

# Wait for Consul to start
sleep 10

echo "Consul server installation complete!"
