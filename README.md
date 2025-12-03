# 🎯 Sistema de Generación de Números Primos Distribuido

Este repositorio contiene una aplicación distribuida para generar números primos grandes (≥12 dígitos)
usando una arquitectura de microservicios: API REST (stateless), cola Redis y Workers que insertan los
resultados en PostgreSQL.

Objetivos clave:
- Crear solicitudes de generación (cantidad, dígitos) → `POST /new`
- Consultar progreso → `GET /status/:id`
- Obtener resultados → `GET /result/:id`

Mantén esta carpeta como punto único de entrada para despliegue en Killercoda y para presentación.

## Archivos importantes que quedan
- `README.md` (esta guía resumida)
- `DESPLIEGUE_KILLERCODA.md` (quickstart para Killercoda)  
- `DESPLIEGUE.md` (guía completa: Docker Compose, Kubernetes, local)  
- `k8s/` (manifiestos para Kubernetes)  
- `Dockerfile`, `docker-compose.yml`  
- `sql/init.sql` (schema)  
- `src/`, `include/` (código fuente)  
- `client.py` (cliente simple para demo)  
- `scripts/` (scripts de despliegue y demo)  

Si necesitas el resto de la documentación más extensa, está en los archivos enlazados arriba.

---

## Quickstart — Killercoda (recomendado para la sustentación)

1. Abre la sesión de Killercoda / cluster remoto provisto.
2. Crea el namespace y los secrets (Killercoda suele dar acceso a kubectl):

```bash
kubectl create namespace primes
kubectl create secret generic app-secret --from-literal=DATABASE_URL='host=postgres port=5432 dbname=primes user=primes_user password=primes_pass' -n primes
```

3. Aplica los recursos (Postgres, Redis, API, workers):

```bash
kubectl apply -f k8s/ -n primes
kubectl get pods -n primes --watch
```

4. Exponer el servicio API localmente para demo con `kubectl port-forward`:

```bash
kubectl port-forward -n primes svc/primes-api-service 8000:80
# En otra terminal
curl -s -X POST http://localhost:8000/new -H "Content-Type: application/json" -d '{"cantidad":2,"digitos":12}' | jq
```

Ver `DESPLIEGUE_KILLERCODA.md` para pasos con valores exactos y ejemplos listos para copiar.

---

## Quickstart — Docker Compose (desarrollo local)

```bash
docker-compose up -d
sleep 10
curl -X POST http://localhost:8000/new -H "Content-Type: application/json" -d '{"cantidad":3,"digitos":12}'
curl http://localhost:8000/status/<ID>
```

---

## API (resumen)

POST /new  — Crear solicitud
Body: {"cantidad": <1-1000>, "digitos": <2-20>} → {"id": "uuid"}

GET /status/:id  — Obtener progreso → {id, cantidad, digitos, generados}

GET /result/:id  — Obtener primos → {id, cantidad, primos: [..]}

---

## Notas sobre seguridad y calidad
- Primalidad garantizada: Miller-Rabin determinístico con bases fijas (soporta grandes números)  
- Prevención de duplicados: índice UNIQUE en `resultados(primo)` y claves compuestas  
- Operaciones DB con prepared statements para evitar SQL injection  

---

## Cambios recientes (limpieza de documentación)
He eliminado archivos de estado y resúmenes largos que no son necesarios para la ejecución ni el despliegue
en Killercoda. Para ver exactamente qué se eliminó, consulta `LIMPIEZA_REALIZADA.md`.

---

## Enlaces
- `DESPLIEGUE_KILLERCODA.md` — Quickstart Killercoda (recomendado)  
- `DESPLIEGUE.md` — Guía completa de despliegue  
- `REQUERIMIENTOS.md` — Especificación técnica  

Última actualización: 3 de Diciembre de 2025
