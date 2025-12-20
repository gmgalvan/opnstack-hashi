# 6. Almacenar Configuración en Consul KV

En Client-2 (o cualquier nodo):

## Guardar configuración de base de datos

```bash
# Obtener la IP privada de Client-2 (donde corre Postgres)
POSTGRES_IP=$(hostname -I | awk '{print $1}')
echo "PostgreSQL está corriendo en: $POSTGRES_IP"

# Almacenar configuración real en Consul KV
consul kv put myapp/database/host "$POSTGRES_IP"
consul kv put myapp/database/port "5432"
consul kv put myapp/database/name "myappdb"
consul kv put myapp/database/username "appuser"
consul kv put myapp/database/password "mysecretpassword"
consul kv put myapp/database/connection-string "postgresql://appuser:mysecretpassword@$POSTGRES_IP:5432/myappdb"

# Verificar almacenamiento
consul kv get -recurse myapp/database/
```

🔑 **Verifica en el Consul UI** → "Key/Value" - ¡Ve tu configuración de base de datos!

---

[← Anterior](./05-postgresql-setup.md) | [Índice](./README.md) | [Siguiente →](./07-connect-from-client1.md)
