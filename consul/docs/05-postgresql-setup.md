# 5. Desplegar PostgreSQL en Client-2

SSH a Client-2:

## Instalar Docker

```bash
sudo apt update
sudo apt install -y docker.io postgresql-client
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu
```

## Desplegar PostgreSQL en Docker

```bash
# Ejecutar contenedor de PostgreSQL
sudo docker run -d \
  --name postgres-db \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -e POSTGRES_USER=appuser \
  -e POSTGRES_DB=myappdb \
  -p 5432:5432 \
  postgres:15

# Esperar a que inicie
sleep 5

# Verificar que está corriendo
sudo docker ps
sudo docker logs postgres-db

# Probar conexión local
PGPASSWORD=mysecretpassword psql -h localhost -U appuser -d myappdb -c "SELECT version();"
```

✅ Deberías ver la información de versión de PostgreSQL!

## Registrar PostgreSQL con Consul

```bash
sudo tee /etc/consul.d/postgres.json > /dev/null <<EOF
{
  "service": {
    "name": "postgres",
    "tags": ["database", "primary", "postgres-15"],
    "port": 5432,
    "meta": {
      "database": "myappdb",
      "version": "15"
    },
    "check": {
      "tcp": "localhost:5432",
      "interval": "10s",
      "timeout": "2s"
    }
  }
}
EOF

sudo consul reload

# Verificar registro
consul catalog services
```

🐘 **Verifica en el Consul UI** - Deberías ver el servicio "postgres"

---

[← Anterior](./04-service-discovery.md) | [Índice](./README.md) | [Siguiente →](./06-consul-kv.md)
