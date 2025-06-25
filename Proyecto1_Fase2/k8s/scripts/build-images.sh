#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=== CONSTRUYENDO TODAS LAS IMÁGENES PARA KUBERNETES ===${NC}"

# Configurar Docker para Minikube
eval $(minikube docker-env)

# Ir al directorio raíz del proyecto
cd "$(dirname "$(dirname "$(realpath "$0")")")"

echo -e "${YELLOW}Construyendo imagen de API Node.js...${NC}"
cd Backend/API
docker build -t bismarckr/monitor-api:latest .

echo -e "${YELLOW}Construyendo imagen de API Python...${NC}"
cd ../API-Python
docker build -t bismarckr/api-python:latest .

echo -e "${YELLOW}Construyendo imagen de WebSocket API...${NC}"
cd ../WebSocket-API
docker build -t bismarckr/websocket-api:latest .

echo -e "${YELLOW}Construyendo imagen de Agente Go...${NC}"
cd ../Agente
docker build -t bismarckr/agente-monitor:latest .

echo -e "${YELLOW}Construyendo imagen de Frontend React...${NC}"
cd ../../Frontend
docker build -t bismarckr/monitor-frontend:latest .

echo -e "${GREEN}Todas las imágenes construidas correctamente${NC}"

# Verificar imágenes
echo -e "${YELLOW}Imágenes disponibles:${NC}"
docker images | grep bismarckr