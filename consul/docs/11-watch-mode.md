# 11. Watch Mode (Actualizaciones en Vivo)

Abre **dos terminales** a Client-1:

## Watch para cambios de servicio

**Terminal 1** - Observar cambios en la base de datos:

```bash
consul watch -type=service -service=postgres
```

**Terminal 2** - En Client-2, reiniciar la base de datos:

```bash
sudo docker restart postgres-db
```

📡 ¡Terminal 1 mostrará actualizaciones en vivo cuando el servicio suba y baje!

---

## Watch para cambios en KV

**Terminal 1:**

```bash
consul watch -type=key -key=myapp/database/host
```

**Terminal 2:**

```bash
consul kv put myapp/database/host "10.0.1.250"
```

⚡ ¡Verás el cambio inmediatamente!

---

[← Anterior](./10-query-services.md) | [Índice](./README.md) | [Siguiente →](./12-summary-cleanup.md)
