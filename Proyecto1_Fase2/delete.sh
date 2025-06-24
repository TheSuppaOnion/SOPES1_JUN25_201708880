#!/bin/bash

# Script para eliminar todos los servicios utilizados
# Autor: Bismarck Romero - 201708880
# Fecha: Junio 2025

# Colores para mensajes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Iniciando limpieza de servicios...${NC}"

# Verificar si Docker está instalado
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker no está instalado. No hay nada que limpiar.${NC}"
    exit 0
fi

# Navegar al directorio del proyecto
cd "$(dirname "$0")" || {
    echo -e "${RED}No se pudo acceder al directorio del proyecto.${NC}"
    exit 1
}

# Detener contenedores de la aplicación
echo -e "${YELLOW}Deteniendo contenedores de la aplicación...${NC}"
docker-compose down -v

# Eliminar volúmenes
echo -e "${YELLOW}Eliminando volúmenes...${NC}"
docker volume rm proyecto1_fase1_mysql-data 2>/dev/null || true

# Descargar módulos del kernel
echo -e "${YELLOW}Descargando módulos del kernel...${NC}"
if lsmod | grep -q "cpu_201708880"; then
    sudo rmmod cpu_201708880
    echo -e "${GREEN}Módulo CPU descargado.${NC}"
fi

if lsmod | grep -q "ram_201708880"; then
    sudo rmmod ram_201708880
    echo -e "${GREEN}Módulo RAM descargado.${NC}"
fi

if lsmod | grep -q "procesos_201708880"; then
    sudo rmmod procesos_201708880
    echo -e "${GREEN}Módulo procesos descargado.${NC}"
fi

# Opcional: Eliminar imágenes de Docker
read -p "¿Deseas eliminar también las imágenes Docker? (s/n): " respuesta
if [[ $respuesta =~ ^[Ss]$ ]]; then
    echo -e "${YELLOW}Eliminando imágenes Docker...${NC}"
    # Obtener las imágenes relacionadas con el proyecto
    images=$(docker images | grep "bismarckr/monitor" | awk '{print $3}')
    if [ -n "$images" ]; then
        docker rmi -f $images
        echo -e "${GREEN}Imágenes Docker eliminadas.${NC}"
    else
        echo -e "${GREEN}No hay imágenes Docker para eliminar.${NC}"
    fi
fi

echo -e "${GREEN}Limpieza completada.${NC}"
