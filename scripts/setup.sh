#!/bin/bash

# Script de instalación automática para el Sistema de Números Primos Distribuido
# Uso: ./setup.sh

set -e  # Salir si hay error

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Sistema de Números Primos Distribuido - Script de Setup      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Verificar dependencias
echo "✓ Verificando dependencias..."
MISSING=0

if ! command -v gcc &> /dev/null; then
    echo "✗ gcc no está instalado"
    MISSING=1
fi

if ! command -v make &> /dev/null; then
    echo "✗ make no está instalado"
    MISSING=1
fi

if ! command -v pkg-config &> /dev/null; then
    echo "✗ pkg-config no está instalado"
    MISSING=1
fi

if ! command -v psql &> /dev/null; then
    echo "✗ PostgreSQL client no está instalado"
    MISSING=1
fi

if ! command -v curl &> /dev/null; then
    echo "✗ curl no está instalado"
    MISSING=1
fi

if [ $MISSING -eq 1 ]; then
    echo ""
    echo "Instale las dependencias faltantes con:"
    echo "  sudo apt update && sudo apt install -y build-essential libpq-dev pkg-config postgresql-client curl"
    exit 1
fi

echo "✓ Todas las dependencias están disponibles"
echo ""

# Descargar Mongoose si es necesario
if [ ! -f include/mongoose.h ] || [ ! -f src/mongoose.c ]; then
    echo "⬇ Descargando Mongoose..."
    curl -L -o include/mongoose.h https://raw.githubusercontent.com/cesanta/mongoose/master/mongoose.h
    curl -L -o src/mongoose.c https://raw.githubusercontent.com/cesanta/mongoose/master/mongoose.c
    echo "✓ Mongoose descargado"
else
    echo "✓ Mongoose ya está presente"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Configuración de PostgreSQL                                  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

read -p "¿Desea configurar PostgreSQL automáticamente? (s/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Ss]$ ]]; then
    # Pedir contraseña
    echo "Ingrese la contraseña para el usuario primes_user:"
    read -s DB_PASSWORD
    echo ""
    
    echo "⚙ Creando usuario PostgreSQL..."
    sudo -u postgres psql -c "DROP USER IF EXISTS primes_user;" 2>/dev/null || true
    sudo -u postgres psql -c "CREATE USER primes_user WITH PASSWORD '$DB_PASSWORD';"
    
    echo "⚙ Creando base de datos..."
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS primes;" 2>/dev/null || true
    sudo -u postgres psql -c "CREATE DATABASE primes OWNER primes_user;"
    
    echo "⚙ Aplicando esquema..."
    export DATABASE_URL="host=localhost port=5432 dbname=primes user=primes_user password=$DB_PASSWORD"
    psql "$DATABASE_URL" -f sql/init.sql
    
    echo "✓ PostgreSQL configurado correctamente"
    echo ""
    echo "Guarde estas credenciales:"
    echo "  DATABASE_URL: $DATABASE_URL"
    echo ""
else
    echo "Asegúrese de configurar PostgreSQL manualmente:"
    echo "1. Crear usuario: sudo -u postgres createuser primes_user --pwprompt"
    echo "2. Crear BD: sudo -u postgres createdb primes --owner primes_user"
    echo "3. Aplicar esquema: psql \$DATABASE_URL -f sql/init.sql"
    echo ""
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Compilación                                                   ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo "🔨 Compilando..."
make clean
make

echo "✓ Compilación exitosa!"
echo ""

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Setup Completado                                             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo "Para iniciar el servidor:"
echo ""
if [ -z "$DB_PASSWORD" ]; then
    echo "  export DATABASE_URL=\"host=localhost port=5432 dbname=primes user=primes_user password=<PASSWORD>\""
else
    echo "  export DATABASE_URL=\"$DATABASE_URL\""
fi
echo "  ./server"
echo ""

echo "Para usar Docker Compose:"
echo "  docker-compose up -d"
echo ""

echo "Para usar Kubernetes:"
echo "  kubectl create namespace primes"
echo "  docker build -t primes-generator ."
echo "  kubectl apply -f k8s/init-sql-configmap.yaml -n primes"
echo "  kubectl apply -f k8s/postgres.yaml -n primes"
echo "  kubectl apply -f k8s/configmap.yaml -n primes"
echo "  kubectl apply -f k8s/deployment.yaml -n primes"
echo "  kubectl apply -f k8s/service.yaml -n primes"
echo ""
