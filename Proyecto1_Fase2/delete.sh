#!/bin/bash

# Script para eliminar todos los servicios utilizados
# Autor: Bismarck Romero - 201708880
# Fecha: Junio 2025 - SO1 Fase 2

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}============================================================${NC}"
echo -e "${YELLOW}    LIMPIEZA COMPLETA DEL SISTEMA - SO1 FASE 2            ${NC}"
echo -e "${YELLOW}============================================================${NC}"
echo

echo -e "${RED}ADVERTENCIA: Esto eliminara TODOS los servicios del proyecto:${NC}"
echo -e "  - Namespace de Kubernetes (so1-fase2)"
echo -e "  - Todos los pods y servicios"
echo -e "  - Minikube (sera detenido)"
echo -e "  - Imagenes Docker del proyecto"
echo -e "  - Modulos del kernel cargados"
echo

read -p "Estas seguro de que deseas continuar? (s/n): " confirmacion

if [[ ! $confirmacion =~ ^[Ss]$ ]]; then
    echo -e "${YELLOW}Operacion cancelada.${NC}"
    exit 0
fi

echo -e "${YELLOW}Iniciando limpieza completa...${NC}"
echo

# Limpiar Kubernetes
echo -e "${YELLOW}=== LIMPIANDO KUBERNETES ===${NC}"
if command -v kubectl &> /dev/null; then
    echo -e "${YELLOW}Eliminando namespace so1-fase2...${NC}"
    kubectl delete namespace so1-fase2 2>/dev/null || true
    
    echo -e "${YELLOW}Esperando eliminacion del namespace...${NC}"
    kubectl wait --for=delete namespace/so1-fase2 --timeout=60s 2>/dev/null || true
    
    echo -e "${GREEN}Namespace eliminado.${NC}"
else
    echo -e "${YELLOW}kubectl no encontrado, omitiendo limpieza de Kubernetes.${NC}"
fi

# Detener Minikube
echo -e "${YELLOW}Deteniendo Minikube...${NC}"
if command -v minikube &> /dev/null; then
    if minikube status &> /dev/null; then
        minikube stop
        echo -e "${GREEN}Minikube detenido.${NC}"
    else
        echo -e "${GREEN}Minikube ya esta detenido.${NC}"
    fi
else
    echo -e "${YELLOW}Minikube no encontrado.${NC}"
fi

# Limpiar imagenes Docker
echo -e "${YELLOW}=== LIMPIANDO IMAGENES DOCKER ===${NC}"
if command -v docker &> /dev/null; then
    images=$(docker images | grep "bismarckr" | awk '{print $3}')
    if [ -n "$images" ]; then
        echo -e "${YELLOW}Eliminando imagenes del proyecto...${NC}"
        docker rmi -f $images 2>/dev/null || true
        echo -e "${GREEN}Imagenes Docker eliminadas.${NC}"
    else
        echo -e "${GREEN}No hay imagenes del proyecto para eliminar.${NC}"
    fi
else
    echo -e "${YELLOW}Docker no encontrado, omitiendo limpieza de imagenes.${NC}"
fi

# Limpiar modulos del kernel
echo -e "${YELLOW}=== LIMPIANDO MODULOS DEL KERNEL ===${NC}"
modules_removed=0

if lsmod | grep -q "cpu_201708880"; then
    echo -e "${YELLOW}Descargando modulo CPU...${NC}"
    sudo rmmod cpu_201708880 2>/dev/null || true
    ((modules_removed++))
fi

if lsmod | grep -q "ram_201708880"; then
    echo -e "${YELLOW}Descargando modulo RAM...${NC}"
    sudo rmmod ram_201708880 2>/dev/null || true
    ((modules_removed++))
fi

if lsmod | grep -q "procesos_201708880"; then
    echo -e "${YELLOW}Descargando modulo procesos...${NC}"
    sudo rmmod procesos_201708880 2>/dev/null || true
    ((modules_removed++))
fi

if [ $modules_removed -eq 0 ]; then
    echo -e "${GREEN}No hay modulos del kernel para descargar.${NC}"
else
    echo -e "${GREEN}$modules_removed modulos del kernel descargados.${NC}"
fi

echo
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}              LIMPIEZA COMPLETA FINALIZADA                ${NC}"
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}Todos los servicios del proyecto han sido eliminados.${NC}"
echo -e "${YELLOW}Para volver a desplegar, ejecuta: ./run.sh${NC}"