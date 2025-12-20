# 10. Consultar Todos los Servicios

## Listar todos los servicios registrados

```bash
consul catalog services
```

## Obtener detalles de cada servicio

```bash
curl http://localhost:8500/v1/catalog/service/web-app | jq
curl http://localhost:8500/v1/catalog/service/postgres | jq
curl http://localhost:8500/v1/catalog/service/test-api | jq
```

## Obtener solo instancias healthy de cada servicio

```bash
curl http://localhost:8500/v1/health/service/web-app?passing | jq '.[].Service.Port'
curl http://localhost:8500/v1/health/service/postgres?passing | jq '.[].Service.Port'
```

## Contar instancias por servicio

```bash
echo "web-app instances: $(curl -s http://localhost:8500/v1/health/service/web-app?passing | jq 'length')"
echo "postgres instances: $(curl -s http://localhost:8500/v1/health/service/postgres?passing | jq 'length')"
echo "test-api instances: $(curl -s http://localhost:8500/v1/health/service/test-api?passing | jq 'length')"
```

---

[← Anterior](./09-high-availability.md) | [Índice](./README.md) | [Siguiente →](./11-watch-mode.md)
