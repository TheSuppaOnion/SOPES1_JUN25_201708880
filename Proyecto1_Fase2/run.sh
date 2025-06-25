#!/bin/bash

# Script para desplegar los contenedores de la aplicación
# Autor: Bismarck Romero - 201708880
# Fecha: Junio 2025

# Colores para mensajes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                            ║${NC}"
echo -e "${BLUE}║ ${YELLOW}Sistema de Monitoreo - Bismarck Romero - 201708880${BLUE}        ║${NC}"
echo -e "${BLUE}║                                                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo

# Función para mostrar menú
show_menu() {
    echo -e "${YELLOW}Selecciona el modo de despliegue:${NC}"
    echo -e "1) Docker Compose (desarrollo local)"
    echo -e "2) Kubernetes con Minikube (pruebas)"
    echo -e "3) Salir"
    echo
}

# Función para Docker Compose (tu código actual)
deploy_docker_compose() {
    echo -e "${YELLOW}=== DESPLIEGUE CON DOCKER COMPOSE ===${NC}"
    
    # Tu código actual de docker-compose aquí...
    # (todo el código existente de verificación de módulos, imágenes, etc.)
    
    # Verificar si Docker y Docker Compose están instalados
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Error: Docker no está instalado.${NC}"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}Error: Docker Compose no está instalado.${NC}"
        exit 1
    fi

    # Verificar módulos del kernel
    if ! lsmod | grep -q "cpu_201708880" || ! lsmod | grep -q "ram_201708880"; then
        echo -e "${YELLOW}Los módulos del kernel no están cargados.${NC}"
        echo -e "${YELLOW}Ejecutando script de instalación de módulos...${NC}"
        sudo ./kernel.sh
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

    # Resto de tu lógica actual...
    echo -e "${YELLOW}Deteniendo contenedores existentes...${NC}"
    docker-compose down

    echo -e "${YELLOW}Iniciando servicios...${NC}"
    docker-compose up -d --build

    echo -e "${GREEN}Aplicación desplegada correctamente.${NC}"
    echo -e "${GREEN}Frontend: http://localhost:8080${NC}"
    echo -e "${GREEN}API: http://localhost:3000${NC}"
}

# Función para Kubernetes
deploy_kubernetes() {
    echo -e "${YELLOW}=== DESPLIEGUE CON KUBERNETES ===${NC}"
    
    # Verificar si minikube está instalado
    if ! command -v minikube &> /dev/null; then
        echo -e "${RED}Minikube no está instalado.${NC}"
        echo -e "${YELLOW}Ejecutando configuración de Minikube...${NC}"
        ./k8s/scripts/setup-minikube.sh
        if [ $? -ne 0 ]; then
            echo -e "${RED}Error al configurar Minikube.${NC}"
            exit 1
        fi
    fi

    # Verificar si minikube está ejecutándose
    if ! minikube status &> /dev/null; then
        echo -e "${YELLOW}Iniciando Minikube...${NC}"
        minikube start --driver=docker --memory=4096 --cpus=2
    fi

    # Construir imágenes
    echo -e "${YELLOW}Construyendo imágenes Docker...${NC}"
    ./k8s/scripts/build-images.sh
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al construir imágenes.${NC}"
        exit 1
    fi

    # Desplegar en Kubernetes
    echo -e "${YELLOW}Desplegando en Kubernetes...${NC}"
    ./k8s/scripts/deploy-local.sh
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al desplegar en Kubernetes.${NC}"
        exit 1
    fi

    echo -e "${GREEN}Aplicación desplegada en Kubernetes correctamente.${NC}"
    echo -e "${YELLOW}Para acceder al frontend:${NC}"
    echo -e "${GREEN}minikube service frontend-service -n so1_fase2${NC}"
}

# Menú principal
while true; do
    show_menu
    read -p "Opción [1-3]: " choice
    
    case $choice in
        1)
            deploy_docker_compose
            break
            ;;
        2)
            deploy_kubernetes
            break
            ;;
        3)
            echo -e "${YELLOW}Saliendo...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Opción inválida. Intenta de nuevo.${NC}"
            echo
            ;;
    esac
done