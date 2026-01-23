# 9. Alta Disponibilidad y Failover Automático

Esta sección demuestra cómo Consul maneja automáticamente el failover entre múltiples instancias de base de datos.

---

## Parte A: Script Básico de Conexión

Crear un script simple en Client-1:

```bash
cat > ~/connect-db.sh <<'EOF'
#!/bin/bash

# Función para obtener instancia de DB healthy
get_db_connection() {
    local db_info=$(curl -s http://localhost:8500/v1/health/service/postgres?passing)
    
    if [ $(echo "$db_info" | jq length) -eq 0 ]; then
        echo "Error: ¡No hay instancias de base de datos disponibles!"
        return 1
    fi
    
    DB_HOST=$(echo "$db_info" | jq -r '.[0].Node.Address')
    DB_PORT=$(echo "$db_info" | jq -r '.[0].Service.Port')
    DB_NAME=$(consul kv get myapp/database/name)
    DB_USER=$(consul kv get myapp/database/username)
    DB_PASS=$(consul kv get myapp/database/password)
    
    echo "Conectando a PostgreSQL en $DB_HOST:$DB_PORT"
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME"
}

# Llamar la función
get_db_connection
EOF

chmod +x ~/connect-db.sh
```

**Probar el script:**
```bash
./connect-db.sh
```

✅ Deberías conectarte a PostgreSQL en Client-2.

---

## Parte B: Agregar Base de Datos Réplica

Desplegar una segunda instancia de PostgreSQL en Client-1 para simular alta disponibilidad.

**En Client-1:**

```bash
# Desplegar PostgreSQL réplica
sudo docker run -d \
  --name postgres-db-replica \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -e POSTGRES_USER=appuser \
  -e POSTGRES_DB=myappdb \
  -p 5433:5432 \
  postgres:15

# Esperar a que inicie
sleep 5

# Verificar que está corriendo
sudo docker ps | grep postgres
PGPASSWORD=mysecretpassword psql -h localhost -p 5433 -U appuser -d myappdb -c "SELECT version();"
```

**Crear los mismos datos en la réplica:**

```bash
PGPASSWORD=mysecretpassword psql -h localhost -p 5433 -U appuser -d myappdb <<'SQL'
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

✅ Deberías ver los 3 usuarios!

**Registrar la réplica con Consul:**

```bash
sudo tee /etc/consul.d/postgres-replica.json > /dev/null <<EOF
{
  "service": {
    "name": "postgres",
    "tags": ["database", "replica", "postgres-15"],
    "port": 5433,
    "meta": {
      "database": "myappdb",
      "version": "15",
      "role": "replica"
    },
    "check": {
      "tcp": "localhost:5433",
      "interval": "10s",
      "timeout": "2s"
    }
  }
}
EOF

sudo consul reload
```

**Verificar ambas instancias:**

```bash
# Ver servicios registrados
consul catalog services

# Ver ambas instancias de postgres
curl http://localhost:8500/v1/health/service/postgres?passing | jq '.[] | {node: .Node.Node, ip: .Node.Address, port: .Service.Port, role: .Service.Meta.role}'
```

🎉 Deberías ver **2 instancias de PostgreSQL** registradas!

Ejemplo de salida:
```json
{
  "node": "i-0b32ec5c3a35b6a58",
  "ip": "10.0.1.206",
  "port": 5432,
  "role": null
}
{
  "node": "i-02ba9df94ed8ed144",
  "ip": "10.0.1.60",
  "port": 5433,
  "role": "replica"
}
```

✅ **Verifica en el Consul UI** - deberías ver postgres con 2 instancias healthy!

---

## Parte C: Demostración de Failover Automático

### 1. Verificar a cuál base de datos estás conectado

```bash
./connect-db.sh -c "SELECT inet_server_addr() as ip, inet_server_port() as port;"
```

Verás algo como:
```
Connecting to PostgreSQL at 10.0.1.206:5432
       ip       | port 
----------------+------
 10.0.1.206     | 5432
(1 row)
```

### 2. Simular falla de la base de datos primaria

Abre otra terminal SSH a Client-2:

```bash
ssh -i ~/.ssh/consul-key.pem ubuntu@<CLIENT-2-IP>

# Detener PostgreSQL primaria
sudo docker stop postgres-db

# Verificar que se detuvo
sudo docker ps | grep postgres
```

### 3. Esperar a que Consul detecte la falla (15 segundos)

```bash
# En Client-1
sleep 15

# Ver el estado de los servicios
curl http://localhost:8500/v1/health/service/postgres | jq '.[] | {node: .Node.Node, port: .Service.Port, status: .Checks[].Status}'
```

Deberías ver una instancia "passing" y otra "critical":
```json
{
  "node": "i-0b32ec5c3a35b6a58",
  "port": 5432,
  "status": "critical"
}
{
  "node": "i-02ba9df94ed8ed144",
  "port": 5433,
  "status": "passing"
}
```

❌✅ **Check Consul UI** - La primaria debería estar roja y la réplica verde

### 4. Intentar conectar de nuevo - ¡Failover automático!

```bash
./connect-db.sh -c "SELECT inet_server_addr() as ip, inet_server_port() as port;"
```

🚀 **¡Ahora debería conectar automáticamente a la réplica!**

```
Connecting to PostgreSQL at 10.0.1.60:5433
       ip       | port 
----------------+------
 10.0.1.60      | 5433
(1 row)
```

### 5. (Opcional) Detener réplica para ver fallo total

```bash
sudo docker stop postgres-db-replica
```

### 6. Recuperar la base de datos primaria

```bash
# En Client-2
sudo docker start postgres-db

# Esperar 15 segundos
sleep 15

# Verificar en Client-1
curl http://localhost:8500/v1/health/service/postgres?passing | jq length
```

✅ Deberías ver "2" - ¡ambas instancias healthy de nuevo!

---

[← Anterior](./08-health-checks.md) | [Índice](./README.md) | [Siguiente →](./10-query-services.md)
