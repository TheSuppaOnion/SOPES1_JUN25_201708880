#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=== LIMPIANDO DESPLIEGUE DE KUBERNETES ===${NC}"

# Eliminar todo el namespace (esto elimina todos los recursos)
kubectl delete namespace so1_fase2

echo -e "${GREEN}Limpieza completada${NC}"

# Opcional: Detener minikube
read -p "¿Desea detener Minikube? (y/N): " stop_minikube
if [[ $stop_minikube =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deteniendo Minikube...${NC}"
    minikube stop
fi