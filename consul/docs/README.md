# Consul Training Guide

Guía completa para aprender Consul: service discovery, health checks, KV store y alta disponibilidad.

## 📚 Contenido

| # | Archivo | Descripción |
|---|---------|-------------|
| 1 | [01-cluster-status.md](./01-cluster-status.md) | Verificar estado del cluster y liderazgo |
| 2 | [02-setup-client1-nginx.md](./02-setup-client1-nginx.md) | Setup de Docker + Nginx en Client-1 |
| 3 | [03-setup-client2-python.md](./03-setup-client2-python.md) | Setup de Python HTTP Server en Client-2 |
| 4 | [04-service-discovery.md](./04-service-discovery.md) | Pruebas de Service Discovery |
| 5 | [05-postgresql-setup.md](./05-postgresql-setup.md) | Desplegar PostgreSQL en Client-2 |
| 6 | [06-consul-kv.md](./06-consul-kv.md) | Configuración en Consul KV Store |
| 7 | [07-connect-from-client1.md](./07-connect-from-client1.md) | Conectar a PostgreSQL desde Client-1 |
| 8 | [08-health-checks.md](./08-health-checks.md) | Health Checks y detección de fallas |
| 9 | [09-high-availability.md](./09-high-availability.md) | Alta Disponibilidad y Failover Automático |
| 10 | [10-query-services.md](./10-query-services.md) | Consultar todos los servicios |
| 11 | [11-watch-mode.md](./11-watch-mode.md) | Modo Watch (actualizaciones en vivo) |
| 12 | [12-summary-cleanup.md](./12-summary-cleanup.md) | Resumen y limpieza |

## 🎯 Lo que aprenderás

- ✅ **Service Registration**: Registrar servicios con Consul
- ✅ **Service Discovery**: Encontrar servicios via DNS y HTTP API
- ✅ **Health Checking**: Detección automática de fallas
- ✅ **Key-Value Store**: Almacenar configuración
- ✅ **Alta Disponibilidad**: Failover automático entre instancias

## 🏗️ Arquitectura

```
┌─────────────────┐     ┌─────────────────┐
│    Client-1     │     │    Client-2     │
│  ┌───────────┐  │     │  ┌───────────┐  │
│  │   Nginx   │  │     │  │ PostgreSQL│  │
│  │  :8080    │  │     │  │   :5432   │  │
│  └───────────┘  │     │  └───────────┘  │
│  ┌───────────┐  │     │  ┌───────────┐  │
│  │ PG Replica│  │     │  │ Python API│  │
│  │  :5433    │  │     │  │   :9090   │  │
│  └───────────┘  │     │  └───────────┘  │
└────────┬────────┘     └────────┬────────┘
         │                       │
         └───────────┬───────────┘
                     │
              ┌──────┴──────┐
              │   Consul    │
              │  Cluster    │
              └─────────────┘
```

## 💰 Limpieza

Cuando termines, no olvides destruir la infraestructura:

```bash
terraform destroy
```

Esto evita cargos de ~$42/mes.


### Notas adicionales

Para ejecutar un agente de consul con un archivo de configuración específico, usa el siguiente comando:
```bash
consul agent -config-file=/opt/consul/config.hcl
```

Normalmente consul es ejecutado como un servicio gestionado por systemd, pero para propósitos de aprendizaje y pruebas, ejecutarlo manualmente es adecuado.
systemd es más adecuado para entornos de producción.
windows server manager para sevidores windows.

Para un agente en modo dev server se usa:
```bash
consul agent -dev
```
