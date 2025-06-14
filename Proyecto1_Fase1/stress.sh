#!/bin/bash

# Script optimizado para desplegar contenedores de estrés
# Autor: Bismarck Romero - 201708880
# Fecha: Junio 2025

# Colores para mensajes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Número de contenedores a crear
NUM_CONTAINERS=10

echo -e "${YELLOW}Iniciando prueba de estrés optimizada con $NUM_CONTAINERS contenedores...${NC}"

# Verificar si Docker está instalado
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker no está instalado. Por favor instálalo primero.${NC}"
    exit 1
fi

# Función para detener contenedores en paralelo
stop_stress_containers() {
    echo -e "${YELLOW}Deteniendo contenedores de prueba de estrés...${NC}"
    
    # Obtener lista de contenedores de estrés que existen
    containers=$(docker ps -a --filter "name=stress-test-" --format "{{.Names}}" 2>/dev/null)
    
    if [ -n "$containers" ]; then
        # Detener todos en paralelo usando xargs
        echo "$containers" | xargs -n 1 -P 0 docker stop > /dev/null 2>&1
        
        # Eliminar todos en paralelo
        echo "$containers" | xargs -n 1 -P 0 docker rm > /dev/null 2>&1
        
        echo -e "   ${GREEN}Todos los contenedores de estrés han sido detenidos y eliminados.${NC}"
    else
        echo -e "   ${YELLOW}No se encontraron contenedores de estrés.${NC}"
    fi
}

# Función para limpiar contenedores de estrés con timeout
force_cleanup() {
    echo -e "${YELLOW}Forzando limpieza de contenedores...${NC}"
    docker ps -a --filter "name=stress-test-" -q | xargs -r docker rm -f > /dev/null 2>&1
}

# Capturar señal de interrupción (Ctrl+C)
trap 'echo -e "${YELLOW}Interrumpido por el usuario.${NC}"; force_cleanup; exit 0' INT

# Limpieza inicial rápida
force_cleanup

# Pre-descargar la imagen si no existe (solo una vez)
echo -e "${YELLOW}Verificando imagen de estrés...${NC}"
if ! docker images | grep -q "polinux/stress"; then
    echo -e "${YELLOW}Descargando imagen polinux/stress...${NC}"
    docker pull polinux/stress > /dev/null 2>&1
fi

# Crear contenedores en paralelo
echo -e "${YELLOW}Creando $NUM_CONTAINERS contenedores de estrés en paralelo...${NC}"

# Crear función para ejecutar un contenedor
run_container() {
    local i=$1
    local container_name="stress-test-$i"
    local cpu_cores=$((1 + $i % 4))
    local memory=$((256 + ($i * 64)))
    local timeout=60s # Modificar si se quiere mas o menos tiempo!!!
    
    docker run -d \
        --name $container_name \
        --rm \
        polinux/stress \
        stress --cpu $cpu_cores \
               --vm 1 \
               --vm-bytes ${memory}M \
               --timeout ${timeout} \
        > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "   ${GREEN} Contenedor $container_name (CPU: $cpu_cores, RAM: ${memory}MB)${NC}"
    else
        echo -e "   ${RED} Error en contenedor $container_name${NC}"
    fi
}

# Exportar la función para usar con xargs
export -f run_container
export GREEN RED YELLOW NC

# Ejecutar contenedores en paralelo
seq 1 $NUM_CONTAINERS | xargs -n 1 -P $NUM_CONTAINERS -I {} bash -c 'run_container {}'

# Verificar contenedores en ejecución
echo
running_containers=$(docker ps --filter "name=stress-test-" --format "{{.Names}}" | wc -l)
echo -e "${YELLOW}Contenedores de estrés en ejecución: ${GREEN}$running_containers/$NUM_CONTAINERS${NC}"

if [ $running_containers -gt 0 ]; then
    echo -e "${GREEN}Prueba de estrés iniciada. Los contenedores se ejecutarán durante 1 minuto.${NC}"
    echo -e "${YELLOW}Presiona Ctrl+C para detener la prueba antes de tiempo.${NC}"
    
	# Configuración al inicio del script
	DURATION_SECONDS=60        # Duración total en segundos
	PROGRESS_INTERVAL=15       # Intervalo de progreso en segundos
	ITERATIONS=$((DURATION_SECONDS / PROGRESS_INTERVAL))

	# En la función run_container
	timeout=${DURATION_SECONDS}s

	# En el bucle de monitoreo
	for i in $(seq 1 $ITERATIONS); do
	    sleep $PROGRESS_INTERVAL
	    remaining=$((DURATION_SECONDS - (i * PROGRESS_INTERVAL)))
	    if [ $remaining -gt 0 ]; then
		active=$(docker ps --filter "name=stress-test-" -q | wc -l)
		echo -e "${YELLOW}Tiempo restante: ${remaining}s - Contenedores activos: $active${NC}"
	    fi
	done
else
    echo -e "${RED}No se pudieron iniciar contenedores de estrés.${NC}"
    exit 1
fi

# Limpieza final
force_cleanup

echo -e "${GREEN}Prueba de estrés completada.${NC}"