#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}=== CONSTRUYENDO IMÁGENES PARA KUBERNETES ===${NC}"

# Configurar Docker para Minikube
eval $(minikube docker-env)

# Método robusto para encontrar el directorio raíz
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo -e "${YELLOW}Directorio del proyecto: ${PROJECT_ROOT}${NC}"

# Verificar estructura del proyecto
if [ ! -d "${PROJECT_ROOT}/Backend" ]; then
    echo -e "${RED}Error: No se encontró la carpeta Backend en ${PROJECT_ROOT}${NC}"
    echo -e "${YELLOW}Contenido actual:${NC}"
    ls -la "${PROJECT_ROOT}"
    exit 1
fi

cd "${PROJECT_ROOT}" || {
    echo -e "${RED}Error: No se pudo acceder al directorio del proyecto${NC}"
    exit 1
}

# Definir imágenes de la Fase 2 (diferentes a Fase 1)
api_nodejs_image="bismarckr/api-nodejs-fase2:latest"
api_python_image="bismarckr/api-python-fase2:latest"
websocket_api_image="bismarckr/websocket-api-fase2:latest"
agente_image="bismarckr/agente-fase2:latest"
frontend_image="bismarckr/frontend-fase2:latest"

# Función para verificar si una imagen existe en DockerHub
check_dockerhub_image() {
    local image_name=$1
    echo -e "${YELLOW}Verificando ${image_name} en DockerHub...${NC}"
    
    if docker manifest inspect ${image_name} &>/dev/null; then
        echo -e "${GREEN}  Imagen encontrada en DockerHub${NC}"
        return 0
    else
        echo -e "${RED}  Imagen no encontrada en DockerHub${NC}"
        return 1
    fi
}

# Verificar disponibilidad en DockerHub
echo -e "${BLUE}=== VERIFICANDO IMÁGENES EN DOCKERHUB ===${NC}"

api_nodejs_exists=false
api_python_exists=false
websocket_exists=false
agente_exists=false
frontend_exists=false

if check_dockerhub_image "$api_nodejs_image"; then
    api_nodejs_exists=true
fi

if check_dockerhub_image "$api_python_image"; then
    api_python_exists=true
fi

if check_dockerhub_image "$websocket_api_image"; then
    websocket_exists=true
fi

if check_dockerhub_image "$agente_image"; then
    agente_exists=true
fi

if check_dockerhub_image "$frontend_image"; then
    frontend_exists=true
fi

# Mostrar resultados y preguntar al usuario
echo
echo -e "${BLUE}=== ESTADO DE IMÁGENES ===${NC}"
echo -e "API Node.js:   $($api_nodejs_exists && echo -e "${GREEN}✓ Disponible${NC}" || echo -e "${RED}✗ No disponible${NC}")"
echo -e "API Python:    $($api_python_exists && echo -e "${GREEN}✓ Disponible${NC}" || echo -e "${RED}✗ No disponible${NC}")" 
echo -e "WebSocket API: $($websocket_exists && echo -e "${GREEN}✓ Disponible${NC}" || echo -e "${RED}✗ No disponible${NC}")"
echo -e "Agente Go:     $($agente_exists && echo -e "${GREEN}✓ Disponible${NC}" || echo -e "${RED}✗ No disponible${NC}")"
echo -e "Frontend:      $($frontend_exists && echo -e "${GREEN}✓ Disponible${NC}" || echo -e "${RED}✗ No disponible${NC}")"
echo

# Decidir estrategia según disponibilidad
if $api_nodejs_exists && $api_python_exists && $websocket_exists && $agente_exists && $frontend_exists; then
    echo -e "${GREEN}Todas las imágenes están disponibles en DockerHub${NC}"
    echo
    echo -e "${YELLOW}Selecciona una opción:${NC}"
    echo -e "1) Usar imágenes de DockerHub (más rápido)"
    echo -e "2) Construir imágenes localmente (permite modificaciones)"
    echo
    read -p "Opción [1-2]: " choice
    
    case $choice in
        1)
            use_dockerhub=true
            echo -e "${GREEN}Se usarán las imágenes de DockerHub${NC}"
            ;;
        2)
            use_dockerhub=false
            echo -e "${YELLOW}Se construirán las imágenes localmente${NC}"
            ;;
        *)
            echo -e "${RED}Opción inválida. Se construirán localmente${NC}"
            use_dockerhub=false
            ;;
    esac
else
    available_count=0
    $api_nodejs_exists && ((available_count++))
    $api_python_exists && ((available_count++))
    $websocket_exists && ((available_count++))
    $agente_exists && ((available_count++))
    $frontend_exists && ((available_count++))
    
    if [ $available_count -gt 0 ]; then
        echo -e "${YELLOW}$available_count de 5 imágenes están disponibles en DockerHub${NC}"
        echo
        echo -e "${YELLOW}Selecciona una opción:${NC}"
        echo -e "1) Usar DockerHub donde sea posible, construir el resto"
        echo -e "2) Construir todas las imágenes localmente"
        echo
        read -p "Opción [1-2]: " choice
        
        case $choice in
            1)
                use_dockerhub=true
                echo -e "${GREEN}Se usarán imágenes de DockerHub donde sea posible${NC}"
                ;;
            2)
                use_dockerhub=false
                echo -e "${YELLOW}Se construirán todas las imágenes localmente${NC}"
                ;;
            *)
                echo -e "${RED}Opción inválida. Se construirán localmente${NC}"
                use_dockerhub=false
                ;;
        esac
    else
        echo -e "${YELLOW}No hay imágenes disponibles en DockerHub${NC}"
        echo -e "${YELLOW}Se construirán todas las imágenes localmente${NC}"
        use_dockerhub=false
    fi
fi

echo
echo -e "${BLUE}=== PROCESANDO IMÁGENES ===${NC}"

# Función para construir o descargar imagen
process_image() {
    local SERVICE_NAME="$1"
    local SERVICE_PATH="$2" 
    local IMAGE_NAME="$3"
    local IMAGE_EXISTS="$4"
    
    if $use_dockerhub && $IMAGE_EXISTS; then
        echo -e "${YELLOW}Descargando ${SERVICE_NAME} desde DockerHub...${NC}"
        docker pull "${IMAGE_NAME}"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}   ${SERVICE_NAME} descargada exitosamente${NC}"
            return 0
        else
            echo -e "${RED}   Error descargando ${SERVICE_NAME}, construyendo localmente...${NC}"
        fi
    fi
    
    # Construir localmente
    echo -e "${YELLOW}Construyendo ${SERVICE_NAME} localmente...${NC}"
    
    if [ -d "${SERVICE_PATH}" ] && [ -f "${SERVICE_PATH}/Dockerfile" ]; then
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
        return 0
    else
        echo -e "${RED}Error: ${SERVICE_PATH}/Dockerfile no encontrado${NC}"
        return 1
    fi
}

# Procesar todas las imágenes
echo

# 1. API Node.js (Ruta 2 del Traffic Split)
process_image "API Node.js" "Backend/API" "$api_nodejs_image" "$api_nodejs_exists"

# 2. API Python (Ruta 1 del Traffic Split) 
process_image "API Python" "Backend/API-Python" "$api_python_image" "$api_python_exists"

# 3. WebSocket API (3ra API para tiempo real)
process_image "WebSocket API" "Backend/WebSocket-API" "$websocket_api_image" "$websocket_exists"

# 4. Agente Go (Recolector de métricas)
process_image "Agente Go" "Backend/Agente" "$agente_image" "$agente_exists"

# 5. Frontend React
process_image "Frontend React" "Frontend" "$frontend_image" "$frontend_exists"

echo
echo -e "${GREEN}=== PROCESO COMPLETADO ===${NC}"

# Verificar imágenes finales
echo -e "${YELLOW}Imágenes disponibles en Minikube:${NC}"
echo -e "${BLUE}API Node.js:${NC}   $(docker images | grep "${api_nodejs_image%:*}" | head -1)"
echo -e "${BLUE}API Python:${NC}    $(docker images | grep "${api_python_image%:*}" | head -1)"
echo -e "${BLUE}WebSocket API:${NC} $(docker images | grep "${websocket_api_image%:*}" | head -1)"
echo -e "${BLUE}Agente Go:${NC}     $(docker images | grep "${agente_image%:*}" | head -1)"
echo -e "${BLUE}Frontend:${NC}      $(docker images | grep "${frontend_image%:*}" | head -1)"

echo
total_images=$(docker images | grep -E "(api-nodejs-fase2|api-python-fase2|websocket-api-fase2|agente-fase2|frontend-fase2)" | wc -l)
echo -e "${YELLOW}Total de imágenes de Fase 2: ${total_images}/5${NC}"