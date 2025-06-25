#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=== CONFIGURANDO MINIKUBE PARA PROYECTO DE MONITOREO ===${NC}"

# Verificar si minikube está instalado
if ! command -v minikube &> /dev/null; then
    echo -e "${RED}Minikube no está instalado. Instalando...${NC}"
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo install minikube-linux-amd64 /usr/local/bin/minikube
    rm minikube-linux-amd64
fi

# Verificar si kubectl está instalado
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl no está instalado. Instalando...${NC}"
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
fi

# Iniciar minikube
echo -e "${YELLOW}Iniciando Minikube...${NC}"
minikube start --driver=docker --memory=4096 --cpus=2

# Verificar estado
echo -e "${YELLOW}Verificando estado de Minikube...${NC}"
minikube status

# Configurar Docker para usar el registro de Minikube
echo -e "${YELLOW}Configurando Docker environment para Minikube...${NC}"
eval $(minikube docker-env)

echo -e "${GREEN}Minikube configurado correctamente${NC}"
echo -e "${YELLOW}Para construir imágenes en Minikube, ejecute:${NC}"
echo -e "eval \$(minikube docker-env)"
echo -e "${YELLOW}Para acceder al dashboard:${NC}"
echo -e "minikube dashboard"