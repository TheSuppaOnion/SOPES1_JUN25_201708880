#!/bin/bash

# Script para eliminar todos los servicios utilizados
# Autor: Bismarck Romero - 201708880
# Fecha: Junio 2025

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Función para mostrar menú
show_cleanup_menu() {
    echo -e "${YELLOW}¿Qué deseas limpiar?${NC}"
    echo -e "1) Docker Compose (contenedores locales)"
    echo -e "2) Kubernetes (Minikube)"
    echo -e "3) Todo (Docker + Kubernetes)"
    echo -e "4) Solo módulos del kernel"
    echo -e "5) Salir"
    echo
}

# Función para limpiar Docker Compose
cleanup_docker_compose() {
    echo -e "${YELLOW}=== LIMPIANDO DOCKER COMPOSE ===${NC}"
    
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker no está instalado.${NC}"
        return
    fi

    cd "$(dirname "$0")" || {
        echo -e "${RED}No se pudo acceder al directorio del proyecto.${NC}"
        return
    }

    echo -e "${YELLOW}Deteniendo contenedores...${NC}"
    docker-compose down -v

    echo -e "${YELLOW}Eliminando volúmenes...${NC}"
    docker volume rm proyecto1_fase2_mysql-data 2>/dev/null || true

    # Preguntar por imágenes
    read -p "¿Deseas eliminar también las imágenes Docker? (s/n): " respuesta
    if [[ $respuesta =~ ^[Ss]$ ]]; then
        echo -e "${YELLOW}Eliminando imágenes Docker...${NC}"
        images=$(docker images | grep "bismarckr/monitor" | awk '{print $3}')
        if [ -n "$images" ]; then
            docker rmi -f $images
            echo -e "${GREEN}Imágenes Docker eliminadas.${NC}"
        else
            echo -e "${GREEN}No hay imágenes Docker para eliminar.${NC}"
        fi
    fi

    echo -e "${GREEN}Limpieza de Docker Compose completada.${NC}"
}

# Función para limpiar Kubernetes
cleanup_kubernetes() {
    echo -e "${YELLOW}=== LIMPIANDO KUBERNETES ===${NC}"
    
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}kubectl no está instalado.${NC}"
        return
    fi

    # Ejecutar script de limpieza de Kubernetes
    if [ -f "k8s/scripts/cleanup.sh" ]; then
        ./k8s/scripts/cleanup.sh
    else
        # Limpieza manual si no existe el script
        echo -e "${YELLOW}Eliminando namespace de monitoreo...${NC}"
        kubectl delete namespace so1_fase2 2>/dev/null || true
        
        echo -e "${YELLOW}¿Deseas detener Minikube? (s/n):${NC}"
        read -p "" stop_minikube
        if [[ $stop_minikube =~ ^[Ss]$ ]]; then
            echo -e "${YELLOW}Deteniendo Minikube...${NC}"
            minikube stop
        fi
    fi

    echo -e "${GREEN}Limpieza de Kubernetes completada.${NC}"
}

# Función para limpiar módulos del kernel
cleanup_kernel_modules() {
    echo -e "${YELLOW}=== LIMPIANDO MÓDULOS DEL KERNEL ===${NC}"
    
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

    echo -e "${GREEN}Módulos del kernel descargados.${NC}"
}

# Menú principal
echo -e "${YELLOW}Iniciando limpieza de servicios...${NC}"

while true; do
    show_cleanup_menu
    read -p "Opción [1-5]: " choice
    
    case $choice in
        1)
            cleanup_docker_compose
            cleanup_kernel_modules
            break
            ;;
        2)
            cleanup_kubernetes
            break
            ;;
        3)
            cleanup_docker_compose
            cleanup_kubernetes
            cleanup_kernel_modules
            break
            ;;
        4)
            cleanup_kernel_modules
            break
            ;;
        5)
            echo -e "${YELLOW}Saliendo...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Opción inválida. Intenta de nuevo.${NC}"
            echo
            ;;
    esac
done

echo -e "${GREEN}Limpieza completada.${NC}"