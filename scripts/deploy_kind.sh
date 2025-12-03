#!/usr/bin/env bash
set -euo pipefail

# deploy_kind.sh
# Construye imágenes para api y worker, crea/usa un cluster kind, carga imágenes y aplica manifests k8s/
# Uso: ./scripts/deploy_kind.sh [--cluster-name NAME]

CLUSTER_NAME="primes"
API_IMAGE="primes-api:local"
WORKER_IMAGE="primes-worker:local"
NAMESPACE="primes"

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster-name) CLUSTER_NAME="$2"; shift 2;;
    *) echo "Unknown arg: $1"; exit 1;;
  esac
done

echo "[info] Chequeando herramientas..."
command -v docker >/dev/null 2>&1 || { echo "docker no encontrado. Instala Docker."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "kubectl no encontrado. Instala kubectl."; exit 1; }
command -v kind >/dev/null 2>&1 || { echo "kind no encontrado. Instalalo o usa Minikube."; exit 1; }

echo "[info] Creando o verificando cluster kind: $CLUSTER_NAME"
if ! kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  kind create cluster --name "${CLUSTER_NAME}"
else
  echo "[info] Cluster ${CLUSTER_NAME} ya existe. Usando existente."
fi

echo "[info] Construyendo imagen API (target api)..."
docker build --target api -t ${API_IMAGE} .

echo "[info] Construyendo imagen WORKER (target worker)..."
docker build --target worker -t ${WORKER_IMAGE} .

echo "[info] Cargando imágenes en Kind cluster..."
kind load docker-image ${API_IMAGE} --name "${CLUSTER_NAME}"
kind load docker-image ${WORKER_IMAGE} --name "${CLUSTER_NAME}"

echo "[info] Crear namespace ${NAMESPACE} si no existe"
kubectl get namespace ${NAMESPACE} >/dev/null 2>&1 || kubectl create namespace ${NAMESPACE}

echo "[info] Aplicando manifests en k8s/"
kubectl apply -f k8s/ -n ${NAMESPACE}

echo "[info] Parcheando deployments con las imágenes locales"
# Actualizar imagen del deployment primes-api
kubectl -n ${NAMESPACE} set image deployment/primes-api api=${API_IMAGE} --record || true
# Actualizar imagen del deployment primes-worker
kubectl -n ${NAMESPACE} set image deployment/primes-worker worker=${WORKER_IMAGE} --record || true

echo "[info] Esperando pods listos (timeout 300s)"
# esperar todos los pods en el namespace hasta Ready
kubectl -n ${NAMESPACE} wait --for=condition=Ready pod -l app=primes-api --timeout=300s || true
kubectl -n ${NAMESPACE} wait --for=condition=Ready pod -l app=primes-worker --timeout=300s || true

echo "[info] Estado final de pods:" 
kubectl get pods -n ${NAMESPACE}

cat <<EOF

Despliegue completado.
Prueba rápida:
1) Port-forward API localmente:
   kubectl port-forward -n ${NAMESPACE} svc/primes-api-service 8000:8000
2) En otra terminal crea solicitud:
   curl -s -X POST http://localhost:8000/new -H "Content-Type: application/json" -d '{"cantidad":3,"digitos":10}' | jq -r '.id'
3) Consulta estado/resultados:
   curl http://localhost:8000/status/<ID>
   curl http://localhost:8000/result/<ID>

Si algo falla, revisa logs:
kubectl logs -n ${NAMESPACE} deployment/primes-api
kubectl logs -n ${NAMESPACE} deployment/primes-worker

EOF
