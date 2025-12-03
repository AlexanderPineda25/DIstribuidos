#!/usr/bin/env bash
set -euo pipefail

# deploy_remote.sh
# Construye imágenes para api y worker, las taggea con Docker Hub y las pushea,
# luego genera manifest remotos (reemplaza imagenes en los deployments) y aplica
# todo en el cluster (útil para Killercoda o clusters remotos).
#
# Uso:
#   ./scripts/deploy_remote.sh DOCKERHUB_USER TAG
# Ejemplo:
#   ./scripts/deploy_remote.sh tu_usuario v1

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 DOCKERHUB_USER TAG"
  exit 2
fi

DOCKERHUB_USER="$1"
TAG="$2"
NAMESPACE="primes"

API_IMAGE="${DOCKERHUB_USER}/primes-api:${TAG}"
WORKER_IMAGE="${DOCKERHUB_USER}/primes-worker:${TAG}"

echo "[info] Build imagen API (target api) -> ${API_IMAGE}"
docker build --target api -t "${API_IMAGE}" .

echo "[info] Build imagen WORKER (target worker) -> ${WORKER_IMAGE}"
docker build --target worker -t "${WORKER_IMAGE}" .

echo "[info] Pusheando imágenes a Docker Hub"
docker push "${API_IMAGE}"
docker push "${WORKER_IMAGE}"

echo "[info] Preparando manifests temporales..."
TMPDIR=$(mktemp -d)
cp -r k8s/* "${TMPDIR}/"

# Reemplazar imagen en deployment.yaml y worker-deployment.yaml
sed -i "s|image: .*primes-api.*|image: ${API_IMAGE}|g" "${TMPDIR}/deployment.yaml"
sed -i "s|imagePullPolicy: Never|imagePullPolicy: IfNotPresent|g" "${TMPDIR}/deployment.yaml" || true

sed -i "s|image: .*primes-worker.*|image: ${WORKER_IMAGE}|g" "${TMPDIR}/worker-deployment.yaml"
sed -i "s|imagePullPolicy: Never|imagePullPolicy: IfNotPresent|g" "${TMPDIR}/worker-deployment.yaml" || true

echo "[info] Crear namespace ${NAMESPACE} si no existe"
kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1 || kubectl create namespace "${NAMESPACE}"

echo "[info] Aplicando manifests (incluye postgres, redis, services, deployments)"
kubectl apply -f "${TMPDIR}/" -n "${NAMESPACE}"

echo "[info] Limpieza: removiendo temporales ${TMPDIR}"
rm -rf "${TMPDIR}"

echo "[info] Despliegue remoto completado. Comprueba pods: kubectl get pods -n ${NAMESPACE}"
echo "Si las imagenes son privadas, crea un secret docker-registry y vuelve a aplicar los deployments con 'imagePullSecrets'."

cat <<EOF

Comprobación rápida:

kubectl get pods -n ${NAMESPACE}

# Port-forward para pruebas locales
kubectl port-forward -n ${NAMESPACE} svc/primes-api-service 8000:8000

# En otra terminal prueba:
curl -X POST http://localhost:8000/new -H "Content-Type: application/json" -d '{"cantidad":3,"digitos":10}'

EOF
