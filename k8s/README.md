# 📦 Kubernetes Deployment Files

Configuración completa de Kubernetes para desplegar la aplicación Generador de Números Primos.

## 📁 Estructura de Archivos

| Archivo | Descripción | Propósito |
|---------|-------------|----------|
| **namespace.yaml** | Namespace "primes" | Aislar recursos |
| **secrets.yaml** | Credenciales PostgreSQL | Base de datos segura |
| **configmap.yaml** | Configuración de aplicación | Variables de entorno |
| **init-sql-configmap.yaml** | Script SQL inicial | Inicializar base de datos |
| **postgres.yaml** | StatefulSet PostgreSQL | Base de datos persistente |
| **redis.yaml** | StatefulSet Redis | Cache y cola de mensajes |
| **deployment.yaml** | Deployment API | API REST con scaling |
| **worker-deployment.yaml** | Deployment Workers | Procesamiento distribuido |
| **service.yaml** | Services y HPA | Load balancer y auto-scaling |
| **network-policy.yaml** | Network policies | Seguridad de red |
| **pdb.yaml** | Pod Disruption Budget | Alta disponibilidad |

## 🚀 Inicio Rápido

### Opción 1: Despliegue Automático (Recomendado)
```bash
# Desde la raíz del proyecto
chmod +x k8s-deploy.sh
./k8s-deploy.sh --auto
```

### Opción 2: Despliegue Manual Paso a Paso
```bash
# 1. Namespace y Secrets
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/secrets.yaml

# 2. Configuración
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/init-sql-configmap.yaml

# 3. Infraestructura (Base de datos y Cache)
kubectl apply -f k8s/postgres.yaml
kubectl apply -f k8s/redis.yaml

# 4. Aplicación (API y Workers)
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/worker-deployment.yaml

# 5. Exponer servicios
kubectl apply -f k8s/service.yaml
```

## ✅ Verificación

### Todos los componentes corriendo
```bash
kubectl get all -n primes
```

### Verificar base de datos
```bash
kubectl exec -it postgres-0 -n primes -- psql -U primes_user -d primes -c "\dt"
```

### Verificar Redis
```bash
kubectl exec -it redis-0 -n primes -- redis-cli ping
```

## 🌐 Acceso a la Aplicación

```bash
# Portforward local
kubectl port-forward -n primes svc/primes-api-service 8000:80

# Probar la API
curl http://localhost:8000/
```

## 📊 Escala y Performance

### Escalar API
```bash
kubectl scale deployment primes-api --replicas=5 -n primes
```

### Escalar Workers
```bash
kubectl scale deployment primes-worker --replicas=10 -n primes
```

### Ver escalado automático
```bash
kubectl get hpa -n primes
kubectl describe hpa primes-api-hpa -n primes
```

## 🔧 Troubleshooting

### Logs de error
```bash
# API
kubectl logs -n primes -l app=primes-api -f

# Workers
kubectl logs -n primes -l app=primes-worker -f

# PostgreSQL
kubectl logs -n primes postgres-0

# Redis
kubectl logs -n primes redis-0
```

### Describir problemas
```bash
kubectl describe pod -n primes <pod-name>
kubectl events -n primes --sort-by='.lastTimestamp'
```

## 🧹 Limpiar Recursos

### Eliminar todo
```bash
kubectl delete namespace primes
```

### Solo eliminar pods (mantiene volúmenes)
```bash
kubectl delete all --all -n primes
```

## 📖 Documentación Completa

- **K8S_DEPLOYMENT_GUIDE.md**: Guía paso a paso detallada (en raíz del proyecto)
- **KILLERCODA_QUICKSTART.md**: Guía específica para KillerCoda (en raíz del proyecto)
- **k8s-deploy.sh**: Script automático de despliegue (en raíz del proyecto)

## 🏗️ Arquitectura

```
┌──────────────────────────────────────────┐
│         Kubernetes Namespace: primes      │
├──────────────────────────────────────────┤
│                                          │
│  API (Deployment)                        │
│  ├─ Pod 1: primes-api                    │
│  ├─ Pod 2: primes-api                    │
│  └─ HPA: 2-5 replicas                    │
│                                          │
│  Workers (Deployment)                    │
│  ├─ Pod 1: primes-worker                 │
│  ├─ Pod 2: primes-worker                 │
│  ├─ Pod 3: primes-worker                 │
│  └─ HPA: 3-20 replicas                   │
│                                          │
│  PostgreSQL (StatefulSet)                │
│  ├─ Pod: postgres-0                      │
│  └─ PVC: 10Gi                            │
│                                          │
│  Redis (StatefulSet)                     │
│  ├─ Pod: redis-0                         │
│  └─ PVC: 1Gi                             │
│                                          │
│  Services                                │
│  ├─ postgres: ClusterIP                  │
│  ├─ redis: ClusterIP                     │
│  └─ primes-api-service: LoadBalancer     │
│                                          │
└──────────────────────────────────────────┘
```

## 📝 Variables de Configuración

### Base de Datos
```
POSTGRES_DB: primes
POSTGRES_USER: primes_user
POSTGRES_PASSWORD: primes_pass (en secrets.yaml)
```

### Redis
```
REDIS_HOST: redis.primes.svc.cluster.local
REDIS_PORT: 6379
```

### API
```
DATABASE_URL: postgresql://primes_user:primes_pass@postgres.primes.svc.cluster.local:5432/primes
PORT: 8000
```

## 🔐 Seguridad

- ✅ Namespaces para aislamiento
- ✅ Secrets para credenciales
- ✅ Network policies (opcional)
- ✅ SecurityContext en contenedores
- ✅ Pod Disruption Budget para HA

## 🎓 Próximos Pasos

1. Lee **K8S_DEPLOYMENT_GUIDE.md** para una guía completa
2. Si usas KillerCoda, consulta **KILLERCODA_QUICKSTART.md**
3. Personaliza los valores en `configmap.yaml` y `secrets.yaml`
4. Construye tu imagen Docker: `docker build -t primes-generator:latest .`
5. Ejecuta: `./k8s-deploy.sh --auto`

---

**Para ayuda detallada, consulta las guías de despliegue incluidas! 📚**
