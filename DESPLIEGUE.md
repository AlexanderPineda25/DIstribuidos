# 🚀 Guía de Despliegue

## 📋 Requisitos Previos

### Opción 1: Docker Compose (Recomendado para desarrollo)
```bash
sudo apt install -y docker.io docker-compose
sudo usermod -aG docker $USER
```

### Opción 2: Local nativo
```bash
sudo apt install -y build-essential gcc make pkg-config
sudo apt install -y postgresql postgresql-contrib libpq-dev
sudo apt install -y libhiredis-dev redis-server
pip3 install requests
```

### Opción 3: Kubernetes (Kind/Minikube)
```bash
# Instalar Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/

# O Minikube
curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
chmod +x minikube-linux-amd64
sudo mv minikube-linux-amd64 /usr/local/bin/minikube
```

---

## 🐳 Despliegue con Docker Compose (RECOMENDADO - 30 segundos)

### 1. Compilar e Iniciar
```bash
# Todo en uno
docker-compose up -d

# Esperar a que PostgreSQL esté listo (~10 segundos)
sleep 10
```

### 2. Verificar Estado
```bash
# Ver servicios
docker-compose ps

# Ver logs de la API
docker-compose logs -f api

# Ver logs de los workers
docker-compose logs -f worker
```

### 3. Probar API
```bash
# Crear solicitud
RESPONSE=$(curl -s -X POST http://localhost:8000/new \
  -H "Content-Type: application/json" \
  -d '{"cantidad":5,"digitos":12}')

ID=$(echo $RESPONSE | grep -oP '(?<="id":")[^"]*')
echo "ID: $ID"

# Esperar un segundo
sleep 1

# Consultar estado
curl http://localhost:8000/status/$ID | jq .

# Obtener resultados
curl http://localhost:8000/result/$ID | jq .
```

### 4. Escalar Workers
```bash
# Aumentar a 5 workers
docker-compose up -d --scale worker=5

# Verificar
docker-compose ps
```

### 5. Detener
```bash
# Parar servicios (mantiene datos)
docker-compose stop

# Parar y eliminar volúmenes (BORRA datos)
docker-compose down -v
```

---

## 💻 Despliegue Local Nativo

### 1. Configurar Base de Datos
```bash
# Crear usuario
sudo -u postgres createuser primes_user --pwprompt
# Contraseña: primes_pass

# Crear BD
sudo -u postgres createdb primes --owner primes_user

# Aplicar schema
export DATABASE_URL="host=localhost port=5432 dbname=primes user=primes_user password=primes_pass"
psql "$DATABASE_URL" -f sql/init.sql
```

### 2. Compilar
```bash
make clean && make
# Genera: ./server (165K) y ./worker (31K)
```

### 3. Ejecutar Componentes

**Terminal 1: API Server**
```bash
export DATABASE_URL="host=localhost port=5432 dbname=primes user=primes_user password=primes_pass"
export REDIS_HOST=localhost
export REDIS_PORT=6379
./server
# ✅ Listening on port 8000
```

**Terminal 2: Worker 1**
```bash
export DATABASE_URL="host=localhost port=5432 dbname=primes user=primes_user password=primes_pass"
export REDIS_HOST=localhost
export REDIS_PORT=6379
./worker
# ✅ Consuming jobs from Redis
```

**Terminal 3: Worker 2+ (opcional)**
```bash
export DATABASE_URL="host=localhost port=5432 dbname=primes user=primes_user password=primes_pass"
export REDIS_HOST=localhost
export REDIS_PORT=6379
./worker
# ✅ Multiple workers processing in parallel
```

### 4. Probar
```bash
# Nueva solicitud
curl -X POST http://localhost:8000/new \
  -H "Content-Type: application/json" \
  -d '{"cantidad":5,"digitos":12}'

# Consultar estado
curl http://localhost:8000/status/<id>

# Obtener resultados
curl http://localhost:8000/result/<id>
```

---

## ☸️ Despliegue con Kubernetes

### 1. Crear Cluster (si no existe)

**Con Kind:**
```bash
kind create cluster --name primes
```

**Con Minikube:**
```bash
minikube start --nodes=3 --memory=4096
```

### 2. Compilar e Importar Imágenes

```bash
# Compilar imagen
docker build -t primes-app:latest .

# Si usas Kind
kind load docker-image primes-app:latest --name primes

# Si usas Minikube
eval $(minikube docker-env)
docker build -t primes-app:latest .
```

### 3. Crear Namespace
```bash
kubectl create namespace primes
```

### 4. Desplegar

```bash
# Desplegar todos los manifiestos
kubectl apply -f k8s/ -n primes

# Esperar a que estén listos
kubectl get pods -n primes -w
```

### 5. Verificar Despliegue

```bash
# Ver todos los recursos
kubectl get all -n primes

# Ver solo Pods
kubectl get pods -n primes

# Ver servicios
kubectl get svc -n primes

# Ver logs de API
kubectl logs -n primes -l app=primes-api -f --tail=50

# Ver logs de workers
kubectl logs -n primes -l app=primes-worker -f --tail=100
```

### 6. Acceder a la Aplicación

```bash
# Port Forward (en Terminal separada)
kubectl port-forward -n primes svc/primes-api-service 8000:8000

# Probar (en otra Terminal)
curl http://localhost:8000/
```

### 7. Escalar

```bash
# Aumentar API (2-5)
kubectl scale deployment primes-api -n primes --replicas=5

# Aumentar Workers (3-20)
kubectl scale deployment primes-worker -n primes --replicas=20

# Ver escalado automático (HPA)
kubectl get hpa -n primes -w
```

### 8. Limpiar

```bash
# Eliminar namespace (borra todo)
kubectl delete namespace primes
```

---

## 🔍 Troubleshooting

### Docker Compose

**Error: "Cannot connect to Docker daemon"**
```bash
sudo service docker start
# O en systemd
sudo systemctl start docker
```

**Error: "port 8000 is already in use"**
```bash
# Liberar puerto
lsof -i :8000 | grep LISTEN | awk '{print $2}' | xargs kill -9
```

**API responde pero sin primos**
```bash
# Verificar workers
docker-compose ps | grep worker

# Ver logs del worker
docker-compose logs worker

# Verificar Redis
docker-compose exec redis redis-cli LLEN jobs
```

### Kubernetes

**Pod stuck en CrashLoopBackOff**
```bash
# Ver logs detallados
kubectl logs -n primes <pod-name>

# Ver descripción
kubectl describe pod -n primes <pod-name>

# Ver eventos
kubectl get events -n primes --sort-by='.lastTimestamp'
```

**Base de datos no inicializa**
```bash
# Ver logs de PostgreSQL
kubectl logs -n primes postgres-0 | tail -50

# Conectarse a la BD
kubectl exec -it postgres-0 -n primes -- psql -U primes_user -d primes

# Verificar tablas
SELECT table_name FROM information_schema.tables WHERE table_schema='public';
```

**Workers no procesan**
```bash
# Ver si hay jobs en Redis
kubectl exec -it redis-0 -n primes -- redis-cli LLEN jobs

# Ver si hay solicitudes en BD
kubectl exec -it postgres-0 -n primes -- psql -U primes_user -d primes \
  -c "SELECT COUNT(*) FROM solicitudes;"

# Ver logs de workers
kubectl logs -n primes -l app=primes-worker --tail=100
```

---

## 📊 Monitoreo

### Verificar Salud

```bash
# API
curl http://localhost:8000/ -w "\nStatus: %{http_code}\n"

# Redis
kubectl exec -it redis-0 -n primes -- redis-cli ping

# PostgreSQL
kubectl exec -it postgres-0 -n primes -- pg_isready -h localhost -U primes_user
```

### Métricas

```bash
# Jobs en cola
kubectl exec -it redis-0 -n primes -- redis-cli LLEN jobs

# Solicitudes total
kubectl exec -it postgres-0 -n primes -- psql -U primes_user -d primes \
  -c "SELECT COUNT(*) FROM solicitudes;"

# Primos generados
kubectl exec -it postgres-0 -n primes -- psql -U primes_user -d primes \
  -c "SELECT COUNT(*) FROM resultados;"

# Recursos en uso
kubectl top pods -n primes
kubectl top nodes
```

---

## 📝 Configuración

### Variables de Entorno

**Para API (server)**
```bash
DATABASE_URL=host=localhost port=5432 dbname=primes user=primes_user password=primes_pass
REDIS_HOST=localhost
REDIS_PORT=6379
```

**Para Workers**
```bash
DATABASE_URL=host=localhost port=5432 dbname=primes user=primes_user password=primes_pass
REDIS_HOST=localhost
REDIS_PORT=6379
```

### Límites de Entrada

- **cantidad**: 1-1000 números primos
- **digitos**: 2-20 dígitos por número

---

## 🎯 Flujo Completo de Testing

### 1. Desplegar
```bash
# Elegir uno:
docker-compose up -d                    # Docker Compose
# O
kubectl apply -f k8s/ -n primes        # Kubernetes
```

### 2. Crear Solicitud
```bash
RESPONSE=$(curl -s -X POST http://localhost:8000/new \
  -H "Content-Type: application/json" \
  -d '{"cantidad":3,"digitos":10}')

ID=$(echo $RESPONSE | jq -r '.id')
echo "Solicitud: $ID"
```

### 3. Monitorear Progreso
```bash
# Consultar estado cada 2 segundos
watch -n 2 "curl -s http://localhost:8000/status/$ID | jq ."
```

### 4. Obtener Resultados
```bash
curl http://localhost:8000/result/$ID | jq .
```

### 5. Verificar en BD
```bash
# Docker Compose
docker-compose exec postgres psql -U primes_user -d primes \
  -c "SELECT * FROM solicitudes WHERE id='$ID';"

# Kubernetes
kubectl exec -it postgres-0 -n primes -- psql -U primes_user -d primes \
  -c "SELECT * FROM solicitudes WHERE id='$ID';"
```

---

## 🔄 Actualización del Código

### Local

```bash
# Compilar nuevamente
make clean && make

# Reiniciar servicios
pkill -f "^\./(server|worker)$"
./server &
./worker &
```

### Docker Compose

```bash
# Recompilar imágenes
docker-compose build

# Reiniciar servicios
docker-compose down
docker-compose up -d
```

### Kubernetes

```bash
# Recompilar imagen
docker build -t primes-app:latest .

# Cargar en cluster
kind load docker-image primes-app:latest --name primes

# Redeployer
kubectl rollout restart deployment/primes-api -n primes
kubectl rollout restart deployment/primes-worker -n primes

# Verificar actualización
kubectl get pods -n primes -l app=primes-api
```

---

**Última actualización**: 3 de Diciembre de 2025  
**Estado**: ✅ Funcional con Docker Compose y Kubernetes
