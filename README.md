# 🎯 Sistema de Generación de Números Primos Distribuido

**Status**: ✅ **COMPLETAMENTE FUNCIONAL** - [Ver Validación E2E](E2E_VALIDATION.md)

Arquitectura de **microservicios distribuida** con componentes completamente separados e independientes:

- 🔹 **API REST**: Endpoints para crear y consultar solicitudes
- 🔹 **Cola Redis**: Almacena jobs de procesamiento (LPUSH/BLPOP)
- 🔹 **Workers**: Múltiples Pods en Kubernetes generando primos en paralelo
- 🔹 **PostgreSQL**: Base de datos para persistencia transaccional
- 🔹 **Miller-Rabin**: Algoritmo determinístico 100% acurado

## 📚 Documentación

| Documento | Propósito |
|-----------|-----------|
| **[DESPLIEGUE_KILLERCODA.md](DESPLIEGUE_KILLERCODA.md)** | ☁️ **RECOMENDADO** - Despliegue en plataforma Killercoda |
| **[DESPLIEGUE_ESTADO.md](DESPLIEGUE_ESTADO.md)** | 📊 Estado actual - Cluster operativo 100% validado |
| **[DESPLIEGUE.md](DESPLIEGUE.md)** | 🚀 Guía paso a paso para Docker Compose, Local, Kubernetes |
| **[PROYECTO_EXPLICADO.md](PROYECTO_EXPLICADO.md)** | 📖 Descripción del proyecto y arquitectura distribuida |
| **[REQUERIMIENTOS.md](REQUERIMIENTOS.md)** | ✅ Especificación técnica de todos los requerimientos |
| **[E2E_VALIDATION.md](E2E_VALIDATION.md)** | ✅ Validación completa E2E - Resultados de tests |

### 🎬 Demo Automatizada

Ejecutar demo completa de sustentación:

```bash
./scripts/demo-sustentacion.sh 3 10
```

Este script demuestra:
1. ✅ Cluster Kubernetes operacional
2. ✅ API REST respondiendo
3. ✅ Creación de solicitud (POST /new)
4. ✅ Progreso en tiempo real (GET /status)
5. ✅ Resultados validados (GET /result)
6. ✅ Persistencia en PostgreSQL

## 🚀 Inicio Rápido (30 segundos)

### Con Docker Compose (Recomendado)

```bash
# 1. Compilar e iniciar todo
docker-compose up -d

# 2. Esperar a que PostgreSQL esté listo
sleep 10

# 3. Crear una solicitud
curl -X POST http://localhost:8000/new \
  -H "Content-Type: application/json" \
  -d '{"cantidad":5,"digitos":12}'

# 4. Consultar estado
curl http://localhost:8000/status/<id>

# 5. Ver resultados
docker-compose logs -f worker
```

**Para guía completa**: Ver [DESPLIEGUE.md](DESPLIEGUE.md)

### Con Kubernetes

```bash
# 1. Crear cluster
kind create cluster --name primes

# 2. Compilar imagen
docker build -t primes-app:latest .
kind load docker-image primes-app:latest --name primes

# Desplegar
kubectl create namespace primes
kubectl apply -f k8s/ -n primes

# Port forward
kubectl port-forward svc/primes-api-service -n primes 8000:80

# Probar
curl http://localhost:8000/
```

👉 **Ver guía completa**: [KUBERNETES_LOCAL_GUIDE.md](KUBERNETES_LOCAL_GUIDE.md)

### 3️⃣ Local nativo (Sin contenedores)

```bash
# Setup BD
sudo -u postgres createuser primes_user --pwprompt  # primes_pass
sudo -u postgres createdb primes --owner primes_user
export DATABASE_URL="host=localhost port=5432 dbname=primes user=primes_user password=primes_pass"

# Inicializar BD
psql "$DATABASE_URL" -f sql/init.sql

# Compilar
make clean && make

# Ejecutar API (Terminal 1)
export REDIS_HOST=localhost REDIS_PORT=6379
./server

# Ejecutar Workers (Terminal 2+)
./worker &
./worker &
./worker &
```

## API Endpoints

```bash
# 1. Crear solicitud (retorna ID)
curl -X POST http://localhost:8000/new \
  -H "Content-Type: application/json" \
  -d '{"cantidad":5,"digitos":12}'
# {"id":"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"}

# 3. Desplegar en Kubernetes
kubectl apply -f k8s/ -n primes
kubectl port-forward -n primes svc/primes-api-service 8000:8000
```

**Para guía completa**: Ver [DESPLIEGUE.md](DESPLIEGUE.md)

## 📋 API Endpoints

```bash
# 1. Crear solicitud
POST /new
Body: {"cantidad": 5, "digitos": 12}
Response: {"id": "uuid"}

# 2. Consultar estado
GET /status/:id
Response: {"id": "uuid", "cantidad": 5, "digitos": 12, "generados": 3}

# 3. Obtener resultados
GET /result/:id
Response: {"id": "uuid", "cantidad": 5, "primos": ["999999999989", "999999999937", ...]}
```

## 🏗️ Arquitectura

```
Client  →  API (8000)  ────→  Redis Queue  ←──  Workers (x3-20)
                       ↓                            ↓
                    PostgreSQL ←─────────────────────┘
                 (Solicitudes + Resultados)
```

**Características:**
- ✅ API y Workers completamente separados
- ✅ Redis desacopla totalmente la comunicación
- ✅ Escalable horizontalmente (agregar workers/APIs)
- ✅ Tolerante a fallos (cada componente independiente)
- ✅ 100% SQL injection safe (prepared statements)

## 📦 Componentes

| Componente | Rol | Tecnología |
|---|---|---|
| **API** | REST endpoints | C + Mongoose |
| **Workers** | Generan primos | C + Miller-Rabin |
| **Redis** | Cola distribuida | Redis (LPUSH/BLPOP) |
| **PostgreSQL** | Persistencia | PostgreSQL (2 tablas) |

## ✅ Requerimientos Cumplidos

- ✅ 3 Endpoints REST (New, Status, Result)
- ✅ PostgreSQL con 2 tablas coordinadas
- ✅ Sistema de colas (Redis LPUSH/BLPOP)
- ✅ Workers distribuidos (Kubernetes Pods)
- ✅ Miller-Rabin determinístico 100%
- ✅ Validación de entrada (1-1000 primos, 2-20 dígitos)
- ✅ Prevención de duplicados (índices UNIQUE)
- ✅ Seguridad (SQL prepared statements)

**Ver detalles:** [REQUERIMIENTOS.md](REQUERIMIENTOS.md)

## 🛠️ Tecnologías

- **Lenguaje**: C
- **API**: Mongoose HTTP Server
- **BD**: PostgreSQL
- **Cola**: Redis
- **Contenedores**: Docker + docker-compose
- **Orquestación**: Kubernetes + HPA

## 🔗 Enlaces Importantes

- [PROYECTO_EXPLICADO.md](PROYECTO_EXPLICADO.md) - Descripción y arquitectura
- [DESPLIEGUE.md](DESPLIEGUE.md) - Guía de despliegue completa
- [REQUERIMIENTOS.md](REQUERIMIENTOS.md) - Especificación técnica
- [LIMPIEZA_REALIZADA.md](LIMPIEZA_REALIZADA.md) - Cambios de documentación

## ☁️ Despliegue remoto (Killercoda / cluster Kubernetes remoto)

Requisitos previos:
- Cuenta Docker Hub (para publicar imágenes)
- `kubectl` configurado apuntando al cluster remoto (Killercoda suele proporcionar kubeconfig en la sesión)

1) Build + Push + Aplicar (script automatizado)

```bash
# En tu máquina local (con Docker login):
chmod +x ./scripts/deploy_remote.sh
./scripts/deploy_remote.sh <DOCKERHUB_USER> <TAG>
# Ejemplo:
./scripts/deploy_remote.sh tu_usuario v1
```

El script buildea las imágenes (`primes-api`, `primes-worker`), las pushea a Docker Hub,
genera manifiestos temporales que apuntan a esas imágenes y aplica todos los recursos en el
namespace `primes` (Postgres, Redis, Services, Deployments).

2) Comandos `kubectl apply` (alternativa manual en Killercoda)

Si prefieres aplicar manualmente (por ejemplo desde la sesión de Killercoda) puedes ejecutar:

```bash
kubectl create namespace primes
kubectl apply -f k8s/postgres.yaml -n primes
kubectl apply -f k8s/redis.yaml -n primes
kubectl apply -f k8s/service.yaml -n primes
# A continuación aplica los deployments (asegúrate de editar las imágenes si es necesario)
kubectl apply -f k8s/deployment.yaml -n primes
kubectl apply -f k8s/worker-deployment.yaml -n primes
```

Si tus deployments siguen apuntando a imágenes locales, actualízalas con `kubectl set image`:

```bash
# Reemplaza DOCKERHUB_USER y TAG por tus valores
kubectl -n primes set image deployment/primes-api api=${DOCKERHUB_USER}/primes-api:${TAG}
kubectl -n primes set image deployment/primes-worker worker=${DOCKERHUB_USER}/primes-worker:${TAG}
```

3) Pruebas durante la sustentación (comandos curl)

Usa `kubectl port-forward` para exponer el servicio API localmente y ejecutar ejemplos `curl`:

```bash
# En una terminal
kubectl port-forward -n primes svc/primes-api-service 8000:8000

# En otra terminal: crear solicitud (New)
curl -s -X POST http://localhost:8000/new -H "Content-Type: application/json" \
  -d '{"cantidad":3,"digitos":10}' | jq -r '.id'

# Copia el ID y consulta estado
curl http://localhost:8000/status/<ID>

# Obtener resultados finales
curl http://localhost:8000/result/<ID>
```

Si la sesión de Killercoda no tiene `docker push` permitido, usa tu máquina local para push y luego ejecuta los comandos `kubectl apply` en la sesión de Killercoda.


---

**Versión**: 1.0  
**Última actualización**: 3 de Diciembre de 2025  
**Estado**: ✅ Funcional con Docker Compose y Kubernetes
