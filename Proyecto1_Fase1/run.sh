#!/bin/bash

# Script para desplegar los contenedores de la aplicación
# Autor: Bismarck Romero - 201708880
# Fecha: Junio 2025

# Colores para mensajes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

clear
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                            ║${NC}"
echo -e "${BLUE}║ ${YELLOW}Sistema de Monitoreo - Bismarck Romero - 201708880${BLUE}        ║${NC}"
echo -e "${BLUE}║                                                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo

# Verificar si Docker y Docker Compose están instalados
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker no está instalado. Por favor instálalo primero.${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Error: Docker Compose no está instalado. Por favor instálalo primero.${NC}"
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

# Definir las imágenes de DockerHub
api_image="bismarckr/monitor-api:latest"
agente_image="bismarckr/monitor-agente:latest"
frontend_image="bismarckr/monitor-frontend:latest"

# Función para verificar si una imagen existe en DockerHub
check_dockerhub_image() {
    local image_name=$1
    echo -e "${YELLOW}Verificando si la imagen ${image_name} existe en DockerHub...${NC}"
    
    # Verificar si podemos hacer pull de la imagen (sin descargarla)
    if docker manifest inspect ${image_name} &>/dev/null; then
        echo -e "${GREEN} Imagen ${image_name} encontrada en DockerHub.${NC}"
        return 0
    else
        echo -e "${RED} Imagen ${image_name} no encontrada en DockerHub.${NC}"
        return 1
    fi
}

# Verificar disponibilidad de imágenes en DockerHub
echo -e "${YELLOW}Verificando disponibilidad de imágenes en DockerHub...${NC}"

api_exists=false
agente_exists=false
frontend_exists=false

if check_dockerhub_image "$api_image"; then
    api_exists=true
fi

if check_dockerhub_image "$agente_image"; then
    agente_exists=true
fi

if check_dockerhub_image "$frontend_image"; then
    frontend_exists=true
fi

# Preguntar al usuario qué opción desea usar
if $api_exists && $agente_exists && $frontend_exists; then
    echo
    echo -e "${GREEN}Todas las imágenes están disponibles en DockerHub.${NC}"
    echo
    echo -e "${YELLOW}Selecciona una opción:${NC}"
    echo -e "1) Usar imágenes de DockerHub (más rápido)"
    echo -e "2) Construir imágenes localmente (permite modificaciones)"
    echo
    read -p "Opción [1-2]: " choice
    
    case $choice in
        1)
            use_dockerhub=true
            echo -e "${GREEN}Se usarán las imágenes de DockerHub.${NC}"
            ;;
        2)
            use_dockerhub=false
            echo -e "${YELLOW}Se construirán las imágenes localmente.${NC}"
            ;;
        *)
            echo -e "${RED}Opción inválida. Se construirán las imágenes localmente.${NC}"
            use_dockerhub=false
            ;;
    esac
else
    echo
    echo -e "${YELLOW}No todas las imágenes están disponibles en DockerHub.${NC}"
    
    if $api_exists || $agente_exists || $frontend_exists; then
        echo -e "${YELLOW}Algunas imágenes están disponibles:${NC}"
        $api_exists && echo -e "  ${GREEN} API${NC}" || echo -e "  ${RED}✗ API${NC}"
        $agente_exists && echo -e "  ${GREEN} Agente${NC}" || echo -e "  ${RED}✗ Agente${NC}"
        $frontend_exists && echo -e "  ${GREEN} Frontend${NC}" || echo -e "  ${RED}✗ Frontend${NC}"
        echo
        
        echo -e "${YELLOW}Selecciona una opción:${NC}"
        echo -e "1) Usar imágenes de DockerHub donde sea posible, construir el resto"
        echo -e "2) Construir todas las imágenes localmente"
        echo
        read -p "Opción [1-2]: " choice
        
        case $choice in
            1)
                use_dockerhub=true
                echo -e "${GREEN}Se usarán imágenes de DockerHub donde sea posible.${NC}"
                ;;
            2)
                use_dockerhub=false
                echo -e "${YELLOW}Se construirán todas las imágenes localmente.${NC}"
                ;;
            *)
                echo -e "${RED}Opción inválida. Se construirán las imágenes localmente.${NC}"
                use_dockerhub=false
                ;;
        esac
    else
        echo -e "${YELLOW}Se construirán todas las imágenes localmente.${NC}"
        use_dockerhub=false
    fi
fi

# Detener contenedores existentes si hay alguno
echo
echo -e "${YELLOW}Deteniendo contenedores existentes...${NC}"
docker-compose down

# Iniciar los servicios según la opción seleccionada
if $use_dockerhub; then
    echo -e "${YELLOW}Iniciando servicios usando imágenes de DockerHub...${NC}"
    
    # Descargar las imágenes primero para asegurarnos de tener la última versión
    if $api_exists; then
        echo -e "${YELLOW}Descargando imagen API...${NC}"
        docker pull $api_image
    fi
    
    if $agente_exists; then
        echo -e "${YELLOW}Descargando imagen Agente...${NC}"
        docker pull $agente_image
    fi
    
    if $frontend_exists; then
        echo -e "${YELLOW}Descargando imagen Frontend...${NC}"
        docker pull $frontend_image
    fi
    
    # Iniciar servicios con pull
    echo -e "${YELLOW}Iniciando servicios...${NC}"
    if $api_exists && $agente_exists && $frontend_exists; then
        # Si todas las imágenes existen, usar pull sin build
        docker-compose pull
        docker-compose up -d
    else
        # Si solo algunas imágenes existen, usar pull donde sea posible y build para el resto
        docker-compose up -d
    fi
else
    echo -e "${YELLOW}Iniciando servicios construyendo todas las imágenes localmente...${NC}"
    docker-compose up -d --build
fi

# Verificar que todos los servicios estén funcionando
echo
echo -e "${YELLOW}Verificando el estado de los servicios...${NC}"
docker-compose ps

echo
echo -e "${GREEN}  Aplicación desplegada correctamente.${NC}"
echo -e "${GREEN}  Frontend: http://localhost:8080${NC}"
echo -e "${GREEN}  API: http://localhost:3000${NC}"
echo