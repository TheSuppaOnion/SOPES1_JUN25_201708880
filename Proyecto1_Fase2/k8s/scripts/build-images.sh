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

# Definir SOLO las imágenes de APIs para Kubernetes con RUTAS CORRECTAS
api_nodejs_image="bismarckr/api-nodejs-fase2:latest"
api_python_image="bismarckr/api-python-fase2:latest"
websocket_api_image="bismarckr/websocket-api-fase2:latest"

# RUTAS CORREGIDAS según tu estructura real
api_nodejs_path="Backend/API"
api_python_path="Backend/API-Python"
websocket_path="Backend/WebSocket-API"

echo -e "${BLUE}=== IMÁGENES OBJETIVO PARA KUBERNETES ===${NC}"
echo -e "${YELLOW}Solo se construirán las APIs necesarias:${NC}"
echo -e "${BLUE}  • API Node.js (Express/Backend) → ${api_nodejs_path}${NC}"
echo -e "${BLUE}  • API Python (Flask/FastAPI) → ${api_python_path}${NC}"
echo -e "${BLUE}  • WebSocket API (Tiempo real) → ${websocket_path}${NC}"
echo -e "${YELLOW}  ✗ Agente (no necesario para K8s)${NC}"
echo -e "${YELLOW}  ✗ Frontend (se despliega por separado)${NC}"
echo

# Verificar que las rutas existen antes de continuar
echo -e "${BLUE}=== VERIFICANDO ESTRUCTURA LOCAL ===${NC}"
all_paths_exist=true

for path_name in "API Node.js:${api_nodejs_path}" "API Python:${api_python_path}" "WebSocket API:${websocket_path}"; do
    IFS=':' read -r name path <<< "$path_name"
    full_path="${PROJECT_ROOT}/${path}"
    
    if [ -d "$full_path" ]; then
        echo -e "${GREEN}✓ ${name}: ${path}${NC}"
        if [ -f "$full_path/Dockerfile" ]; then
            echo -e "${GREEN}  ✓ Dockerfile encontrado${NC}"
        else
            echo -e "${RED}  X Dockerfile NO encontrado en ${full_path}${NC}"
            all_paths_exist=false
        fi
    else
        echo -e "${RED}X ${name}: ${path} NO EXISTE${NC}"
        all_paths_exist=false
    fi
done

if [ "$all_paths_exist" = false ]; then
    echo -e "${RED}Error: No se pueden construir las imágenes debido a rutas faltantes${NC}"
    echo -e "${YELLOW}Verifica que los directorios y Dockerfiles existan${NC}"
    exit 1
fi

# Función para verificar si una imagen existe en DockerHub
check_dockerhub_image() {
    local image_name=$1
    echo -e "${YELLOW}Verificando ${image_name} en DockerHub...${NC}"
    
    if docker manifest inspect ${image_name} &>/dev/null; then
        echo -e "${GREEN}  ✓ Imagen encontrada en DockerHub${NC}"
        return 0
    else
        echo -e "${RED}  ✗ Imagen no encontrada en DockerHub${NC}"
        return 1
    fi
}

# Verificar disponibilidad en DockerHub SOLO para APIs
echo -e "${BLUE}=== VERIFICANDO APIS EN DOCKERHUB ===${NC}"

api_nodejs_exists=false
api_python_exists=false
websocket_exists=false

if check_dockerhub_image "$api_nodejs_image"; then
    api_nodejs_exists=true
fi

if check_dockerhub_image "$api_python_image"; then
    api_python_exists=true
fi

if check_dockerhub_image "$websocket_api_image"; then
    websocket_exists=true
fi

# Mostrar resultados y preguntar al usuario
echo
echo -e "${BLUE}=== ESTADO DE APIS EN DOCKERHUB ===${NC}"
echo -e "API Node.js:   $($api_nodejs_exists && echo -e "${GREEN}✓ Disponible${NC}" || echo -e "${RED}✗ No disponible${NC}")"
echo -e "API Python:    $($api_python_exists && echo -e "${GREEN}✓ Disponible${NC}" || echo -e "${RED}✗ No disponible${NC}")" 
echo -e "WebSocket API: $($websocket_exists && echo -e "${GREEN}✓ Disponible${NC}" || echo -e "${RED}✗ No disponible${NC}")"
echo

# Decidir estrategia según disponibilidad
if $api_nodejs_exists && $api_python_exists && $websocket_exists; then
    echo -e "${GREEN}✓ Todas las APIs están disponibles en DockerHub${NC}"
    echo
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║                    OPCIONES DISPONIBLES                   ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${GREEN}1) Usar imágenes de DockerHub ${BLUE}(más rápido)${NC}"
    echo -e "${BLUE}   → Descarga rápida desde DockerHub${NC}"
    echo -e "${BLUE}   → Imágenes pre-compiladas y probadas${NC}"
    echo -e "${BLUE}   → No requiere compilación local${NC}"
    echo
    echo -e "${GREEN}2) Construir imágenes localmente ${BLUE}(más control)${NC}"
    echo -e "${BLUE}   → Permite modificaciones al código${NC}"
    echo -e "${BLUE}   → Optimización para tu sistema${NC}"
    echo -e "${BLUE}   → Control total del proceso${NC}"
    echo
    read -p "$(echo -e ${YELLOW}Selecciona una opción [1-2]: ${NC})" choice
    
    case $choice in
        1)
            use_dockerhub=true
            echo -e "${GREEN}✓ Se usarán las imágenes de DockerHub${NC}"
            ;;
        2)
            use_dockerhub=false
            echo -e "${YELLOW}⚠ Se construirán las imágenes localmente${NC}"
            ;;
        *)
            echo -e "${RED}Opción inválida. Usando construcción local como predeterminado${NC}"
            use_dockerhub=false
            ;;
    esac
else
    available_count=0
    $api_nodejs_exists && ((available_count++))
    $api_python_exists && ((available_count++))
    $websocket_exists && ((available_count++))
    
    if [ $available_count -gt 0 ]; then
        echo -e "${YELLOW}⚠ $available_count de 3 APIs están disponibles en DockerHub${NC}"
        echo
        echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║                   ESTRATEGIA MIXTA                        ║${NC}"
        echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
        echo -e "${GREEN}1) Estrategia híbrida ${BLUE}(recomendado)${NC}"
        echo -e "${BLUE}   → Usar DockerHub donde sea posible${NC}"
        echo -e "${BLUE}   → Construir localmente las faltantes${NC}"
        echo
        echo -e "${GREEN}2) Construir todas localmente ${BLUE}(consistencia)${NC}"
        echo -e "${BLUE}   → Todas las imágenes construidas igual${NC}"
        echo -e "${BLUE}   → Mayor tiempo de construcción${NC}"
        echo
        read -p "$(echo -e ${YELLOW}Selecciona una opción [1-2]: ${NC})" choice
        
        case $choice in
            1)
                use_dockerhub=true
                echo -e "${GREEN}✓ Estrategia híbrida: DockerHub + construcción local${NC}"
                ;;
            2)
                use_dockerhub=false
                echo -e "${YELLOW}⚠ Se construirán todas las APIs localmente${NC}"
                ;;
            *)
                echo -e "${RED}Opción inválida. Usando construcción local${NC}"
                use_dockerhub=false
                ;;
        esac
    else
        echo -e "${YELLOW}⚠ No hay APIs disponibles en DockerHub${NC}"
        echo -e "${YELLOW}Se construirán todas las APIs localmente${NC}"
        use_dockerhub=false
    fi
fi

echo
echo -e "${BLUE}=== PROCESANDO IMÁGENES DE APIS ===${NC}"

# Función para construir o descargar imagen
process_image() {
    local SERVICE_NAME="$1"
    local SERVICE_PATH="$2" 
    local IMAGE_NAME="$3"
    local IMAGE_EXISTS="$4"
    
    echo -e "${YELLOW}📦 Procesando ${SERVICE_NAME}...${NC}"
    
    if $use_dockerhub && $IMAGE_EXISTS; then
        echo -e "${YELLOW}  → Descargando desde DockerHub...${NC}"
        docker pull "${IMAGE_NAME}"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}  ✓ ${SERVICE_NAME} descargada exitosamente${NC}"
            return 0
        else
            echo -e "${RED}  ✗ Error descargando, construyendo localmente...${NC}"
        fi
    fi
    
    # Construir localmente
    echo -e "${YELLOW}  → Construyendo localmente...${NC}"
    
    if [ -d "${SERVICE_PATH}" ] && [ -f "${SERVICE_PATH}/Dockerfile" ]; then
        cd "${SERVICE_PATH}" || {
            echo -e "${RED}  ✗ Error: No se pudo acceder a ${SERVICE_PATH}${NC}"
            return 1
        }
        
        echo -e "${BLUE}    Ubicación: $(pwd)${NC}"
        echo -e "${BLUE}    Comando: docker build -t ${IMAGE_NAME} .${NC}"
        
        docker build -t "${IMAGE_NAME}" .
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}  ✓ ${SERVICE_NAME} construida exitosamente${NC}"
        else
            echo -e "${RED}  ✗ Error construyendo ${SERVICE_NAME}${NC}"
            echo -e "${YELLOW}    Verificando Dockerfile y dependencias...${NC}"
            if [ -f "Dockerfile" ]; then
                echo -e "${BLUE}    Dockerfile encontrado${NC}"
            else
                echo -e "${RED}    Dockerfile NO encontrado${NC}"
            fi
            return 1
        fi
        
        cd "${PROJECT_ROOT}"
        return 0
    else
        echo -e "${RED}  ✗ Error: ${SERVICE_PATH}/Dockerfile no encontrado${NC}"
        echo -e "${YELLOW}    Verificando estructura:${NC}"
        if [ -d "${SERVICE_PATH}" ]; then
            echo -e "${BLUE}    Directorio existe: $(ls -la ${SERVICE_PATH} | head -5)${NC}"
        else
            echo -e "${RED}    Directorio NO existe: ${SERVICE_PATH}${NC}"
        fi
        return 1
    fi
}

# Procesar SOLO las APIs necesarias para Kubernetes CON RUTAS CORREGIDAS
echo

# 1. API Node.js - RUTA CORREGIDA
if process_image "API Node.js" "${api_nodejs_path}" "$api_nodejs_image" "$api_nodejs_exists"; then
    echo -e "${GREEN}     API Node.js lista para Kubernetes${NC}"
else
    echo -e "${RED}     Error procesando API Node.js${NC}"
    exit 1
fi
echo

# 2. API Python - RUTA CORREGIDA
if process_image "API Python" "${api_python_path}" "$api_python_image" "$api_python_exists"; then
    echo -e "${GREEN}     API Python lista para Kubernetes${NC}"
else
    echo -e "${RED}     Error procesando API Python${NC}"
    exit 1
fi
echo

# 3. WebSocket API - RUTA CORREGIDA
if process_image "WebSocket API" "${websocket_path}" "$websocket_api_image" "$websocket_exists"; then
    echo -e "${GREEN}     WebSocket API lista para Kubernetes${NC}"
else
    echo -e "${RED}     Error procesando WebSocket API${NC}"
    exit 1
fi
echo

echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    PROCESO COMPLETADO                     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"

# Verificar imágenes finales disponibles en Minikube
echo -e "${YELLOW} Imágenes disponibles en Minikube:${NC}"

api_nodejs_info=$(docker images | grep "${api_nodejs_image%:*}" | head -1)
api_python_info=$(docker images | grep "${api_python_image%:*}" | head -1)
websocket_info=$(docker images | grep "${websocket_api_image%:*}" | head -1)

if [ -n "$api_nodejs_info" ]; then
    echo -e "${GREEN}  ✓ API Node.js:${NC}   $api_nodejs_info"
else
    echo -e "${RED}  ✗ API Node.js:   No disponible${NC}"
fi

if [ -n "$api_python_info" ]; then
    echo -e "${GREEN}  ✓ API Python:${NC}    $api_python_info"
else
    echo -e "${RED}  ✗ API Python:    No disponible${NC}"
fi

if [ -n "$websocket_info" ]; then
    echo -e "${GREEN}  ✓ WebSocket API:${NC} $websocket_info"
else
    echo -e "${RED}  ✗ WebSocket API: No disponible${NC}"
fi

echo
total_images=$(docker images | grep -E "(api-nodejs-fase2|api-python-fase2|websocket-api-fase2)" | wc -l)
echo -e "${YELLOW} Total de APIs listas: ${total_images}/3${NC}"

if [ $total_images -eq 3 ]; then
    echo -e "${GREEN} ¡Todas las APIs están listas para desplegar en Kubernetes!${NC}"
    echo
    echo -e "${BLUE} Próximos pasos:${NC}"
    echo -e "${YELLOW}  1. Las imágenes están cargadas en Minikube${NC}"
    echo -e "${YELLOW}  2. Listas para usar en manifests de Kubernetes${NC}"
    echo -e "${YELLOW}  3. El despliegue puede continuar${NC}"
else
    echo -e "${RED} Error: No todas las APIs están disponibles${NC}"
    echo -e "${YELLOW}⚠ El despliegue puede fallar${NC}"
    exit 1
fi

echo
echo -e "${BLUE} Comandos útiles:${NC}"
echo -e "${YELLOW}  docker images | grep fase2${NC}               # Ver todas las imágenes"
echo -e "${YELLOW}  minikube image ls | grep fase2${NC}           # Ver imágenes en Minikube"
echo -e "${YELLOW}  kubectl create deployment test --image=${api_nodejs_image}${NC}  # Probar deployment"
echo