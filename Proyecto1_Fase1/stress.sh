#!/bin/bash

# Script para desplegar 10 contenedores para estresar CPU y RAM
# Autor: Bismarck Romero - 201708880
# Fecha: Junio 2025

# Colores para mensajes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Número de contenedores a crear
NUM_CONTAINERS=10

echo -e "${YELLOW}Iniciando prueba de estrés con $NUM_CONTAINERS contenedores...${NC}"

# Verificar si Docker está instalado
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker no está instalado. Por favor instálalo primero.${NC}"
    exit 1
fi

# Función para detener todos los contenedores de estrés
stop_stress_containers() {
    echo -e "${YELLOW}Deteniendo contenedores de prueba de estrés...${NC}"
    for i in $(seq 1 $NUM_CONTAINERS); do
        container_name="stress-test-$i"
        if docker ps -a | grep -q $container_name; then
            docker stop $container_name > /dev/null 2>&1
            docker rm $container_name > /dev/null 2>&1
            echo -e "   ${GREEN}Contenedor $container_name detenido y eliminado.${NC}"
        fi
    done
}

# Capturar señal de interrupción (Ctrl+C)
trap 'echo -e "${YELLOW}Interrumpido por el usuario.${NC}"; stop_stress_containers; exit 0' INT

# Detener contenedores existentes de pruebas anteriores
stop_stress_containers

# Crear y ejecutar los contenedores de estrés
echo -e "${YELLOW}Creando $NUM_CONTAINERS contenedores de estrés...${NC}"

for i in $(seq 1 $NUM_CONTAINERS); do
    container_name="stress-test-$i"

    # Calcular valores de estrés diferentes para cada contenedor
    # para distribuir la carga
    cpu_cores=$((1 + $i % 4))  # Entre 1 y 4 núcleos
    memory=$((256 + ($i * 64)))  # Entre 256MB y 896MB

    echo -e "${YELLOW}Iniciando contenedor $container_name:${NC}"
    echo -e "   - CPU: $cpu_cores núcleos"
    echo -e "   - Memoria: $memory MB"

    docker run -d \
        --name $container_name \
        --rm \
        polinux/stress \
        stress --cpu $cpu_cores \
               --vm 1 \
               --vm-bytes ${memory}M \
               --timeout 300s \
        > /dev/null

    if [ $? -eq 0 ]; then
        echo -e "   ${GREEN}Contenedor $container_name iniciado correctamente.${NC}"
    else
        echo -e "   ${RED}Error al iniciar el contenedor $container_name.${NC}"
    fi
done

# Mostrar todos los contenedores en ejecución
echo -e "${YELLOW}Contenedores de estrés en ejecución:${NC}"
docker ps | grep "stress-test"

echo -e "${GREEN}Prueba de estrés iniciada. Los contenedores se ejecutarán durante 1 minuto.${NC}"
echo -e "${YELLOW}Presiona Ctrl+C para detener la prueba antes de tiempo.${NC}"

# Esperar a que todos los contenedores terminen (1 minuto = 60 segundos)
sleep 60

# Detener todos los contenedores si aún están en ejecución
stop_stress_containers

echo -e "${GREEN}Prueba de estrés completada.${NC}"