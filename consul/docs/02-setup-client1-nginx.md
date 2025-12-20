# 2. Setup de Servicios en Client-1 (Docker + Nginx)

## Instalar Docker

```bash
sudo apt update
sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu

# Probar Docker
sudo docker run hello-world

# Ejecutar nginx en Docker
sudo docker run -d -p 8080:80 --name web-app nginx

# Verificar que está corriendo
curl localhost:8080
```

## Registrar el servicio nginx con Consul

```bash
sudo tee /etc/consul.d/web-app.json > /dev/null <<EOF
{
  "service": {
    "name": "web-app",
    "tags": ["docker", "nginx", "frontend"],
    "port": 8080,
    "check": {
      "http": "http://localhost:8080",
      "interval": "10s",
      "timeout": "2s"
    }
  }
}
EOF

# Recargar Consul para registrar el servicio
sudo consul reload

# Verificar que el servicio está registrado
consul catalog services
```

✅ **Verifica en el Consul UI** - Deberías ver el servicio "web-app"

---

[← Anterior](./01-cluster-status.md) | [Índice](./README.md) | [Siguiente →](./03-setup-client2-python.md)
