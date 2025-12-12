output "consul_server_ips" {
  description = "Public IP addresses of Consul servers"
  value = {
    for idx, instance in aws_instance.consul_server :
    "server-${idx + 1}" => {
      public_ip  = instance.public_ip
      private_ip = instance.private_ip
    }
  }
}

output "consul_client_ips" {
  description = "Public IP addresses of Consul clients"
  value = {
    for idx, instance in aws_instance.consul_client :
    "client-${idx + 1}" => {
      public_ip  = instance.public_ip
      private_ip = instance.private_ip
    }
  }
}

output "consul_ui_urls" {
  description = "Consul UI URLs (accessible from any server)"
  value = [
    for instance in aws_instance.consul_server :
    "http://${instance.public_ip}:8500"
  ]
}

output "consul_encrypt_key" {
  description = "Consul gossip encryption key"
  value       = random_id.consul_encrypt.b64_std
  sensitive   = true
}

output "ssh_connection_strings" {
  description = "SSH connection commands"
  value = merge(
    {
      for idx, instance in aws_instance.consul_server :
      "server-${idx + 1}" => "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${instance.public_ip}"
    },
    {
      for idx, instance in aws_instance.consul_client :
      "client-${idx + 1}" => "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${instance.public_ip}"
    }
  )
}
