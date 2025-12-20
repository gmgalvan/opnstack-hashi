# 7. Conectar a PostgreSQL desde Client-1

SSH a Client-1:

## Instalar cliente PostgreSQL

```bash
sudo apt update
sudo apt install -y postgresql-client
```

## Método 1: Descubrir via Consul HTTP API + KV Store

```bash
# Obtener info de DB dinámicamente desde service discovery
DB_IP=$(curl -s http://localhost:8500/v1/health/service/postgres?passing | jq -r '.[0].Node.Address')
DB_PORT=$(curl -s http://localhost:8500/v1/health/service/postgres?passing | jq -r '.[0].Service.Port')

# Obtener credenciales desde Consul KV store
DB_NAME=$(consul kv get myapp/database/name)
DB_USER=$(consul kv get myapp/database/username)
DB_PASS=$(consul kv get myapp/database/password)

echo "PostgreSQL descubierto en: $DB_IP:$DB_PORT"

# Conectar usando valores descubiertos
PGPASSWORD="$DB_PASS" psql \
  -h "$DB_IP" \
  -p "$DB_PORT" \
  -U "$DB_USER" \
  -d "$DB_NAME" \
  -c "SELECT version();"
```

✅ Deberías ver la versión de PostgreSQL!

### ¿Qué acaba de pasar?

- 🔍 **Service Discovery**: Encontró la ubicación de PostgreSQL dinámicamente
- 🔑 **KV Store**: Obtuvo credenciales de forma segura
- ✅ **Health Check**: Solo conectó a instancias healthy
- 🚫 **Sin IPs hardcodeadas**: ¡Todo descubierto via Consul!

---

## Método 2: Script de Conexión Reutilizable

```bash
cat > ~/db-connect.sh <<'SCRIPT'
#!/bin/bash

echo "🔍 Descubriendo base de datos via Consul..."

# Encontrar instancia healthy de postgres
DB_INFO=$(curl -s http://localhost:8500/v1/health/service/postgres?passing)

if [ $(echo "$DB_INFO" | jq length) -eq 0 ]; then
    echo "❌ Error: ¡No hay instancias de PostgreSQL healthy!"
    exit 1
fi

# Obtener detalles de conexión desde service discovery
DB_IP=$(echo "$DB_INFO" | jq -r '.[0].Node.Address')
DB_PORT=$(echo "$DB_INFO" | jq -r '.[0].Service.Port')

# Obtener credenciales desde Consul KV
DB_NAME=$(consul kv get myapp/database/name)
DB_USER=$(consul kv get myapp/database/username)
DB_PASS=$(consul kv get myapp/database/password)

echo "✅ PostgreSQL encontrado en: $DB_IP:$DB_PORT"
echo "   Base de datos: $DB_NAME"
echo "   Usuario: $DB_USER"
echo ""

# Conectar
export PGPASSWORD="$DB_PASS"
psql -h "$DB_IP" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" "$@"
SCRIPT

chmod +x ~/db-connect.sh
```

### Probar el script

```bash
# Conexión interactiva
./db-connect.sh

# Ejecutar una sola query
./db-connect.sh -c "SELECT version();"

# Salir con \q o Ctrl+D
```

---

## Crear Datos de Prueba

```bash
# Obtener toda la info de conexión desde Consul
DB_IP=$(curl -s http://localhost:8500/v1/health/service/postgres?passing | jq -r '.[0].Node.Address')
DB_PORT=$(curl -s http://localhost:8500/v1/health/service/postgres?passing | jq -r '.[0].Service.Port')
DB_NAME=$(consul kv get myapp/database/name)
DB_USER=$(consul kv get myapp/database/username)
DB_PASS=$(consul kv get myapp/database/password)

# Crear tabla e insertar datos
PGPASSWORD="$DB_PASS" psql -h "$DB_IP" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'SQL'
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users (username, email) VALUES 
    ('alice', 'alice@example.com'),
    ('bob', 'bob@example.com'),
    ('charlie', 'charlie@example.com');

SELECT * FROM users;
SQL
```

Deberías ver:
```
CREATE TABLE
INSERT 0 3
 id | username |        email        |         created_at         
----+----------+---------------------+----------------------------
  1 | alice    | alice@example.com   | 2025-12-12 18:30:45.123456
  2 | bob      | bob@example.com     | 2025-12-12 18:30:45.123456
  3 | charlie  | charlie@example.com | 2025-12-12 18:30:45.123456
(3 rows)
```

### Consultar info de la base de datos

```bash
./db-connect.sh -c "
SELECT 
    current_database() as database,
    current_user as user,
    inet_server_addr() as server_ip,
    inet_server_port() as server_port;
"
```

---

[← Anterior](./06-consul-kv.md) | [Índice](./README.md) | [Siguiente →](./08-health-checks.md)
