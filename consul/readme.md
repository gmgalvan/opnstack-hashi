# Consul Training Guide

## 1. Check Cluster Status & Leadership

On any server or client:
```bash
# See all nodes
consul members

# Check which server is the leader
consul operator raft list-peers
```

---

## 2. Setup Services on Client-1 (Docker + Nginx)

SSH into Client-1:
```bash
ssh -i ~/.ssh/consul-key.pem ubuntu@3.236.91.47
```

Install Docker:
```bash
sudo apt update
sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu

# Test Docker
sudo docker run hello-world

# Run nginx in Docker
sudo docker run -d -p 8080:80 --name web-app nginx

# Verify it's running locally
curl localhost:8080
```

** Register the nginx service with Consul:**
```bash
sudo tee /etc/consul.d/web-app.json > /dev/null <<EOF
{
  "service": {
    "name": "web-app",
    "tags": ["docker", "nginx", "frontend"],
    "port": 8080,
    "check": {
      "http": "http://localhost:8080",
      "interval": "10s",
      "timeout": "2s"
    }
  }
}
EOF

# Reload Consul to register the service
sudo consul reload

# Verify service is registered
consul catalog services
```

**Check the Consul UI** - You should now see "web-app" service! ✅

---

## 3. Setup Service on Client-2 (Python HTTP Server)

SSH into Client-2:
```bash
ssh -i ~/.ssh/consul-key.pem ubuntu@13.218.92.220
```

Start Python HTTP server:
```bash
# Create a simple HTML page
mkdir -p ~/api
cd ~/api
echo '{"status": "ok", "message": "Hello from Client-2!"}' > index.json

# Start HTTP server in background
nohup python3 -m http.server 9090 > /dev/null 2>&1 &

# Verify it's running
curl localhost:9090/index.json
```

Register with Consul:
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

# Verify
consul catalog services
```

**Check the Consul UI** - You should now see "test-api" service! ✅

---

## 4. Test Service Discovery (The Consul Magic! 🎩✨)

### From Client-1, discover and call the service on Client-2:
```bash
# Method 1: DNS Discovery
dig @127.0.0.1 -p 8600 test-api.service.consul

# Method 2: DNS with A record (just IP)
dig @127.0.0.1 -p 8600 test-api.service.consul A +short

# Method 3: HTTP API Discovery
curl http://localhost:8500/v1/catalog/service/test-api | jq

# Method 4: Get healthy instances only
curl http://localhost:8500/v1/health/service/test-api?passing | jq

# Method 5: Get service address programmatically and call it
SERVICE_IP=$(curl -s http://localhost:8500/v1/health/service/test-api?passing | jq -r '.[0].Node.Address')
echo "test-api is running at: $SERVICE_IP"

# Try to connect to it
curl http://$SERVICE_IP:9090/index.json
```

**Expected result:** You should get the JSON response from Client-2! 🎉

---

## 5. Deploy Real PostgreSQL Database on Client-2

SSH into Client-2:
```bash
ssh -i ~/.ssh/consul-key.pem ubuntu@13.218.92.220
```

### Install Docker:
```bash
sudo apt update
sudo apt install -y docker.io postgresql-client
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu
```

### Deploy PostgreSQL in Docker:
```bash
# Run PostgreSQL container
sudo docker run -d \
  --name postgres-db \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -e POSTGRES_USER=appuser \
  -e POSTGRES_DB=myappdb \
  -p 5432:5432 \
  postgres:15

# Wait a few seconds for startup
sleep 5

# Verify it's running
sudo docker ps
sudo docker logs postgres-db

# Test local connection
PGPASSWORD=mysecretpassword psql -h localhost -U appuser -d myappdb -c "SELECT version();"
```

You should see PostgreSQL version info! ✅

### Register PostgreSQL with Consul:
```bash
sudo tee /etc/consul.d/postgres.json > /dev/null <<EOF
{
  "service": {
    "name": "postgres",
    "tags": ["database", "primary", "postgres-15"],
    "port": 5432,
    "meta": {
      "database": "myappdb",
      "version": "15"
    },
    "check": {
      "tcp": "localhost:5432",
      "interval": "10s",
      "timeout": "2s"
    }
  }
}
EOF

sudo consul reload

# Verify registration
consul catalog services
```

**Check the Consul UI** - You should see the "postgres" service! 🐘

---

## 6. Store Database Configuration in Consul KV

On Client-2 (or any node):
```bash
# Get the actual private IP of Client-2 (where Postgres is running)
POSTGRES_IP=$(hostname -I | awk '{print $1}')
echo "PostgreSQL is running at: $POSTGRES_IP"

# Store real database configuration in Consul KV
consul kv put myapp/database/host "$POSTGRES_IP"
consul kv put myapp/database/port "5432"
consul kv put myapp/database/name "myappdb"
consul kv put myapp/database/username "appuser"
consul kv put myapp/database/password "mysecretpassword"
consul kv put myapp/database/connection-string "postgresql://appuser:mysecretpassword@$POSTGRES_IP:5432/myappdb"

# Verify storage
consul kv get -recurse myapp/database/
```

**Check the Consul UI** → "Key/Value" - See your database config! 🔑

---

## 7. Connect to PostgreSQL from Client-1 Using Service Discovery

SSH into Client-1:
```bash
ssh -i ~/.ssh/consul-key.pem ubuntu@3.236.91.47
```

### Install PostgreSQL client:
```bash
sudo apt update
sudo apt install -y postgresql-client
```

### Method 1: Discover via Consul HTTP API + KV Store
```bash
# Dynamically get database info from Consul service discovery
DB_IP=$(curl -s http://localhost:8500/v1/health/service/postgres?passing | jq -r '.[0].Node.Address')
DB_PORT=$(curl -s http://localhost:8500/v1/health/service/postgres?passing | jq -r '.[0].Service.Port')

# Get credentials from Consul KV store (secure!)
DB_NAME=$(consul kv get myapp/database/name)
DB_USER=$(consul kv get myapp/database/username)
DB_PASS=$(consul kv get myapp/database/password)

echo "Discovered PostgreSQL at: $DB_IP:$DB_PORT"

# Connect using discovered values
PGPASSWORD="$DB_PASS" psql \
  -h "$DB_IP" \
  -p "$DB_PORT" \
  -U "$DB_USER" \
  -d "$DB_NAME" \
  -c "SELECT version();"
```

You should see the PostgreSQL version! ✅

**What just happened:**
- 🔍 **Service Discovery**: Found PostgreSQL location dynamically
- 🔑 **KV Store**: Retrieved credentials securely
- ✅ **Health Check**: Only connected to healthy instances
- 🚫 **No Hardcoded IPs**: Everything discovered via Consul!

---

### Method 2: Create a Reusable Connection Script
```bash
# Create a helper script for database connections
cat > ~/db-connect.sh <<'SCRIPT'
#!/bin/bash

echo "🔍 Discovering database via Consul..."

# Find healthy postgres instance
DB_INFO=$(curl -s http://localhost:8500/v1/health/service/postgres?passing)

if [ $(echo "$DB_INFO" | jq length) -eq 0 ]; then
    echo "❌ Error: No healthy PostgreSQL instances found!"
    exit 1
fi

# Get connection details from service discovery
DB_IP=$(echo "$DB_INFO" | jq -r '.[0].Node.Address')
DB_PORT=$(echo "$DB_INFO" | jq -r '.[0].Service.Port')

# Get credentials from Consul KV
DB_NAME=$(consul kv get myapp/database/name)
DB_USER=$(consul kv get myapp/database/username)
DB_PASS=$(consul kv get myapp/database/password)

echo "✅ Found PostgreSQL at: $DB_IP:$DB_PORT"
echo "   Database: $DB_NAME"
echo "   User: $DB_USER"
echo ""

# Connect
export PGPASSWORD="$DB_PASS"
psql -h "$DB_IP" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" "$@"
SCRIPT

chmod +x ~/db-connect.sh
```

**Test the script:**
```bash
# Interactive connection
./db-connect.sh

# Run a single query
./db-connect.sh -c "SELECT version();"

# Exit with \q or Ctrl+D
```

🎯 **This demonstrates the complete Consul pattern:**
- ✅ Service Discovery (find where database is)
- ✅ Health Checking (only connect to healthy instances)  
- ✅ Configuration Management (get credentials from KV)
- ✅ Zero hardcoded values!

---

### Create Some Test Data

Using Method 1 (inline commands):
```bash
# Get all DB connection info from Consul
DB_IP=$(curl -s http://localhost:8500/v1/health/service/postgres?passing | jq -r '.[0].Node.Address')
DB_PORT=$(curl -s http://localhost:8500/v1/health/service/postgres?passing | jq -r '.[0].Service.Port')
DB_NAME=$(consul kv get myapp/database/name)
DB_USER=$(consul kv get myapp/database/username)
DB_PASS=$(consul kv get myapp/database/password)

# Create a table and insert data
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

You should see output like:
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

**Or use the helper script (Method 2):**
```bash
./db-connect.sh -c "SELECT * FROM users;"
```

---

### Query Database Info
```bash
./db-connect.sh -c "
SELECT 
    current_database() as database,
    current_user as user,
    inet_server_addr() as server_ip,
    inet_server_port() as server_port;
"
```

Expected output:
```
 database | user    | server_ip   | server_port 
----------+---------+-------------+-------------
 myappdb  | appuser | 10.0.1.206  |        5432
(1 row)
```

---

### Understanding What You Built

This is a **real microservices pattern** used in production:

1. **Client-1** (web app) needs a database
2. **Client-2** (database server) runs PostgreSQL
3. **Consul** manages the discovery and configuration
4. **No hardcoded IPs** - everything is dynamic
5. **Health checks** ensure you only connect to working services
6. **Configuration in KV store** - change credentials without redeploying

**Real-world use case:** If Client-2 fails and you spin up a new database server, Consul automatically updates the service registry. Client-1 will discover the new database location without any code changes! 🚀

---

## 8. Test Health Checks & Automatic Failover Concept

### Stop PostgreSQL and watch Consul detect it:

On Client-2:
```bash
# Stop the PostgreSQL container
sudo docker stop postgres-db

# Wait 10-15 seconds
sleep 15

# Check service health
consul catalog services
curl http://localhost:8500/v1/health/service/postgres | jq
```

**Check the Consul UI** - PostgreSQL should show as "failing" ❌

### From Client-1, try to discover it:
```bash
# This will return empty because no healthy instances
curl http://localhost:8500/v1/health/service/postgres?passing | jq

# This query would return empty, preventing connection to failed service!
```

**This is the power of health checks!** Your app won't try to connect to a dead database. 🛡️

### Restart PostgreSQL:
```bash
# On Client-2
sudo docker start postgres-db

# Wait 10-15 seconds
sleep 15

# Check health
curl http://localhost:8500/v1/health/service/postgres?passing | jq
```

**Check the Consul UI** - Should turn green again! ✅

---

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

## 10. Query All Your Services
```bash
# List all registered services
consul catalog services

# Get details about each service
curl http://localhost:8500/v1/catalog/service/web-app | jq
curl http://localhost:8500/v1/catalog/service/postgres | jq
curl http://localhost:8500/v1/catalog/service/test-api | jq

# Get only healthy instances of each
curl http://localhost:8500/v1/health/service/web-app?passing | jq '.[].Service.Port'
curl http://localhost:8500/v1/health/service/postgres?passing | jq '.[].Service.Port'

# Count instances per service
echo "web-app instances: $(curl -s http://localhost:8500/v1/health/service/web-app?passing | jq 'length')"
echo "postgres instances: $(curl -s http://localhost:8500/v1/health/service/postgres?passing | jq 'length')"
echo "test-api instances: $(curl -s http://localhost:8500/v1/health/service/test-api?passing | jq 'length')"
```

---

## 11. Bonus: Watch Mode (Live Updates)

Open **two terminals** to Client-1:

**Terminal 1** - Watch for database changes:
```bash
# Watch for postgres service changes
consul watch -type=service -service=postgres
```

**Terminal 2** - On Client-2, restart the database:
```bash
sudo docker restart postgres-db
```

Terminal 1 will show live updates as the service goes down and comes back up! 📡

**Watch for KV changes:**

**Terminal 1:**
```bash
consul watch -type=key -key=myapp/database/host
```

**Terminal 2:**
```bash
consul kv put myapp/database/host "10.0.1.250"
```

You'll see the change immediately! ⚡

---

## Summary - What You've Learned

✅ **Service Registration**: Registered web-app, test-api, and postgres
✅ **Service Discovery**: Found services using DNS and HTTP API
✅ **Health Checking**: Automatic detection of service failures
✅ **Key-Value Store**: Stored and retrieved database configuration
✅ **Real Database**: Connected to PostgreSQL using service discovery
✅ **Dynamic Configuration**: Used Consul for runtime config management
✅ **Multi-Service Architecture**: Multiple services discovering each other

### Real-World Use Case You've Built:
- **Client-1**: Web application (nginx) that needs to connect to a database
- **Client-2**: PostgreSQL database server
- **Consul**: Service registry and configuration store connecting them
- **Dynamic Discovery**: App finds database automatically, no hardcoded IPs!

---

## Cleanup When Done
```bash
# On your local machine
terraform destroy

# Type 'yes' to confirm
```

**Cost savings:** Stops ~$42/month charges! 💰

---