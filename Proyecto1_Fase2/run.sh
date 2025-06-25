#!/bin/bash

# Script para desplegar la aplicación con Kubernetes
# Autor: Bismarck Romero - 201708880
# Fecha: Junio 2025 - SO1 Fase 2

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
echo -e "${BLUE}║                    ${YELLOW}SO1 FASE 2 - KUBERNETES${BLUE}                    ║${NC}"
echo -e "${BLUE}║                                                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo

echo -e "${YELLOW}=== DESPLEGANDO SISTEMA DE MONITOREO CON KUBERNETES ===${NC}"
echo

# Verificar si Docker está instalado
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker no está instalado.${NC}"
    echo -e "${YELLOW}Instale Docker: sudo apt install docker.io${NC}"
    exit 1
fi

# Verificar módulos del kernel
echo -e "${YELLOW}Verificando módulos del kernel...${NC}"
if ! lsmod | grep -q "cpu_201708880" || ! lsmod | grep -q "ram_201708880" || ! lsmod | grep -q "procesos_201708880"; then
    echo -e "${YELLOW}Los módulos del kernel no están cargados.${NC}"
    echo -e "${YELLOW}Ejecutando script de instalación de módulos...${NC}"
    sudo ./kernel.sh
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al cargar los módulos del kernel.${NC}"
        exit 1
    fi
    echo -e "${GREEN} Módulos del kernel cargados correctamente${NC}"
else
    echo -e "${GREEN} Módulos del kernel ya están cargados${NC}"
fi

# Verificar si minikube está instalado
echo -e "${YELLOW}Verificando Minikube...${NC}"
if ! command -v minikube &> /dev/null; then
    echo -e "${RED}Minikube no está instalado.${NC}"
    echo -e "${YELLOW}Descargando e instalando Minikube automáticamente...${NC}"
    ./k8s/scripts/setup-minikube.sh
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al instalar y configurar Minikube.${NC}"
        exit 1
    fi
    echo -e "${GREEN} Minikube instalado correctamente${NC}"
else
    echo -e "${GREEN} Minikube ya está instalado${NC}"
fi

# Verificar si minikube está ejecutándose
echo -e "${YELLOW}Verificando estado de Minikube...${NC}"
if ! minikube status &> /dev/null; then
    echo -e "${YELLOW}Iniciando Minikube...${NC}"
    minikube start --driver=docker --memory=4096 --cpus=2
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al iniciar Minikube${NC}"
        exit 1
    fi
    echo -e "${GREEN} Minikube iniciado correctamente${NC}"
else
    echo -e "${GREEN} Minikube ya está ejecutándose${NC}"
fi

# Verificar conectividad kubectl
echo -e "${YELLOW}Verificando conectividad con Kubernetes...${NC}"
kubectl config use-context minikube
kubectl get nodes &> /dev/null
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: kubectl no puede conectarse al cluster. Reiniciando Minikube...${NC}"
    minikube delete
    minikube start --driver=docker --memory=4096 --cpus=2 --force
    kubectl config use-context minikube
fi

# Función para verificar y generar estructura React
setup_react_structure() {
    echo -e "${YELLOW}Verificando estructura del proyecto React...${NC}"
    
    # Verificar Frontend/public/index.html
    if [ ! -f "Frontend/public/index.html" ]; then
        echo -e "${YELLOW}Generando estructura React faltante...${NC}"
        
        # Crear carpeta public si no existe
        mkdir -p Frontend/public
        
        # Generar index.html
        cat > Frontend/public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#000000" />
    <meta name="description" content="Sistema de Monitoreo - SO1 Fase 2" />
    <title>Monitor de Sistema - Bismarck Romero</title>
  </head>
  <body>
    <noscript>Necesitas habilitar JavaScript para ejecutar esta aplicación.</noscript>
    <div id="root"></div>
  </body>
</html>
EOF
        
        # Generar manifest.json
        cat > Frontend/public/manifest.json << 'EOF'
{
  "short_name": "Monitor Sistema",
  "name": "Sistema de Monitoreo - SO1 Fase 2",
  "start_url": ".",
  "display": "standalone",
  "theme_color": "#000000",
  "background_color": "#ffffff"
}
EOF
        
        echo -e "${GREEN}  Estructura React generada automáticamente${NC}"
    else
        echo -e "${GREEN}  Estructura React ya existe${NC}"
    fi
    
    # Verificar src/index.js
    if [ ! -f "Frontend/src/index.js" ]; then
        echo -e "${YELLOW}Generando punto de entrada React...${NC}"
        
        cat > Frontend/src/index.js << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import './App.css';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF
        
        echo -e "${GREEN} ✓ Punto de entrada React generado automáticamente${NC}"
    else
        echo -e "${GREEN} ✓ Punto de entrada React ya existe${NC}"
    fi
    
    # Verificar package-lock.json problemáticos
    if [ -f "Frontend/package-lock.json" ]; then
        echo -e "${YELLOW}Limpiando package-lock.json para evitar conflictos...${NC}"
        rm -f Frontend/package-lock.json
        rm -rf Frontend/node_modules
        echo -e "${GREEN} ✓ Cache npm limpiado${NC}"
    fi
    
    # Lo mismo para WebSocket-API
    if [ -f "Backend/WebSocket-API/package-lock.json" ]; then
        echo -e "${YELLOW}Limpiando cache WebSocket-API...${NC}"
        rm -f Backend/WebSocket-API/package-lock.json
        rm -rf Backend/WebSocket-API/node_modules
        echo -e "${GREEN} ✓ Cache WebSocket-API limpiado${NC}"
    fi
}

# Ejecutar verificación y generación automática
setup_react_structure

# Construir todas las imágenes
echo -e "${YELLOW}Construyendo imágenes Docker para Kubernetes...${NC}"
./k8s/scripts/build-images.sh
if [ $? -ne 0 ]; then
    echo -e "${RED}Error al construir imágenes.${NC}"
    exit 1
fi

# Desplegar en Kubernetes
echo -e "${YELLOW}Desplegando aplicación en Kubernetes...${NC}"
./k8s/scripts/deploy-local.sh
if [ $? -ne 0 ]; then
    echo -e "${RED}Error al desplegar en Kubernetes.${NC}"
    exit 1
fi

echo
echo -e "${GREEN} APLICACIÓN DESPLEGADA EXITOSAMENTE EN KUBERNETES 🎉${NC}"
echo
echo -e "${YELLOW} INFORMACIÓN DE ACCESO:${NC}"
echo -e "${GREEN}Para acceder al frontend:${NC}"
echo -e "   ${BLUE}minikube service frontend-service -n so1-fase2${NC}"
echo
echo -e "${GREEN}Para acceder a las APIs directamente:${NC}"
echo -e "   ${BLUE}minikube service api-nodejs-service -n so1-fase2${NC}  (API Node.js)"
echo -e "   ${BLUE}minikube service api-python-service -n so1-fase2${NC}  (API Python)"
echo -e "   ${BLUE}minikube service websocket-api-service -n so1-fase2${NC}  (WebSocket)"
echo
echo -e "${GREEN}Para ver el estado de los pods:${NC}"
echo -e "   ${BLUE}kubectl get pods -n so1-fase2${NC}"
echo
echo -e "${GREEN}Para ver logs:${NC}"
echo -e "   ${BLUE}kubectl logs -f deployment/api-nodejs -n so1-fase2${NC}"
echo -e "   ${BLUE}kubectl logs -f deployment/api-python -n so1-fase2${NC}"
echo
echo -e "${YELLOW}Para limpiar todo cuando termines:${NC}"
echo -e "   ${BLUE}./delete.sh${NC}"
echo