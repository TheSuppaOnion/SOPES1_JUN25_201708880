#!/bin/bash

# Script para instalar y configurar los módulos del Kernel
# Autor: Bismarck Romero - 201708880
# Fecha: Junio 2025

# Colores para mensajes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Iniciando instalación de módulos del kernel...${NC}"

# Verificar si se está ejecutando como root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Este script requiere privilegios de superusuario.${NC}"
    echo -e "${YELLOW}Por favor ejecuta: sudo $0${NC}"
    exit 1
fi

# Navegar al directorio de módulos
cd "$(dirname "$0")/Modulos" || {
    echo -e "${RED}No se pudo acceder al directorio de módulos.${NC}"
    exit 1
}

# Compilar los módulos
echo -e "${YELLOW}Compilando módulos...${NC}"
make clean
make

# Verificar que la compilación fue exitosa
if [ $? -ne 0 ]; then
    echo -e "${RED}Error al compilar los módulos.${NC}"
    exit 1
fi

# Descargar módulos existentes si están cargados
if lsmod | grep -q "cpu_201708880"; then
    echo -e "${YELLOW}Descargando módulo CPU existente...${NC}"
    rmmod cpu_201708880
fi

if lsmod | grep -q "ram_201708880"; then
    echo -e "${YELLOW}Descargando módulo RAM existente...${NC}"
    rmmod ram_201708880
fi

# Cargar los módulos
echo -e "${YELLOW}Cargando módulos...${NC}"
insmod cpu_201708880.ko
insmod ram_201708880.ko

# Verificar que los módulos se cargaron correctamente
if lsmod | grep -q "cpu_201708880" && lsmod | grep -q "ram_201708880"; then
    echo -e "${GREEN}Módulos cargados exitosamente.${NC}"
else
    echo -e "${RED}Error al cargar los módulos.${NC}"
    exit 1
fi

# Verificar la creación de archivos en /proc
if [ -f /proc/cpu_201708880 ] && [ -f /proc/ram_201708880 ]; then
    echo -e "${GREEN}Archivos en /proc creados correctamente.${NC}"
    echo -e "${YELLOW}Datos de CPU:${NC}"
    cat /proc/cpu_201708880
    echo -e "${YELLOW}Datos de RAM:${NC}"
    cat /proc/ram_201708880
else
    echo -e "${RED}Error: No se encontraron los archivos en /proc.${NC}"
    exit 1
fi

echo -e "${GREEN}Instalación y configuración de módulos completada.${NC}"
