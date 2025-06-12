#!/bin/bash

# Script para desplegar los contenedores de la aplicación
# Autor: Bismarck Romero - 201708880
# Fecha: Junio 2025

# Colores para mensajes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Iniciando despliegue de la aplicación...${NC}"

# Verificar si Docker y Docker Compose están instalados
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker no está instalado. Por favor instálalo primero.${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Docker Compose no está instalado. Por favor instálalo primero.${NC}"
    exit 1
fi

# Verificar si los módulos del kernel están cargados
if ! lsmod | grep -q "cpu_201708880" || ! lsmod | grep -q "ram_201708880"; then
    echo -e "${YELLOW}Los módulos del kernel no están cargados.${NC}"
    echo -e "${YELLOW}Ejecutando script de instalación de módulos...${NC}"

    # Ejecutar el script de instalación de módulos
    sudo ./setup-modules.sh

    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al cargar los módulos del kernel.${NC}"
        exit 1
    fi
fi

# Navegar al directorio del proyecto
cd "$(dirname "$0")" || {
    echo -e "${RED}No se pudo acceder al directorio del proyecto.${NC}"
    exit 1
}

# Verificar si todos los contenedores ya existen
if docker ps -a | grep -q "proyecto1_fase1_api_1" && \
   docker ps -a | grep -q "proyecto1_fase1_agente_1" && \
   docker ps -a | grep -q "proyecto1_fase1_frontend_1" && \
   docker ps -a | grep -q "mysql"; then
    # Los contenedores ya existen, simplemente iniciarlos
    echo -e "${YELLOW}Los contenedores ya existen. Iniciando servicios...${NC}"
    docker-compose up -d
else
    # Los contenedores no existen, construir e iniciar
    echo -e "${YELLOW}Los contenedores no existen. Construyendo e iniciando servicios...${NC}"
    
    # Detener contenedores existentes si hay alguno
    echo -e "${YELLOW}Deteniendo contenedores existentes...${NC}"
    docker-compose down

    # Eliminar el volumen de MySQL para forzar reinicialización
    echo -e "${YELLOW}Eliminando volumen de MySQL...${NC}"
    docker volume rm proyecto1_fase1_mysql-data 2>/dev/null || true

    # Iniciar MySQL primero
    echo -e "${YELLOW}Iniciando MySQL...${NC}"
    docker-compose up -d --build mysql

    # Esperar a que MySQL esté listo
    echo -e "${YELLOW}Esperando a que MySQL esté listo...${NC}"
    sleep 15

    # Verificar que la base de datos esté correctamente inicializada
    echo -e "${YELLOW}Verificando inicialización de la base de datos...${NC}"
    if ! docker exec -i mysql mysql -u monitor -pmonitor123 -e "USE monitoring; SHOW TABLES;" 2>/dev/null | grep -q "cpu_metrics"; then
        echo -e "${RED}Las tablas no se crearon correctamente.${NC}"
        echo -e "${YELLOW}Ejecutando script de inicialización manualmente...${NC}"

        # Ejecutar el script de inicialización manualmente
        docker exec -i mysql mysql -u monitor -pmonitor123 < ./Backend/BD/init.sql

        # Verificar nuevamente
        if ! docker exec -i mysql mysql -u monitor -pmonitor123 -e "USE monitoring; SHOW TABLES;" 2>/dev/null | grep -q "cpu_metrics"; then
            echo -e "${RED}Error: No se pudieron crear las tablas.${NC}"
            exit 1
        fi
    fi

    # Iniciar el resto de los servicios
    echo -e "${YELLOW}Iniciando el resto de los servicios...${NC}"
    docker-compose up -d --build
fi

# Verificar que todos los servicios estén funcionando
echo -e "${YELLOW}Verificando el estado de los servicios...${NC}"
docker-compose ps

echo -e "${GREEN}Aplicación desplegada correctamente.${NC}"
echo -e "${GREEN}Frontend: http://localhost:8080${NC}"
echo -e "${GREEN}API: http://localhost:3000${NC}"