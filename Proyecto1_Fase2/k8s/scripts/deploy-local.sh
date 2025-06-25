#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=== DESPLEGANDO PROYECTO COMPLETO EN MINIKUBE ===${NC}"

# Ir al directorio de manifiestos
cd "$(dirname "$(realpath "$0")")/../manifests"

# Crear namespace
echo -e "${YELLOW}Creando namespace...${NC}"
kubectl apply -f namespace.yaml

# Desplegar MySQL
echo -e "${YELLOW}Desplegando MySQL...${NC}"
kubectl apply -f mysql/

# Esperar a que MySQL esté listo
echo -e "${YELLOW}Esperando a que MySQL esté listo...${NC}"
kubectl wait --for=condition=ready pod -l app=mysql -n so1_fase2 --timeout=300s

# Desplegar APIs
echo -e "${YELLOW}Desplegando API Node.js...${NC}"
kubectl apply -f api-nodejs/

echo -e "${YELLOW}Desplegando API Python...${NC}"
kubectl apply -f api-python/

echo -e "${YELLOW}Desplegando WebSocket API...${NC}"
kubectl apply -f websocket-api/

# Esperar a que las APIs estén listas
echo -e "${YELLOW}Esperando a que las APIs estén listas...${NC}"
kubectl wait --for=condition=ready pod -l app=api-nodejs -n so1_fase2 --timeout=180s
kubectl wait --for=condition=ready pod -l app=api-python -n so1_fase2 --timeout=180s
kubectl wait --for=condition=ready pod -l app=websocket-api -n so1_fase2 --timeout=180s

# Desplegar Agente
echo -e "${YELLOW}Desplegando Agente...${NC}"
kubectl apply -f agente/

# Desplegar Frontend
echo -e "${YELLOW}Desplegando Frontend React...${NC}"
kubectl apply -f frontend/

# Desplegar Ingress (opcional)
echo -e "${YELLOW}Desplegando Ingress...${NC}"
kubectl apply -f ingress/

echo -e "${GREEN}Despliegue completado${NC}"

# Mostrar estado
echo -e "${YELLOW}Estado de los pods:${NC}"
kubectl get pods -n so1_fase2

echo -e "${YELLOW}Servicios disponibles:${NC}"
kubectl get services -n so1_fase2

# Obtener URLs de acceso
echo -e "${YELLOW}Para acceder a los servicios:${NC}"
echo -e "Frontend: minikube service frontend-service -n so1_fase2"
echo -e "API Node.js: minikube service api-nodejs-service -n so1_fase2"
echo -e "API Python: minikube service api-python-service -n so1_fase2"
echo -e "WebSocket: minikube service websocket-api-service -n so1_fase2"