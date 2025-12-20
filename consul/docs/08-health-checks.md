# 8. Test Health Checks y Detección de Fallas

## Detener PostgreSQL y ver cómo Consul lo detecta

En Client-2:

```bash
# Detener el contenedor de PostgreSQL
sudo docker stop postgres-db

# Esperar 10-15 segundos
sleep 15

# Verificar salud del servicio
consul catalog services
curl http://localhost:8500/v1/health/service/postgres | jq
```

❌ **Verifica en el Consul UI** - PostgreSQL debería mostrarse como "failing"

## Desde Client-1, intentar descubrirlo

```bash
# Esto retornará vacío porque no hay instancias healthy
curl http://localhost:8500/v1/health/service/postgres?passing | jq

# ¡Esta query retornaría vacío, previniendo conexión a servicio fallido!
```

🛡️ **¡Este es el poder de los health checks!** Tu aplicación no intentará conectarse a una base de datos muerta.

## Reiniciar PostgreSQL

```bash
# En Client-2
sudo docker start postgres-db

# Esperar 10-15 segundos
sleep 15

# Verificar salud
curl http://localhost:8500/v1/health/service/postgres?passing | jq
```

✅ **Verifica en el Consul UI** - ¡Debería volver a verde!

---

[← Anterior](./07-connect-from-client1.md) | [Índice](./README.md) | [Siguiente →](./09-high-availability.md)
