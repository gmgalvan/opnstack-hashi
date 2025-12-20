# 3. Setup de Servicio en Client-2 (Python HTTP Server)

SSH a Client-2 y ejecutar:

## Iniciar Python HTTP Server

```bash
# Crear una página HTML simple
mkdir -p ~/api
cd ~/api
echo '{"status": "ok", "message": "Hello from Client-2!"}' > index.json

# Iniciar HTTP server en background
nohup python3 -m http.server 9090 > /dev/null 2>&1 &

# Verificar que está corriendo
curl localhost:9090/index.json
```

## Registrar con Consul

```bash
sudo tee /etc/consul.d/test-api.json > /dev/null <<EOF
{
  "service": {
    "name": "test-api",
    "tags": ["python", "backend", "api"],
    "port": 9090,
    "check": {
      "http": "http://localhost:9090/index.json",
      "interval": "10s",
      "timeout": "2s"
    }
  }
}
EOF

sudo consul reload

# Verificar
consul catalog services
```

✅ **Verifica en el Consul UI** - Deberías ver el servicio "test-api"

---

[← Anterior](./02-setup-client1-nginx.md) | [Índice](./README.md) | [Siguiente →](./04-service-discovery.md)
