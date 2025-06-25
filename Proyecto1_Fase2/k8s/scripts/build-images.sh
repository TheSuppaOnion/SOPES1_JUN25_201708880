#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=== CONSTRUYENDO TODAS LAS IMÁGENES PARA KUBERNETES ===${NC}"

# Configurar Docker para Minikube
eval $(minikube docker-env)

# Ir al directorio raíz del proyecto (2 niveles arriba desde k8s/scripts/)
PROJECT_ROOT="$(dirname "$(dirname "$(realpath "$0")")")"
echo -e "${YELLOW}Directorio del proyecto: ${PROJECT_ROOT}${NC}"

# Verificar que estamos en el directorio correcto
if [ ! -d "${PROJECT_ROOT}/Backend" ]; then
    echo -e "${RED}Error: No se encontró la carpeta Backend en ${PROJECT_ROOT}${NC}"
    echo -e "${YELLOW}Estructura esperada:${NC}"
    echo -e "Proyecto1_Fase2/"
    echo -e "├── Backend/"
    echo -e "│   ├── API/"
    echo -e "│   ├── API-Python/"
    echo -e "│   ├── WebSocket-API/"
    echo -e "│   └── Agente/"
    echo -e "├── Frontend/"
    echo -e "└── k8s/"
    exit 1
fi

cd "${PROJECT_ROOT}" || {
    echo -e "${RED}Error: No se pudo acceder al directorio del proyecto${NC}"
    exit 1
}

# Función para construir imagen
build_image() {
    local SERVICE_NAME="$1"
    local SERVICE_PATH="$2" 
    local IMAGE_NAME="$3"
    
    echo -e "${YELLOW}Construyendo imagen de ${SERVICE_NAME}...${NC}"
    
    if [ -d "${SERVICE_PATH}" ]; then
        if [ -f "${SERVICE_PATH}/Dockerfile" ]; then
            cd "${SERVICE_PATH}" || {
                echo -e "${RED}Error: No se pudo acceder a ${SERVICE_PATH}${NC}"
                return 1
            }
            
            echo -e "${YELLOW}  → Construyendo desde $(pwd)${NC}"
            docker build -t "${IMAGE_NAME}" .
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}   ${SERVICE_NAME} construida exitosamente${NC}"
            else
                echo -e "${RED}   Error construyendo ${SERVICE_NAME}${NC}"
                return 1
            fi
            
            cd "${PROJECT_ROOT}"
        else
            echo -e "${RED}Error: ${SERVICE_PATH}/Dockerfile no encontrado${NC}"
            return 1
        fi
    else
        echo -e "${RED}Error: Directorio ${SERVICE_PATH} no encontrado${NC}"
        return 1
    fi
}

# Construir todas las imágenes (equivalente a docker-compose.yml de Fase 1)
echo -e "${YELLOW} Construyendo imágenes de todas las APIs y servicios...${NC}"
echo

# 1. API Node.js (Ruta 2 del Traffic Split)
build_image "API Node.js" "Backend/API" "bismarckr/monitor-api:latest"

# 2. API Python (Ruta 1 del Traffic Split) 
build_image "API Python" "Backend/API-Python" "bismarckr/api-python:latest"

# 3. WebSocket API (3ra API para tiempo real)
build_image "WebSocket API" "Backend/WebSocket-API" "bismarckr/websocket-api:latest"

# 4. Agente Go (Recolector de métricas)
build_image "Agente Go" "Backend/Agente" "bismarckr/agente-monitor:latest"

# 5. Frontend React
build_image "Frontend React" "Frontend" "bismarckr/monitor-frontend:latest"

echo
echo -e "${GREEN} TODAS LAS IMÁGENES CONSTRUIDAS CORRECTAMENTE 🎉${NC}"
echo

# Verificar imágenes construidas
echo -e "${YELLOW} Imágenes disponibles en Minikube:${NC}"
docker images | grep bismarckr | while read line; do
    echo -e "${GREEN}  $line${NC}"
done

echo
echo -e "${YELLOW}Total de imágenes construidas: $(docker images | grep bismarckr | wc -l)${NC}"