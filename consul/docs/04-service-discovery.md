# 4. Test Service Discovery (¡La magia de Consul! 🎩✨)

Desde Client-1, descubrir y llamar al servicio en Client-2:

## Método 1: DNS Discovery

```bash
dig @127.0.0.1 -p 8600 test-api.service.consul
```

## Método 2: DNS con A record (solo IP)

```bash
dig @127.0.0.1 -p 8600 test-api.service.consul A +short
```

## Método 3: HTTP API Discovery

```bash
curl http://localhost:8500/v1/catalog/service/test-api | jq
```

## Método 4: Obtener solo instancias healthy

```bash
curl http://localhost:8500/v1/health/service/test-api?passing | jq
```

## Método 5: Obtener dirección programáticamente y llamar

```bash
SERVICE_IP=$(curl -s http://localhost:8500/v1/health/service/test-api?passing | jq -r '.[0].Node.Address')
echo "test-api está corriendo en: $SERVICE_IP"

# Conectar
curl http://$SERVICE_IP:9090/index.json
```

🎉 **Resultado esperado:** Deberías obtener la respuesta JSON de Client-2!

---

[← Anterior](./03-setup-client2-python.md) | [Índice](./README.md) | [Siguiente →](./05-postgresql-setup.md)
