# 🚀 Despliegue en Killercoda (Kubernetes Remoto)

> **Tiempo estimado**: 5-10 minutos  
> **Requisitos**: Docker Hub cuenta + Killercoda acceso

---

## 🔧 Preparación Previa (En Tu Máquina Local)

### 1. Crear Cuenta Docker Hub
Si aún no tienes:
1. Ve a https://hub.docker.com/
2. Regístrate (ej: `tu_usuario`)
3. Crea un token personal en **Account Settings → Security → New Access Token**
4. Copia el token (lo necesitarás pronto)

### 2. Compilar y Publicar Imágenes

```bash
# En tu máquina local (donde está el código)
cd /home/alex/Desktop/Proyecto-Final-sistemas-distribuidos-main

# Compilar imágenes
docker build --target api -t tu_usuario/primes-api:latest .
docker build --target worker -t tu_usuario/primes-worker:latest .

# Login en Docker Hub
docker login

# Publicar
docker push tu_usuario/primes-api:latest
docker push tu_usuario/primes-worker:latest

# Verificar
docker images | grep primes
```

**Ejemplo completo:**
```bash
docker login
# Username: alex_dev
# Password: <pega tu token>

docker build --target api -t alex_dev/primes-api:latest .
docker build --target worker -t alex_dev/primes-worker:latest .

docker push alex_dev/primes-api:latest
docker push alex_dev/primes-worker:latest
```

---

## 🎯 Despliegue en Killercoda

### Paso 1: Acceder a Killercoda
1. Ve a https://killercoda.com/
2. Busca "Kubernetes" → Elige **"Ubuntu with Docker & Kubernetes"**
3. Haz clic en **"Open in playground"**
4. **Espera 30-60 segundos** mientras se inicia el entorno

### Paso 2: Clonar el Proyecto

En la terminal de Killercoda:

```bash
# Clonar repositorio (o copiar archivos manualmente)
git clone https://github.com/tu_usuario/Proyecto-Final-sistemas-distribuidos-main.git
cd Proyecto-Final-sistemas-distribuidos-main
```

O si prefieres cargar manualmente:
```bash
# Copiar archivos necesarios
mkdir -p k8s sql src include
# ... (copiar archivos manualmente o via SCP)
```

### Paso 3: Crear Namespace y Secrets

```bash
# Crear namespace
kubectl create namespace primes

# Crear secret para Docker Hub (reemplaza TUS VALORES)
kubectl create secret docker-registry regcred \
  --docker-server=docker.io \
  --docker-username=TU_USUARIO_DOCKER_HUB \
  --docker-password=TU_TOKEN_DOCKER_HUB \
  --docker-email=tu_email@example.com \
  -n primes

# Crear secret para BD
kubectl create secret generic app-secret \
  --from-literal=database-url='host=postgres port=5432 dbname=primes user=primes_user password=primes_pass' \
  -n primes

# Crear secret para PostgreSQL
kubectl create secret generic postgres-secret \
  --from-literal=POSTGRES_USER=primes_user \
  --from-literal=POSTGRES_PASSWORD=primes_pass \
  --from-literal=POSTGRES_DB=primes \
  -n primes

# Verificar
kubectl get secrets -n primes
```

### Paso 4: Actualizar Manifests con Tu Usuario Docker Hub

Reemplaza `TU_USUARIO` en los manifests:

```bash
# Opción 1: Usar sed (automático)
sed -i 's|primes-api:latest|TU_USUARIO/primes-api:latest|g' k8s/deployment.yaml
sed -i 's|primes-worker:latest|TU_USUARIO/primes-worker:latest|g' k8s/worker-deployment.yaml

# Agregar imagePullSecrets y cambiar imagePullPolicy
# (Ver paso 5 para detalles)
```

**Opción 2: Editar manualmente**

Modifica `k8s/deployment.yaml`:
```yaml
# Cambiar línea:
        image: primes-api:latest
# A:
        image: TU_USUARIO/primes-api:latest
        
# Y cambiar:
        imagePullPolicy: Never
# A:
        imagePullPolicy: IfNotPresent
        
# Y agregar en spec.template.spec (después de terminationGracePeriodSeconds):
      imagePullSecrets:
      - name: regcred
```

Haz lo mismo en `k8s/worker-deployment.yaml`.

### Paso 5: Desplegar Componentes

```bash
# Crear ConfigMap
kubectl create configmap primes-config \
  --from-literal=REDIS_HOST=redis \
  --from-literal=REDIS_PORT=6379 \
  -n primes

# Desplegar PostgreSQL
kubectl apply -f k8s/postgres.yaml -n primes

# Esperar a que PostgreSQL esté listo
kubectl get pod -n primes -l app=postgres -w

# (Presiona Ctrl+C cuando esté Running y Ready 1/1)

# Desplegar Redis
kubectl apply -f k8s/redis.yaml -n primes

# Desplegar Servicios
kubectl apply -f k8s/service.yaml -n primes

# Desplegar API
kubectl apply -f k8s/deployment.yaml -n primes

# Desplegar Workers
kubectl apply -f k8s/worker-deployment.yaml -n primes

# Verificar estado
kubectl get pods -n primes
```

**Salida esperada:**
```
NAME                              READY   STATUS    RESTARTS   AGE
postgres-0                        1/1     Running   0          2m
redis-0                           1/1     Running   0          1m30s
primes-api-xxxxx-xxxxx            1/1     Running   0          30s
primes-api-xxxxx-yyyyy            1/1     Running   0          29s
primes-worker-xxxxx-aaaaa         1/1     Running   0          25s
primes-worker-xxxxx-bbbbb         1/1     Running   0          25s
primes-worker-xxxxx-ccccc         1/1     Running   0          25s
```

### Paso 6: Verificar Despliegue

```bash
# Ver todos los recursos
kubectl get all -n primes

# Ver logs de API
kubectl logs -n primes -l app=primes-api --tail=20

# Ver logs de Workers
kubectl logs -n primes -l app=primes-worker --tail=20

# Probar endpoint raíz (desde dentro del cluster)
kubectl run -n primes curl-test --image=curlimages/curl --rm -it --restart=Never \
  -- curl -s http://primes-api-service/

# Resultado esperado: {"status":"ok"}
```

---

## 🧪 Testing E2E en Killercoda

### Crear Solicitud

```bash
kubectl run -n primes curl-test --image=curlimages/curl --rm -it --restart=Never \
  -- curl -s -X POST http://primes-api-service/new \
  -H "Content-Type: application/json" \
  -d '{"cantidad":3,"digitos":10}'
```

**Resultado:** `{"id":"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"}`

Copia el ID para los siguientes pasos.

### Consultar Estado

```bash
# Reemplaza {ID} con el ID de arriba
kubectl run -n primes curl-test --image=curlimages/curl --rm -it --restart=Never \
  -- curl -s http://primes-api-service/status/{ID}
```

**Resultado:** `{"id":"...","cantidad":3,"digitos":10,"generados":3}`

### Obtener Resultados

```bash
# Espera a que generados == cantidad
kubectl run -n primes curl-test --image=curlimages/curl --rm -it --restart=Never \
  -- curl -s http://primes-api-service/result/{ID}
```

**Resultado:**
```json
{
  "id": "...",
  "cantidad": 3,
  "digitos": 10,
  "primos": ["1234567891", "9876543217", "5555555551"]
}
```

---

## 🔌 Port Forward para Acceso Local

Si quieres exponer la API a tu máquina local:

```bash
# En Terminal de Killercoda
kubectl port-forward -n primes svc/primes-api-service 8000:80 --address=0.0.0.0

# En tu máquina local (obtén la IP de Killercoda)
curl http://<KILLERCODA_IP>:8000/
```

---

## 📊 Escalado en Killercoda

```bash
# Aumentar replicas de API (2-5)
kubectl scale deployment primes-api -n primes --replicas=5

# Aumentar replicas de Workers (3-20)
kubectl scale deployment primes-worker -n primes --replicas=20

# Verificar escalado
kubectl get pods -n primes
```

---

## 🧹 Limpieza

```bash
# Eliminar todo (namespace + recursos)
kubectl delete namespace primes

# O solo algunos recursos
kubectl delete deployment -n primes --all
kubectl delete statefulset -n primes --all
kubectl delete svc -n primes --all
```

---

## ⚠️ Troubleshooting

### Pods en CrashLoopBackOff

```bash
# Ver logs detallados
kubectl logs -n primes <pod-name>

# Ver descripción (incluyendo eventos)
kubectl describe pod -n primes <pod-name>

# Verificar imagen está disponible
kubectl get pod -n primes <pod-name> -o yaml | grep image:
```

### ImagePullBackOff

```bash
# Significa que la imagen no se puede descargar de Docker Hub
# Soluciones:
# 1. Verifica que el usuario/imagen es correcto
# 2. Verifica que el token Docker Hub es válido
# 3. Verifica que la imagen fue pusheada correctamente
docker pull TU_USUARIO/primes-api:latest
```

### Conexión rechazada a BD

```bash
# Verifica que PostgreSQL esté listo
kubectl get pod postgres-0 -n primes

# Si no está Running, espera más o revisa logs:
kubectl logs postgres-0 -n primes

# Verifica que el secret de BD existe
kubectl get secret app-secret -n primes -o yaml
```

---

## 📋 Checklist Rápido para Sustentación

- [ ] Imágenes publicadas en Docker Hub
- [ ] Killercoda acceso disponible
- [ ] Namespace `primes` creado
- [ ] Secrets configurados (regcred, app-secret, postgres-secret)
- [ ] Manifests actualizados con usuario Docker Hub
- [ ] PostgreSQL `1/1 Running`
- [ ] Redis `1/1 Running`
- [ ] API `2/2 Ready`
- [ ] Workers `3/3 Ready`
- [ ] Endpoint `/` responde `{"status":"ok"}`
- [ ] POST `/new` crea ID
- [ ] GET `/status/{id}` muestra progreso
- [ ] GET `/result/{id}` retorna primos

---

## 🎬 Script de Demo Automatizado

Para ejecutar durante la sustentación:

```bash
#!/bin/bash
set -e

echo "🚀 Demostrando cluster Kubernetes con primos-generator..."
echo ""

# 1. Mostrar estado del cluster
echo "1️⃣  Estado del cluster:"
kubectl get pods -n primes
echo ""

# 2. Crear solicitud
echo "2️⃣  Crear solicitud (3 primos de 10 dígitos)..."
RESPONSE=$(kubectl run -n primes curl-test --image=curlimages/curl --rm -i --restart=Never \
  -- curl -s -X POST http://primes-api-service/new \
  -H "Content-Type: application/json" \
  -d '{"cantidad":3,"digitos":10}' 2>/dev/null)

ID=$(echo "$RESPONSE" | grep -oP '(?<="id":")[^"]*')
echo "✅ ID: $ID"
echo ""

# 3. Esperar procesamiento
echo "3️⃣  Esperando que workers procesen..."
sleep 3

# 4. Consultar estado
echo "4️⃣  Estado actual:"
kubectl run -n primes curl-test --image=curlimages/curl --rm -i --restart=Never \
  -- curl -s http://primes-api-service/status/$ID 2>/dev/null

echo ""
echo ""

# 5. Obtener resultados
echo "5️⃣  Primos generados:"
kubectl run -n primes curl-test --image=curlimages/curl --rm -i --restart=Never \
  -- curl -s http://primes-api-service/result/$ID 2>/dev/null

echo ""
echo "✅ Demo completada!"
```

Guarda como `scripts/demo-killercoda.sh` y ejecuta:
```bash
chmod +x scripts/demo-killercoda.sh
./scripts/demo-killercoda.sh
```

---

**Última actualización**: 3 de Diciembre de 2025  
**Estado**: ✅ Probado en Killercoda  
**Tiempo de despliegue**: ~5 minutos
