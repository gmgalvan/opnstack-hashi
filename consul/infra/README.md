# Consul Cluster on AWS with Terraform

This Terraform configuration deploys a Consul cluster on AWS with 3 server nodes and 2 client nodes using EC2 t2.micro instances.

## Architecture

- **3 Consul Servers**: Form the consensus cluster using Raft protocol
- **2 Consul Clients**: Lightweight agents for service discovery and registration
- **AWS Cloud Auto-Join**: Automatic cluster formation using EC2 tags
- **Gossip Encryption**: Secure inter-node communication
- **UI Enabled**: Web interface available on all server nodes

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** installed (v1.0+)
3. **AWS CLI** configured with credentials
4. **EC2 Key Pair** created in your target region

## Quick Start

### 1. Clone and Configure

```bash
# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars and set your key_name
# key_name = "your-aws-key-pair-name"
```

### 2. Deploy

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

The deployment takes about 5-10 minutes. Instances will automatically install Consul and join the cluster.

### 3. Access the Cluster

After deployment, Terraform will output:
- Server and client IP addresses
- Consul UI URLs
- SSH connection strings

```bash
# View outputs
terraform output

# View the encryption key (keep this secure)
terraform output -raw consul_encrypt_key
```

## Accessing the Consul UI

Open any of the server URLs in your browser:
```
http://<server-public-ip>:8500
```

You'll see the Consul dashboard with all nodes and services.

## SSH into Instances

```bash
# SSH into a server
ssh -i ~/.ssh/your-key.pem ubuntu@<server-public-ip>

# Check Consul status
consul members
consul operator raft list-peers
```

## Testing the Cluster

### 1. Check Cluster Members

SSH into any node and run:
```bash
consul members
```

You should see all 5 nodes (3 servers, 2 clients).

### 2. Register a Service (on a client node)

```bash
# Create a service definition
sudo tee /etc/consul.d/web.json > /dev/null <<EOF
{
  "service": {
    "name": "web",
    "tags": ["rails"],
    "port": 80,
    "check": {
      "args": ["curl", "localhost"],
      "interval": "10s"
    }
  }
}
EOF

# Reload Consul
consul reload
```

### 3. Query the Service

```bash
# DNS query
dig @127.0.0.1 -p 8600 web.service.consul

# HTTP API
curl http://localhost:8500/v1/catalog/service/web
```

### 4. Use Key-Value Store

```bash
# Put a value
consul kv put my-app/config/db-addr "10.0.1.100"

# Get a value
consul kv get my-app/config/db-addr

# List keys
consul kv get -recurse my-app/
```

## Network Ports

The security group allows:
- **22**: SSH access
- **8300**: Server RPC (server-to-server)
- **8301**: Serf LAN (all nodes)
- **8302**: Serf WAN (servers)
- **8500**: HTTP API (public)
- **8600**: DNS

## File Structure

```
consul-terraform/
├── main.tf                    # Main infrastructure
├── variables.tf               # Variable definitions
├── outputs.tf                 # Output values
├── terraform.tfvars.example   # Example variables
├── scripts/
│   ├── consul_server.sh      # Server bootstrap script
│   └── consul_client.sh      # Client bootstrap script
└── README.md
```

## Configuration Details

### Server Configuration
- Bootstrap expects 3 servers
- Raft consensus protocol
- UI enabled
- Cloud auto-join using AWS tags

### Client Configuration
- Connects to servers via cloud auto-join
- Lightweight agent for service registration
- No data persistence required

## Cost Estimate

With t2.micro instances in us-east-1:
- 5 instances × $0.0116/hour = ~$0.058/hour
- ~$42/month if running 24/7

**Remember to destroy resources when done testing!**

## Cleanup

```bash
# Destroy all resources
terraform destroy
```

## Troubleshooting

### Nodes not joining cluster

```bash
# Check Consul logs
sudo journalctl -u consul -f

# Verify network connectivity
curl http://169.254.169.254/latest/meta-data/local-ipv4

# Check if Consul is running
sudo systemctl status consul
```

### Can't access UI

- Verify security group allows inbound on port 8500
- Check that Consul is running: `sudo systemctl status consul`
- Ensure you're using the public IP, not private IP

### AWS Permissions Issues

The IAM role needs:
- `ec2:DescribeInstances`
- `ec2:DescribeTags`

## Next Steps

1. **Enable ACLs**: Secure your cluster with access control
2. **Add More Services**: Register applications on client nodes
3. **Service Mesh**: Configure Consul Connect for service-to-service encryption
4. **Health Checks**: Add custom health checks for your services
5. **Multi-DC**: Set up WAN federation with another datacenter

## Security Considerations

This is a **development setup**. For production:

1. Enable ACLs with proper tokens
2. Use TLS for all communication
3. Restrict security group rules (especially SSH and UI)
4. Use private subnets with NAT gateway
5. Enable encryption at rest for data
6. Implement proper backup and disaster recovery

## Resources

- [Consul Documentation](https://www.consul.io/docs)
- [Consul on AWS](https://learn.hashicorp.com/collections/consul/cloud-production)
- [Service Discovery Guide](https://learn.hashicorp.com/tutorials/consul/get-started-service-discovery)

## License

This is example code for learning purposes.
