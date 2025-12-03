#!/bin/bash

# Script de prueba de API
# Uso: ./test-api.sh

API_URL="${1:-http://localhost:8000}"
QUANTITY="${2:-5}"
DIGITS="${3:-12}"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Test de API - Sistema de Números Primos                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "URL del API: $API_URL"
echo "Cantidad de primos a generar: $QUANTITY"
echo "Dígitos por primo: $DIGITS"
echo ""

# Test 1: Crear solicitud
echo "═══════════════════════════════════════════════════════════════════"
echo "TEST 1: Crear nueva solicitud (POST /new)"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

RESPONSE=$(curl -s -X POST "$API_URL/new" \
  -H "Content-Type: application/json" \
  -d "{\"cantidad\":$QUANTITY,\"digitos\":$DIGITS}")

echo "Respuesta:"
echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
echo ""

# Extraer ID
REQUEST_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4)

if [ -z "$REQUEST_ID" ]; then
    echo "✗ Error: No se pudo extraer el ID de la solicitud"
    exit 1
fi

echo "✓ Solicitud creada con ID: $REQUEST_ID"
echo ""

# Esperar un poco
echo "Esperando procesamiento..."
for i in {1..10}; do
    sleep 1
    echo -n "."
done
echo ""
echo ""

# Test 2: Consultar estado
echo "═══════════════════════════════════════════════════════════════════"
echo "TEST 2: Consultar estado (GET /status/{id})"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

STATUS=$(curl -s "$API_URL/status/$REQUEST_ID")
echo "Respuesta:"
echo "$STATUS" | jq . 2>/dev/null || echo "$STATUS"
echo ""

GENERADOS=$(echo "$STATUS" | grep -o '"generados":[0-9]*' | cut -d':' -f2)
echo "✓ Números primos generados hasta ahora: $GENERADOS"
echo ""

# Test 3: Obtener resultados
echo "═══════════════════════════════════════════════════════════════════"
echo "TEST 3: Obtener resultados (GET /result/{id})"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

RESULTS=$(curl -s "$API_URL/result/$REQUEST_ID")
echo "Respuesta:"
echo "$RESULTS" | jq . 2>/dev/null || echo "$RESULTS"
echo ""

COUNT=$(echo "$RESULTS" | grep -o '"primos":\[' | wc -l)
if [ $COUNT -gt 0 ]; then
    echo "✓ Resultados obtenidos correctamente"
else
    echo "⚠ Aún no hay resultados disponibles (esto es normal si el procesamiento no ha terminado)"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "Test completado"
echo "═══════════════════════════════════════════════════════════════════"
