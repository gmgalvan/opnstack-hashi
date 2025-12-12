# Sección 9: Alta Disponibilidad y Failover Automático

Esta sección demuestra cómo Consul maneja automáticamente el failover entre múltiples instancias de base de datos.

---

## Parte A: Script Básico de Conexión

Primero, crear un script simple en Client-1:

```bash
cat > ~/connect-db.sh <<'EOF'
#!/bin/bash

# Function to get healthy database instance
get_db_connection() {
    local db_info=$(curl -s http://localhost:8500/v1/health/service/postgres?passing)
    
    if [ $(echo "$db_info" | jq length) -eq 0 ]; then
        echo "Error: No healthy database instances available!"
        return 1
    fi
    
    DB_HOST=$(echo "$db_info" | jq -r '.[0].Node.Address')
    DB_PORT=$(echo "$db_info" | jq -r '.[0].Service.Port')
    DB_NAME=$(consul kv get myapp/database/name)
    DB_USER=$(consul kv get myapp/database/username)
    DB_PASS=$(consul kv get myapp/database/password)
    
    echo "Connecting to PostgreSQL at $DB_HOST:$DB_PORT"
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME"
}

# Call the function
get_db_connection
EOF

chmod +x ~/connect-db.sh
```

**Probar el script:**
```bash
./connect-db.sh
```

Deberías conectarte a PostgreSQL en Client-2. ✅

---

## Parte B: Agregar Base de Datos Réplica para Alta Disponibilidad

Ahora vamos a desplegar una segunda instancia de PostgreSQL en Client-1 para simular alta disponibilidad.

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

Deberías ver los 3 usuarios! ✅

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

Deberías ver **2 instancias de PostgreSQL** registradas! 🎉

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

**Verifica en el Consul UI** - deberías ver postgres con 2 instancias healthy! ✅

---

## Parte C: Demostración de Failover Automático

### 1. Verificar a cuál base de datos estás conectado actualmente:

```bash
./db-connect.sh -c "SELECT inet_server_addr() as ip, inet_server_port() as port;"
```

Verás algo como:
```
Connecting to PostgreSQL at 10.0.1.206:5432
       ip       | port 
----------------+------
 10.0.1.206     | 5432
(1 row)
```

### 2. Simular falla de la base de datos primaria:

Abre otra terminal SSH a Client-2:
```bash
ssh -i ~/.ssh/consul-key.pem ubuntu@13.218.92.220

# Detener PostgreSQL primaria
sudo docker stop postgres-db

# Verificar que se detuvo
sudo docker ps | grep postgres
```

### 3. Esperar a que Consul detecte la falla (15 segundos):

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

**Check Consul UI** - La primaria debería estar roja ❌ y la réplica verde ✅

### 4. Intentar conectar de nuevo - ¡Failover automático!:

```bash
 ./db-connect.sh -c "SELECT inet_server_addr() as ip, inet_server_port() as port;"
```

¡**Ahora debería conectar automáticamente a la réplica!** 🚀

```
Connecting to PostgreSQL at 10.0.1.60:5433
       ip       | port |        message         
----------------+------+------------------------
 10.0.1.60      | 5433 | Connected via failover!
(1 row)
```

# dtener replica para ver fallo total 
sudo docker stop postgres-db-replica

### 5. Recuperar la base de datos primaria:

```bash
# En Client-2
sudo docker start postgres-db

# Esperar 15 segundos
sleep 15

# Verificar en Client-1
curl http://localhost:8500/v1/health/service/postgres?passing | jq length
```

Deberías ver "2" - ambas instancias healthy de nuevo! ✅

---

## Parte D: Script Avanzado con Failover Inteligente

Crear un script que intenta todas las instancias disponibles:

```bash
cat > ~/db-connect-ha.sh <<'SCRIPT'
#!/bin/bash

echo "🔍 Discovering healthy PostgreSQL instances..."

# Get all healthy postgres instances
DB_INSTANCES=$(curl -s http://localhost:8500/v1/health/service/postgres?passing)
INSTANCE_COUNT=$(echo "$DB_INSTANCES" | jq length)

if [ "$INSTANCE_COUNT" -eq 0 ]; then
    echo "❌ Error: No healthy database instances available!"
    exit 1
fi

echo "✅ Found $INSTANCE_COUNT healthy database instance(s)"

# Try each instance until one works
for i in $(seq 0 $(($INSTANCE_COUNT - 1))); do
    DB_IP=$(echo "$DB_INSTANCES" | jq -r ".[$i].Node.Address")
    DB_PORT=$(echo "$DB_INSTANCES" | jq -r ".[$i].Service.Port")
    DB_ROLE=$(echo "$DB_INSTANCES" | jq -r ".[$i].Service.Meta.role // \"primary\"")
    
    echo "   [$((i+1))/$INSTANCE_COUNT] Trying $DB_ROLE at $DB_IP:$DB_PORT"
    
    # Get credentials from KV
    DB_NAME=$(consul kv get myapp/database/name)
    DB_USER=$(consul kv get myapp/database/username)
    DB_PASS=$(consul kv get myapp/database/password)
    
    # Try to connect
    export PGPASSWORD="$DB_PASS"
    if psql -h "$DB_IP" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" "$@" 2>/dev/null; then
        break
    else
        echo "   ⚠️  Connection failed, trying next instance..."
    fi
done
SCRIPT

chmod +x ~/db-connect-ha.sh
```

**Probar el script de alta disponibilidad:**
```bash
./db-connect-ha.sh -c "SELECT 
    inet_server_addr() as connected_to_ip, 
    inet_server_port() as port,
    current_database() as database,
    version() as pg_version;"
```

Deberías ver:
```
🔍 Discovering healthy PostgreSQL instances...
✅ Found 2 healthy database instance(s)
   [1/2] Trying primary at 10.0.1.206:5432
 connected_to_ip | port | database |           pg_version           
-----------------+------+----------+--------------------------------
 10.0.1.206      | 5432 | myappdb  | PostgreSQL 15.15 ...
(1 row)
```

---

## Parte E: Demostración de Múltiples Fallas

**Abrir 2 terminales:**

### Terminal 1 - Monitorear servicios en tiempo real:
```bash
watch -n 2 'echo "=== PostgreSQL Instances ===" && curl -s http://localhost:8500/v1/health/service/postgres | jq ".[] | {node: .Node.Node, ip: .Node.Address, port: .Service.Port, status: .Checks[].Status}"'
```

### Terminal 2 - Simular fallas:
```bash
# 1. Detener primaria
echo "🔴 Deteniendo primaria..."
ssh ubuntu@13.218.92.220 'sudo docker stop postgres-db'
sleep 15

# 2. Intentar conectar - debe usar réplica
echo "🟢 Conectando (debería usar réplica)..."
./db-connect-ha.sh -c "SELECT inet_server_addr(), inet_server_port();"

# 3. Detener réplica también
echo "🔴 Deteniendo réplica..."
sudo docker stop postgres-db-replica
sleep 15

# 4. Intentar conectar - no debe funcionar
echo "❌ Conectando (debería fallar)..."
./db-connect-ha.sh -c "SELECT 1;"

# 5. Levantar réplica
echo "🟢 Levantando réplica..."
sudo docker start postgres-db-replica
sleep 15

# 6. Conectar - debe funcionar con réplica
echo "🟢 Conectando (debería usar réplica)..."
./db-connect-ha.sh -c "SELECT inet_server_addr(), inet_server_port();"

# 7. Levantar primaria
echo "🟢 Levantando primaria..."
ssh ubuntu@13.218.92.220 'sudo docker start postgres-db'
sleep 15

# 8. Verificar ambas disponibles
echo "✅ Ambas instancias disponibles:"
curl -s http://localhost:8500/v1/health/service/postgres?passing | jq length
```

---

## Lo Que Acabas de Demostrar 🏆

✅ **Alta Disponibilidad**: 2 instancias de PostgreSQL en diferentes nodos  
✅ **Failover Automático**: Consul detecta fallas y redirige tráfico  
✅ **Auto-Recuperación**: Cuando un servicio vuelve, Consul lo detecta automáticamente  
✅ **Sin Cambios de Código**: La aplicación no necesita saber que hay failover  
✅ **Health Checking Continuo**: Consul monitorea constantemente (cada 10s)  
✅ **Zero Downtime**: Mientras haya una instancia healthy, la app funciona  

---

## Caso de Uso Real

Imagina una aplicación en producción:

- **Día 1**: Base de datos primaria en us-east-1a
- **Día 2**: Falla de zona - Consul automáticamente dirige tráfico a réplica en us-east-1b
- **Día 3**: Primaria se recupera - ambas instancias disponibles
- **La aplicación nunca cambió ni una línea de código** 🚀

Esto es exactamente cómo compañías como Netflix, Uber y Airbnb manejan alta disponibilidad!

---
