#!/bin/bash
# Demo script - Generador de Primos en Kubernetes
# Uso: ./scripts/demo-sustentacion.sh [cantidad] [digitos]

set -e

CANTIDAD=${1:-3}
DIGITOS=${2:-10}
NAMESPACE="primes"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎬 DEMO: Generador de Números Primos Distribuido"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. Mostrar estado del cluster
echo "1️⃣  Estado del Cluster Kubernetes"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get pods -n $NAMESPACE --no-headers | awk '{print "   " $0}'
echo ""

# 2. Verificar health de API
echo "2️⃣  Verificando Health de API"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
HEALTH=$(kubectl run -n $NAMESPACE health-check --image=curlimages/curl --rm -i --restart=Never \
  -- curl -s http://primes-api-service/ 2>/dev/null || echo '{}')
echo "   API Response: $HEALTH"
echo ""

# 3. Crear solicitud
echo "3️⃣  Creando Solicitud: $CANTIDAD primos de $DIGITOS dígitos"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
RESPONSE=$(kubectl run -n $NAMESPACE new-request --image=curlimages/curl --rm -i --restart=Never \
  -- curl -s -X POST http://primes-api-service/new \
  -H "Content-Type: application/json" \
  -d "{\"cantidad\":$CANTIDAD,\"digitos\":$DIGITOS}" 2>/dev/null)

ID=$(echo "$RESPONSE" | grep -oP '(?<="id":")[^"]*' || echo "ERROR")

if [ "$ID" == "ERROR" ]; then
  echo "   ❌ Error al crear solicitud"
  echo "   Response: $RESPONSE"
  exit 1
fi

echo "   ✅ ID Generado: $ID"
echo ""

# 4. Esperar procesamiento
echo "4️⃣  Esperando Procesamiento..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for i in {1..10}; do
  STATUS=$(kubectl run -n $NAMESPACE status-check-$i --image=curlimages/curl --rm -i --restart=Never \
    -- curl -s http://primes-api-service/status/$ID 2>/dev/null)
  
  GENERADOS=$(echo "$STATUS" | grep -oP '(?<="generados":)\d+' || echo "0")
  
  printf "   Intento %d: %d/%d números generados\r" "$i" "$GENERADOS" "$CANTIDAD"
  
  if [ "$GENERADOS" -eq "$CANTIDAD" ]; then
    echo ""
    break
  fi
  
  sleep 1
done

echo ""
echo ""

# 5. Obtener resultados finales
echo "5️⃣  Resultados Finales"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

RESULT=$(kubectl run -n $NAMESPACE final-result --image=curlimages/curl --rm -i --restart=Never \
  -- curl -s http://primes-api-service/result/$ID 2>/dev/null)

echo "$RESULT" | jq '.' 2>/dev/null || echo "   $RESULT"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Demo completada exitosamente!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
