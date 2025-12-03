#!/bin/bash

# EJEMPLOS PRÁCTICOS DE USO
# Estos son comandos listos para copiar y pegar

set -e

echo "==================================================================="
echo "  EJEMPLOS PRÁCTICOS - Sistema de Generación de Números Primos"
echo "==================================================================="

# ============================================================
# EJEMPLO 1: Uso Simple con CURL
# ============================================================

echo ""
echo "EJEMPLO 1: Uso Simple con CURL"
echo "-------------------------------------------------------------------"

echo ""
echo "Paso 1: Crear una solicitud de 5 números primos de 12 dígitos"
echo ""
echo "$ curl -X POST http://localhost:8000/new \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"cantidad\":5,\"digitos\":12}'"
echo ""

# Descomentar la siguiente línea si el servidor está corriendo:
# REQ_ID=$(curl -s -X POST http://localhost:8000/new \
#     -H "Content-Type: application/json" \
#     -d '{"cantidad":5,"digitos":12}' | jq -r '.id')
# echo "Response: {\"id\":\"$REQ_ID\"}"

echo ""
echo "Paso 2: Consultar el estado (reemplaza UUID con el ID recibido)"
echo ""
echo "$ curl http://localhost:8000/status/550e8400-e29b-41d4-a716-446655440000"
echo ""
echo "Response:"
echo "{"
echo "  \"id\": \"550e8400-e29b-41d4-a716-446655440000\","
echo "  \"cantidad\": 5,"
echo "  \"digitos\": 12,"
echo "  \"generados\": 3"
echo "}"
echo ""

echo ""
echo "Paso 3: Obtener los números finales"
echo ""
echo "$ curl http://localhost:8000/result/550e8400-e29b-41d4-a716-446655440000"
echo ""
echo "Response:"
echo "{"
echo "  \"id\": \"550e8400-e29b-41d4-a716-446655440000\","
echo "  \"primos\": ["
echo "    \"123456789019\","
echo "    \"456789012347\","
echo "    \"789012345671\","
echo "    \"234567890137\","
echo "    \"567890123427\""
echo "  ]"
echo "}"

# ============================================================
# EJEMPLO 2: Script de Monitoreo
# ============================================================

echo ""
echo ""
echo "EJEMPLO 2: Script de Monitoreo en Tiempo Real"
echo "-------------------------------------------------------------------"

cat > /tmp/monitor_example.sh << 'EOF'
#!/bin/bash

# Guardar el ID de solicitud
REQUEST_ID="550e8400-e29b-41d4-a716-446655440000"

# Monitorear cada 2 segundos
while true; do
  STATUS=$(curl -s http://localhost:8000/status/$REQUEST_ID)
  GENERADOS=$(echo $STATUS | jq '.generados')
  CANTIDAD=$(echo $STATUS | jq '.cantidad')
  
  echo "[$(date +'%H:%M:%S')] Progreso: $GENERADOS/$CANTIDAD"
  
  if [ "$GENERADOS" -eq "$CANTIDAD" ]; then
    echo "✓ ¡Completado!"
    break
  fi
  
  sleep 2
done

# Mostrar resultados
echo ""
echo "Números primos generados:"
curl -s http://localhost:8000/result/$REQUEST_ID | jq '.primos[]'
EOF

echo "$ cat > monitor.sh << 'EOF'"
cat /tmp/monitor_example.sh
echo "EOF"
echo ""
echo "$ bash monitor.sh"

# ============================================================
# EJEMPLO 3: Múltiples Solicitudes
# ============================================================

echo ""
echo ""
echo "EJEMPLO 3: Crear Múltiples Solicitudes Simultáneas"
echo "-------------------------------------------------------------------"

cat > /tmp/multiple_example.sh << 'EOF'
#!/bin/bash

# Crear 10 solicitudes en paralelo
IDS=()

echo "Creando 10 solicitudes..."
for i in {1..10}; do
  ID=$(curl -s -X POST http://localhost:8000/new \
    -H "Content-Type: application/json" \
    -d '{"cantidad":3,"digitos":12}' | jq -r '.id')
  IDS+=("$ID")
  echo "[$i] ID: $ID"
done

# Esperar a que todas se completen
echo ""
echo "Esperando completación..."
COMPLETED=0
while [ $COMPLETED -lt ${#IDS[@]} ]; do
  COMPLETED=0
  for ID in "${IDS[@]}"; do
    GENERADOS=$(curl -s http://localhost:8000/status/$ID | jq '.generados // 0')
    CANTIDAD=$(curl -s http://localhost:8000/status/$ID | jq '.cantidad // 0')
    if [ "$GENERADOS" -eq "$CANTIDAD" ]; then
      COMPLETED=$((COMPLETED + 1))
    fi
  done
  echo "Completadas: $COMPLETED/${#IDS[@]}"
  sleep 1
done

echo ""
echo "¡Todas completadas!"
EOF

echo "$ cat > batch.sh << 'EOF'"
cat /tmp/multiple_example.sh
echo "EOF"
echo ""
echo "$ bash batch.sh"

# ============================================================
# EJEMPLO 4: Cliente Python
# ============================================================

echo ""
echo ""
echo "EJEMPLO 4: Usar el Cliente Python"
echo "-------------------------------------------------------------------"

echo ""
echo "Modo interactivo:"
echo "$ python3 client.py"
echo ""

echo "Modo rápido (3 números, 12 dígitos):"
echo "$ python3 client.py quick"
echo ""

echo "Ejemplo de código Python personalizado:"
cat > /tmp/custom_client_example.py << 'EOF'
from client import PrimesClient

# Crear cliente
client = PrimesClient("http://localhost:8000")

# Crear solicitud de 20 números primos de 14 dígitos
request_id = client.new_request(cantidad=20, digitos=14)

if request_id:
    print(f"\nEsperando completación...")
    if client.wait_for_completion(request_id, max_wait=600):
        result = client.get_result(request_id)
        
        if result:
            print(f"\n✓ Generados {len(result['primos'])} números primos:")
            for primo in result['primos']:
                print(f"  - {primo}")
    else:
        print("Timeout alcanzado")
EOF

echo "$ python3 << 'EOF'"
cat /tmp/custom_client_example.py
echo "EOF"

# ============================================================
# EJEMPLO 5: Stress Test
# ============================================================

echo ""
echo ""
echo "EJEMPLO 5: Stress Test - Carga Alta"
echo "-------------------------------------------------------------------"

cat > /tmp/stress_test_example.sh << 'EOF'
#!/bin/bash

# Crear 50 solicitudes
echo "Creando 50 solicitudes simultáneamente..."
for i in {1..50}; do
  (
    curl -s -X POST http://localhost:8000/new \
      -H "Content-Type: application/json" \
      -d '{"cantidad":5,"digitos":12}' > /dev/null
    echo "[$i] Solicitud creada"
  ) &
done

# Esperar a que todas terminen
wait
echo "Todas las solicitudes han sido creadas"

# Monitorear la cola
echo ""
echo "Monitoreando Redis queue:"
watch -n 1 'redis-cli LLEN primes:queue'
EOF

echo "$ cat > stress_test.sh << 'EOF'"
cat /tmp/stress_test_example.sh
echo "EOF"
echo ""
echo "$ bash stress_test.sh"

# ============================================================
# EJEMPLO 6: Escalado Dinámico
# ============================================================

echo ""
echo ""
echo "EJEMPLO 6: Escalar Workers Dinámicamente"
echo "-------------------------------------------------------------------"

echo ""
echo "Ver workers actuales:"
echo "$ docker-compose ps | grep worker"
echo ""

echo "Crear una solicitud grande:"
echo "$ curl -X POST http://localhost:8000/new \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"cantidad\":100,\"digitos\":12}'"
echo ""

echo "Monitorear progreso en una terminal:"
echo "$ watch -n 1 'curl -s http://localhost:8000/status/ID_AQUI | jq .'"
echo ""

echo "Escalar a 20 workers en otra terminal:"
echo "$ docker-compose up -d --scale worker=20"
echo ""

echo "Observar aceleración del procesamiento ✓"

# ============================================================
# EJEMPLO 7: Verificar BD
# ============================================================

echo ""
echo ""
echo "EJEMPLO 7: Verificar Base de Datos"
echo "-------------------------------------------------------------------"

echo ""
echo "Ver solicitudes:"
echo "$ psql \$DATABASE_URL -c 'SELECT id, cantidad, digitos, generados FROM solicitudes;'"
echo ""

echo "Contar números primos generados:"
echo "$ psql \$DATABASE_URL -c 'SELECT COUNT(*) FROM resultados;'"
echo ""

echo "Ver números de una solicitud específica:"
echo "$ psql \$DATABASE_URL -c \"SELECT primo FROM resultados WHERE solicitud_id = 'ID_AQUI';\""

# ============================================================
# EJEMPLO 8: Limpiar y Reiniciar
# ============================================================

echo ""
echo ""
echo "EJEMPLO 8: Limpiar y Reiniciar"
echo "-------------------------------------------------------------------"

echo ""
echo "Detener todos los servicios:"
echo "$ docker-compose down"
echo ""

echo "Detener Y eliminar datos (limpiar todo):"
echo "$ docker-compose down -v"
echo ""

echo "Reconstruir imágenes:"
echo "$ docker-compose build --no-cache"
echo ""

echo "Reiniciar con BD limpia:"
echo "$ docker-compose up -d"

# ============================================================
# RESUMEN
# ============================================================

echo ""
echo ""
echo "==================================================================="
echo "  RESUMEN DE EJEMPLOS"
echo "==================================================================="

echo ""
echo "1. CURL simple"
echo "   POST /new → GET /status → GET /result"
echo ""

echo "2. Monitoreo en tiempo real"
echo "   watch -n 1 'curl ... | jq .'"
echo ""

echo "3. Múltiples solicitudes"
echo "   for i in {1..10}; do curl ...; done"
echo ""

echo "4. Cliente Python"
echo "   python3 client.py quick"
echo ""

echo "5. Stress test"
echo "   50+ solicitudes simultáneas"
echo ""

echo "6. Escalado dinámico"
echo "   docker-compose up -d --scale worker=20"
echo ""

echo "7. Verificar BD"
echo "   psql \$DATABASE_URL -c ..."
echo ""

echo "8. Limpiar"
echo "   docker-compose down -v"
echo ""

echo "==================================================================="
echo ""
echo "✓ Todos los ejemplos están listos para usar"
echo "✓ Solo asegúrate de que docker-compose esté corriendo"
echo "✓ Copia y pega los comandos en tu terminal"
echo ""
