#!/bin/bash

# Script para eliminar todos los servicios de Fase 2
# Autor: Bismarck Romero - 201708880
# Fecha: Junio 2025

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║               LIMPIEZA COMPLETA - FASE 2                  ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"

# Función para verificar si un comando existe
command_exists() {
    command -v "$1" &> /dev/null
}

# Función para limpiar MySQL correctamente según tu configuración
cleanup_mysql() {
    echo -e "${YELLOW}6. Limpiando base de datos MySQL...${NC}"
    
    if ! command_exists mysql; then
        echo -e "${BLUE}  → MySQL no está instalado, saltando...${NC}"
        return
    fi
    
    if ! sudo systemctl is-active --quiet mysql; then
        echo -e "${YELLOW}  → MySQL no está ejecutándose${NC}"
        read -p "$(echo -e ${BLUE}¿Quieres intentar iniciarlo para limpiar? (s/N): ${NC})" start_mysql
        
        if [[ $start_mysql =~ ^[SsYy]$ ]]; then
            sudo systemctl start mysql
            sleep 3
        else
            echo -e "${BLUE}  → Saltando limpieza de MySQL${NC}"
            return
        fi
    fi
    
    # Mostrar estado actual de la base de datos
    echo -e "${BLUE}  → Estado actual de la base de datos:${NC}"
    if mysql -u monitor -pmonitor123 -e "USE monitoring; SHOW TABLES;" 2>/dev/null; then
        echo -e "${YELLOW}    Base de datos 'monitoring' existe con las siguientes tablas:${NC}"
        mysql -u monitor -pmonitor123 -e "USE monitoring; SHOW TABLES;" 2>/dev/null | grep -v "Tables_in_monitoring" | sed 's/^/      - /'
    else
        echo -e "${BLUE}    No se puede acceder o no existe la base de datos 'monitoring'${NC}"
    fi
    
    read -p "$(echo -e ${YELLOW}¿Eliminar COMPLETAMENTE la base de datos 'monitoring'? (s/N): ${NC})" delete_db
    
    if [[ $delete_db =~ ^[SsYy]$ ]]; then
        echo -e "${YELLOW}  → Intentando limpieza como usuario monitor...${NC}"
        
        # Primero eliminar todas las tablas como usuario monitor
        echo -e "${BLUE}    Eliminando tablas existentes...${NC}"
        mysql -u monitor -pmonitor123 2>/dev/null <<EOF
USE monitoring;
DROP TABLE IF EXISTS cpu_metrics;
DROP TABLE IF EXISTS ram_metrics;
DROP TABLE IF EXISTS process_metrics;
DROP TABLE IF EXISTS metrics_cache;
DROP TABLE IF EXISTS metrics;
SELECT 'Tablas eliminadas' AS status;
EOF
        
        # Luego eliminar la base de datos completa
        echo -e "${BLUE}    Eliminando base de datos...${NC}"
        mysql -u monitor -pmonitor123 -e "DROP DATABASE IF EXISTS monitoring;" 2>/dev/null
        
        # Intentar eliminar el usuario usando sudo (como root necesita sudo en tu sistema)
        echo -e "${BLUE}    Intentando eliminar usuario monitor...${NC}"
        if sudo mysql -u root -e "DROP USER IF EXISTS 'monitor'@'localhost'; DROP USER IF EXISTS 'monitor'@'%'; FLUSH PRIVILEGES;" 2>/dev/null; then
            echo -e "${GREEN}  ✓ Base de datos y usuario eliminados completamente (método sudo)${NC}"
        else
            echo -e "${YELLOW}  ⚠ Base de datos eliminada, pero usuario monitor puede persistir${NC}"
            echo -e "${BLUE}    Para eliminar manualmente: sudo mysql -u root${NC}"
            echo -e "${BLUE}    DROP USER IF EXISTS 'monitor'@'localhost';${NC}"
            echo -e "${BLUE}    DROP USER IF EXISTS 'monitor'@'%';${NC}"
        fi
        
        # Verificar limpieza
        echo -e "${BLUE}  → Verificando limpieza...${NC}"
        if mysql -u monitor -pmonitor123 -e "USE monitoring; SELECT 1;" 2>/dev/null; then
            echo -e "${RED}    ✗ Base de datos aún existe${NC}"
        else
            echo -e "${GREEN}    ✓ Base de datos eliminada correctamente${NC}"
        fi
        
    else
        echo -e "${BLUE}  → Saltando limpieza de base de datos${NC}"
    fi
}

# Función para verificar limpieza MEJORADA
verify_cleanup() {
    echo -e "${YELLOW}9. Verificando limpieza...${NC}"
    
    # Verificar Docker - buscar TODOS los contenedores, no solo fase2
    if command_exists docker; then
        ALL_CONTAINERS=$(docker ps -a --format "{{.Names}}" 2>/dev/null | wc -l)
        PROJECT_CONTAINERS=$(docker ps -a | grep -E "(fase2|bismarckr|api-|websocket|frontend|monitor)" 2>/dev/null | wc -l)
        ALL_IMAGES=$(docker images --format "{{.Repository}}" 2>/dev/null | wc -l)
        PROJECT_IMAGES=$(docker images | grep -E "(fase2|bismarckr)" 2>/dev/null | wc -l)
        
        echo -e "${BLUE}  → Total contenedores: $ALL_CONTAINERS | Del proyecto: $PROJECT_CONTAINERS${NC}"
        echo -e "${BLUE}  → Total imágenes: $ALL_IMAGES | Del proyecto: $PROJECT_IMAGES${NC}"
        
        # Mostrar contenedores existentes si hay alguno
        if [ $ALL_CONTAINERS -gt 0 ]; then
            echo -e "${BLUE}  → Contenedores actuales:${NC}"
            docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null | head -10 | sed 's/^/      /'
        fi
    fi
    
    # Verificar Kubernetes
    if command_exists kubectl; then
        NAMESPACES=$(kubectl get namespaces 2>/dev/null | grep -E "(so1-fase2|monitoring)" | wc -l)
        echo -e "${BLUE}  → Namespaces del proyecto: $NAMESPACES${NC}"
        
        # Mostrar todos los namespaces actuales
        echo -e "${BLUE}  → Namespaces actuales:${NC}"
        kubectl get namespaces --no-headers 2>/dev/null | awk '{print $1}' | sed 's/^/      /' | head -5
    fi
    
    # Verificar Minikube
    if command_exists minikube; then
        MINIKUBE_STATUS=$(minikube status 2>/dev/null | grep -E "(host|kubelet|apiserver)" | head -1 | awk '{print $2}' || echo "No disponible")
        echo -e "${BLUE}  → Estado de Minikube: $MINIKUBE_STATUS${NC}"
    fi
    
    # Verificar MySQL - MEJORADO
    if command_exists mysql; then
        echo -e "${BLUE}  → Estado de MySQL:${NC}"
        
        # Verificar si la base de datos monitoring existe
        if mysql -u monitor -pmonitor123 -e "USE monitoring; SELECT 1;" &>/dev/null; then
            TABLES=$(mysql -u monitor -pmonitor123 -e "USE monitoring; SHOW TABLES;" 2>/dev/null | grep -v "Tables_in_monitoring" | wc -l)
            echo -e "${RED}      ⚠ Base de datos 'monitoring' AÚN EXISTE con $TABLES tablas${NC}"
            mysql -u monitor -pmonitor123 -e "USE monitoring; SHOW TABLES;" 2>/dev/null | grep -v "Tables_in_monitoring" | sed 's/^/        - /'
        else
            echo -e "${GREEN}      ✓ Base de datos 'monitoring' eliminada${NC}"
        fi
        
        # Verificar si el usuario monitor existe
        if mysql -u monitor -pmonitor123 -e "SELECT 1;" &>/dev/null; then
            echo -e "${YELLOW}      ⚠ Usuario 'monitor' aún accesible${NC}"
        else
            echo -e "${GREEN}      ✓ Usuario 'monitor' eliminado${NC}"
        fi
    fi
    
    # Verificar archivos temporales
    TEMP_FILES=0
    if [ -d "/tmp" ]; then
        TEMP_FILES=$(find /tmp -name "*fase2*" -o -name "*monitor*" -o -name "*locust*" 2>/dev/null | wc -l)
    fi
    echo -e "${BLUE}  → Archivos temporales del proyecto: $TEMP_FILES${NC}"
}

# INICIO DE LIMPIEZA

echo -e "${BLUE}Iniciando limpieza completa del proyecto Fase 2...${NC}"
echo

# 1. Limpiar Docker Compose
echo -e "${YELLOW}1. Limpiando Docker Compose...${NC}"
if [ -f "docker-compose.yml" ]; then
    echo -e "${YELLOW}  → Deteniendo servicios de Docker Compose...${NC}"
    docker-compose down -v --remove-orphans &>/dev/null
    echo -e "${GREEN}  ✓ Docker Compose limpiado${NC}"
else
    echo -e "${BLUE}  → No hay docker-compose.yml${NC}"
fi

# 2. Limpiar contenedores Docker - MEJORADO para buscar TODOS los patrones
echo -e "${YELLOW}2. Limpiando contenedores Docker...${NC}"
if command_exists docker; then
    
    # Mostrar todos los contenedores existentes primero
    ALL_CONTAINERS_LIST=$(docker ps -a --format "{{.Names}} ({{.Image}})" 2>/dev/null)
    if [ -n "$ALL_CONTAINERS_LIST" ]; then
        echo -e "${BLUE}  → Contenedores existentes:${NC}"
        echo "$ALL_CONTAINERS_LIST" | sed 's/^/      /'
        echo
    fi
    
    # Buscar contenedores por patrones amplios
    CONTAINER_PATTERNS=(
        "fase2"
        "bismarckr"
        "api-nodejs"
        "api-python" 
        "websocket"
        "frontend"
        "monitor"
        "locust"
        "agente"
        "proyecto"
        "so1"
    )
    
    ALL_CONTAINER_IDS=""
    
    echo -e "${BLUE}  → Buscando contenedores del proyecto...${NC}"
    for pattern in "${CONTAINER_PATTERNS[@]}"; do
        CONTAINERS=$(docker ps -a --filter "name=$pattern" --format "{{.ID}}" 2>/dev/null)
        if [ -n "$CONTAINERS" ]; then
            echo -e "${YELLOW}    Patrón '$pattern': $(echo "$CONTAINERS" | wc -l) contenedores${NC}"
            ALL_CONTAINER_IDS="$ALL_CONTAINER_IDS $CONTAINERS"
        fi
    done
    
    # También buscar por imagen
    IMAGE_CONTAINERS=$(docker ps -a --format "{{.ID}}" --filter "ancestor=bismarckr" 2>/dev/null)
    if [ -n "$IMAGE_CONTAINERS" ]; then
        echo -e "${YELLOW}    Por imagen 'bismarckr': $(echo "$IMAGE_CONTAINERS" | wc -l) contenedores${NC}"
        ALL_CONTAINER_IDS="$ALL_CONTAINER_IDS $IMAGE_CONTAINERS"
    fi
    
    # Limpiar duplicados
    ALL_CONTAINER_IDS=$(echo $ALL_CONTAINER_IDS | tr ' ' '\n' | sort -u | grep -v "^$" | tr '\n' ' ')
    
    if [ -n "$ALL_CONTAINER_IDS" ] && [ "$ALL_CONTAINER_IDS" != " " ]; then
        CONTAINER_COUNT=$(echo $ALL_CONTAINER_IDS | wc -w)
        echo -e "${YELLOW}  → Total contenedores a eliminar: $CONTAINER_COUNT${NC}"
        
        read -p "$(echo -e ${YELLOW}¿Eliminar estos contenedores? (s/N): ${NC})" delete_containers
        if [[ $delete_containers =~ ^[SsYy]$ ]]; then
            echo -e "${YELLOW}  → Deteniendo contenedores...${NC}"
            echo $ALL_CONTAINER_IDS | xargs docker stop &>/dev/null || true
            sleep 2
            
            echo -e "${YELLOW}  → Eliminando contenedores...${NC}"
            echo $ALL_CONTAINER_IDS | xargs docker rm -f &>/dev/null || true
            
            echo -e "${GREEN}  ✓ Contenedores eliminados${NC}"
        else
            echo -e "${BLUE}  → Saltando eliminación de contenedores${NC}"
        fi
    else
        echo -e "${BLUE}  → No hay contenedores del proyecto${NC}"
    fi
    
    # Eliminar imágenes del proyecto
    read -p "$(echo -e ${YELLOW}¿Eliminar TODAS las imágenes relacionadas? (s/N): ${NC})" delete_images
    if [[ $delete_images =~ ^[SsYy]$ ]]; then
        echo -e "${BLUE}  → Buscando imágenes...${NC}"
        
        # Buscar imágenes por patrones
        IMAGES=$(docker images | grep -E "(fase2|bismarckr|monitor|api|websocket|frontend)" | awk '{print $3}' 2>/dev/null | sort -u)
        
        if [ -n "$IMAGES" ]; then
            IMAGE_COUNT=$(echo "$IMAGES" | wc -l)
            echo -e "${YELLOW}  → Eliminando $IMAGE_COUNT imágenes...${NC}"
            echo "$IMAGES" | xargs docker rmi -f &>/dev/null || true
            echo -e "${GREEN}  ✓ Imágenes eliminadas${NC}"
        else
            echo -e "${BLUE}  → No hay imágenes del proyecto${NC}"
        fi
        
        # Limpiar imágenes huérfanas
        echo -e "${YELLOW}  → Limpiando imágenes huérfanas...${NC}"
        docker image prune -f &>/dev/null
    fi
    
    # Limpiar volúmenes y redes
    echo -e "${YELLOW}  → Limpiando volúmenes y redes...${NC}"
    docker volume prune -f &>/dev/null
    docker network prune -f &>/dev/null
    echo -e "${GREEN}  ✓ Volúmenes y redes limpiados${NC}"
    
else
    echo -e "${BLUE}  → Docker no está instalado${NC}"
fi

# 3. Limpiar Kubernetes
echo -e "${YELLOW}3. Limpiando Kubernetes...${NC}"
if command_exists kubectl; then
    # Eliminar namespace del proyecto
    NAMESPACES=("so1-fase2" "monitoring" "proyecto-fase2")
    for ns in "${NAMESPACES[@]}"; do
        if kubectl get namespace "$ns" &>/dev/null; then
            echo -e "${YELLOW}  → Eliminando namespace $ns...${NC}"
            kubectl delete namespace "$ns" --grace-period=0 --force &>/dev/null &
            echo -e "${GREEN}  ✓ Namespace $ns en eliminación${NC}"
        fi
    done
    
    # Esperar un momento
    sleep 3
    
    # Limpiar recursos huérfanos
    echo -e "${YELLOW}  → Limpiando recursos huérfanos...${NC}"
    kubectl delete pods --all-namespaces --field-selector=status.phase=Failed &>/dev/null || true
    kubectl delete pods --all-namespaces --field-selector=status.phase=Succeeded &>/dev/null || true
    echo -e "${GREEN}  ✓ Recursos huérfanos limpiados${NC}"
else
    echo -e "${BLUE}  → kubectl no está instalado${NC}"
fi

# 4. Limpiar Minikube
echo -e "${YELLOW}4. Limpiando Minikube...${NC}"
if command_exists minikube; then
    echo -e "${YELLOW}  → Deteniendo Minikube...${NC}"
    minikube stop &>/dev/null
    
    read -p "$(echo -e ${YELLOW}¿Eliminar completamente el cluster de Minikube? (s/N): ${NC})" delete_minikube
    if [[ $delete_minikube =~ ^[SsYy]$ ]]; then
        echo -e "${YELLOW}  → Eliminando cluster de Minikube...${NC}"
        minikube delete &>/dev/null
        echo -e "${GREEN}  ✓ Minikube eliminado completamente${NC}"
    else
        echo -e "${GREEN}  ✓ Minikube detenido${NC}"
    fi
else
    echo -e "${BLUE}  → Minikube no está instalado${NC}"
fi

# 5. Detener procesos nativos
echo -e "${YELLOW}5. Deteniendo procesos nativos...${NC}"
PROCESSES=("locust" "python.*app.py" "node.*index.js" "python.*agente.py" "npm.*start" "serve")

for process in "${PROCESSES[@]}"; do
    PIDS=$(pgrep -f "$process" 2>/dev/null || true)
    if [ -n "$PIDS" ]; then
        echo -e "${YELLOW}  → Deteniendo proceso: $process${NC}"
        echo "$PIDS" | xargs kill -15 &>/dev/null || true  # SIGTERM
        sleep 1
        # Verificar si siguen ejecutándose
        PIDS=$(pgrep -f "$process" 2>/dev/null || true)
        if [ -n "$PIDS" ]; then
            echo "$PIDS" | xargs kill -9 &>/dev/null || true  # SIGKILL
        fi
    fi
done

echo -e "${GREEN}  ✓ Procesos nativos detenidos${NC}"

# 6. Limpiar MySQL (función corregida)
cleanup_mysql

# 7. Limpiar archivos temporales
echo -e "${YELLOW}7. Limpiando archivos temporales...${NC}"
TEMP_PATTERNS=("/tmp/*fase2*" "/tmp/*monitor*" "/tmp/*locust*" "/tmp/docker_build_*" "/tmp/*bismarckr*")

for pattern in "${TEMP_PATTERNS[@]}"; do
    find ${pattern%/*} -name "${pattern##*/}" -type f -exec rm -f {} \; 2>/dev/null || true
done

echo -e "${GREEN}  ✓ Archivos temporales limpiados${NC}"

# 8. Limpiar configuraciones temporales
echo -e "${YELLOW}8. Limpiando configuraciones temporales...${NC}"

# Limpiar archivos de proyecto
find . -name ".env.backup" -type f -exec rm -f {} \; 2>/dev/null || true
find . -name "*.log" -path "*/logs/*" -exec rm -f {} \; 2>/dev/null || true
find . -name "build" -type d -path "*/Frontend/*" -exec rm -rf {} \; 2>/dev/null || true
find . -name "node_modules" -path "*/Frontend/*" -exec rm -rf {} \; 2>/dev/null || true
find . -name "__pycache__" -type d -exec rm -rf {} \; 2>/dev/null || true
find . -name "*.pyc" -type f -exec rm -f {} \; 2>/dev/null || true

echo -e "${GREEN}  ✓ Configuraciones limpiadas${NC}"

# Verificar limpieza
verify_cleanup

echo
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}║              LIMPIEZA COMPLETA FINALIZADA                 ║${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"

echo
echo -e "${GREEN}✅ Todos los componentes del proyecto Fase 2 han sido procesados:${NC}"
echo -e "${BLUE}   • Contenedores Docker detenidos y eliminados${NC}"
echo -e "${BLUE}   • Imágenes Docker del proyecto eliminadas${NC}"
echo -e "${BLUE}   • Namespaces de Kubernetes eliminados${NC}"
echo -e "${BLUE}   • Minikube detenido/eliminado${NC}"
echo -e "${BLUE}   • Procesos nativos detenidos${NC}"
echo -e "${BLUE}   • Base de datos MySQL limpiada${NC}"
echo -e "${BLUE}   • Archivos temporales eliminados${NC}"

echo
echo -e "${YELLOW}📋 Para verificar manualmente:${NC}"
echo -e "${BLUE}   docker ps -a${NC}"
echo -e "${BLUE}   docker images${NC}"
echo -e "${BLUE}   kubectl get namespaces${NC}"
echo -e "${BLUE}   minikube status${NC}"
echo -e "${BLUE}   mysql -u monitor -pmonitor123 -e 'SHOW DATABASES;'${NC}"

echo
echo -e "${GREEN}¡Limpieza completada! El sistema está listo para Fase 2.${NC}"
echo -e "${YELLOW}💡 Siguiente paso: ./setup-mysql-local.sh para crear la tabla 'metrics' unificada${NC}"