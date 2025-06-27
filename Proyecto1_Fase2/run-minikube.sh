#!/bin/bash

# Script maestro para desplegar APIs en Kubernetes (Minikube)
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
echo -e "${BLUE}║ ${YELLOW}MINIKUBE ORCHESTRATOR - Bismarck Romero - 201708880${BLUE}      ║${NC}"
echo -e "${BLUE}║                    ${YELLOW}SO1 FASE 2 - KUBERNETES${BLUE}                    ║${NC}"
echo -e "${BLUE}║                                                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo

echo -e "${YELLOW}=== ORQUESTADOR DE DESPLIEGUE EN MINIKUBE ===${NC}"
echo -e "${BLUE}Flujo: Verificar → Instalar → Configurar → Construir → Desplegar${NC}"
echo

# Verificar si Docker está instalado
check_docker() {
    echo -e "${YELLOW}[1/5] Verificando Docker...${NC}"
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Error: Docker no está instalado.${NC}"
        echo -e "${YELLOW}Instale Docker: sudo apt install docker.io${NC}"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        echo -e "${RED}Error: Docker no está ejecutándose${NC}"
        echo -e "${YELLOW}Inicie Docker y vuelva a ejecutar este script${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Docker está disponible${NC}"
}

# Verificar si Minikube está instalado
check_minikube_installation() {
    echo -e "${YELLOW}[2/5] Verificando instalación de Minikube...${NC}"
    
    if ! command -v minikube &> /dev/null; then
        echo -e "${RED}✗ Minikube no está instalado${NC}"
        echo -e "${YELLOW}Instalando Minikube automáticamente...${NC}"
        
        # Descargar e instalar Minikube
        echo -e "${YELLOW}  → Descargando Minikube...${NC}"
        curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}Error al descargar Minikube${NC}"
            exit 1
        fi
        
        echo -e "${YELLOW}  → Instalando Minikube...${NC}"
        sudo install minikube-linux-amd64 /usr/local/bin/minikube
        rm minikube-linux-amd64
        
        if ! command -v minikube &> /dev/null; then
            echo -e "${RED}Error: Minikube no se instaló correctamente${NC}"
            exit 1
        fi
        
        echo -e "${GREEN}✓ Minikube instalado exitosamente${NC}"
    else
        echo -e "${GREEN}✓ Minikube ya está instalado${NC}"
        MINIKUBE_VERSION=$(minikube version --short 2>/dev/null || echo "desconocida")
        echo -e "${BLUE}  Versión: $MINIKUBE_VERSION${NC}"
    fi
    
    # Verificar kubectl
    if ! command -v kubectl &> /dev/null; then
        echo -e "${YELLOW}  → kubectl no encontrado, instalando...${NC}"
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        rm kubectl
        echo -e "${GREEN}  ✓ kubectl instalado${NC}"
    else
        echo -e "${GREEN}  ✓ kubectl ya disponible${NC}"
    fi
}

# Configurar Minikube usando el script dedicado
setup_minikube_cluster() {
    echo -e "${YELLOW}[3/5] Configurando cluster de Minikube...${NC}"
    
    # Verificar que existe el script de configuración
    if [ ! -f "k8s/scripts/setup-minikube.sh" ]; then
        echo -e "${RED}Error: k8s/scripts/setup-minikube.sh no encontrado${NC}"
        echo -e "${YELLOW}Asegúrate de estar en el directorio raíz del proyecto${NC}"
        exit 1
    fi
    
    # Hacer ejecutable si no lo es
    chmod +x k8s/scripts/setup-minikube.sh
    
    echo -e "${YELLOW}  → Ejecutando script de configuración...${NC}"
    ./k8s/scripts/setup-minikube.sh
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al configurar Minikube${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Minikube configurado correctamente${NC}"
    
    # Verificar estado final
    echo -e "${YELLOW}  → Verificando estado del cluster...${NC}"
    if minikube status | grep -q "Running"; then
        echo -e "${GREEN}  ✓ Cluster ejecutándose correctamente${NC}"
    else
        echo -e "${RED}  ✗ Cluster no está en estado correcto${NC}"
        echo -e "${BLUE}Estado actual:${NC}"
        minikube status
        exit 1
    fi
    
    # Verificar kubectl conectividad
    if kubectl get nodes &> /dev/null; then
        NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
        echo -e "${GREEN}  ✓ kubectl conectado ($NODE_COUNT nodo(s))${NC}"
    else
        echo -e "${RED}  ✗ kubectl no puede conectarse${NC}"
        exit 1
    fi
}

# Construir imágenes usando el script dedicado
build_docker_images() {
    echo -e "${YELLOW}[4/5] Construyendo/descargando imágenes Docker...${NC}"
    
    # Verificar que existe el script de construcción
    if [ ! -f "k8s/scripts/build-images.sh" ]; then
        echo -e "${RED}Error: k8s/scripts/build-images.sh no encontrado${NC}"
        exit 1
    fi
    
    # Hacer ejecutable si no lo es
    chmod +x k8s/scripts/build-images.sh
    
    echo -e "${YELLOW}  → Ejecutando script de construcción de imágenes...${NC}"
    echo -e "${BLUE}  → El script verificará DockerHub y te dará opciones${NC}"
    
    ./k8s/scripts/build-images.sh
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al construir/descargar imágenes${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Imágenes Docker preparadas correctamente${NC}"
    
    # Verificar imágenes disponibles
    echo -e "${YELLOW}  → Verificando imágenes en Minikube...${NC}"
    eval $(minikube docker-env)
    
    images_found=0
    expected_images=(
        "bismarckr/api-nodejs-fase2"
        "bismarckr/api-python-fase2" 
        "bismarckr/websocket-api-fase2"
    )
    
    for image in "${expected_images[@]}"; do
        if docker images | grep -q "$image"; then
            echo -e "${GREEN}    ✓ $image disponible${NC}"
            ((images_found++))
        else
            echo -e "${YELLOW}    ⚠ $image no encontrada${NC}"
        fi
    done
    
    echo -e "${BLUE}  Total: $images_found/${#expected_images[@]} imágenes principales disponibles${NC}"
    
    if [ $images_found -eq 0 ]; then
        echo -e "${RED}Error: No hay imágenes disponibles para desplegar${NC}"
        exit 1
    fi
}

# Desplegar en Kubernetes
deploy_to_kubernetes() {
    echo -e "${YELLOW}[5/5] Desplegando en Kubernetes...${NC}"
    
    # Verificar estructura de manifests
    if [ ! -d "k8s/manifests" ]; then
        echo -e "${RED}Error: Directorio k8s/manifests no encontrado${NC}"
        exit 1
    fi
    
    cd k8s/manifests
    
    # 1. Crear namespace
    echo -e "${YELLOW}  → Creando namespace...${NC}"
    if [ -f "namespace.yaml" ]; then
        kubectl apply -f namespace.yaml
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}    ✓ Namespace so1-fase2 creado${NC}"
        else
            echo -e "${RED}    ✗ Error creando namespace${NC}"
            exit 1
        fi
    else
        # Crear namespace básico si no existe archivo
        kubectl create namespace so1-fase2 --dry-run=client -o yaml | kubectl apply -f -
        echo -e "${GREEN}    ✓ Namespace so1-fase2 creado (básico)${NC}"
    fi
    
    # 2. Desplegar API Node.js
    echo -e "${YELLOW}  → Desplegando API Node.js...${NC}"
    if [ -d "api-nodejs" ]; then
        kubectl apply -f api-nodejs/
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}    ✓ API Node.js desplegada${NC}"
        else
            echo -e "${RED}    ✗ Error desplegando API Node.js${NC}"
            cd ../..
            exit 1
        fi
    else
        echo -e "${YELLOW}    ⚠ Directorio api-nodejs no encontrado${NC}"
    fi
    
    # 3. Desplegar API Python  
    echo -e "${YELLOW}  → Desplegando API Python...${NC}"
    if [ -d "api-python" ]; then
        kubectl apply -f api-python/
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}    ✓ API Python desplegada${NC}"
        else
            echo -e "${RED}    ✗ Error desplegando API Python${NC}"
            cd ../..
            exit 1
        fi
    else
        echo -e "${YELLOW}    ⚠ Directorio api-python no encontrado${NC}"
    fi
    
    # 4. Desplegar WebSocket API
    echo -e "${YELLOW}  → Desplegando WebSocket API...${NC}"
    if [ -d "websocket-api" ]; then
        kubectl apply -f websocket-api/
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}    ✓ WebSocket API desplegada${NC}"
        else
            echo -e "${RED}    ✗ Error desplegando WebSocket API${NC}"
            cd ../..
            exit 1
        fi
    else
        echo -e "${YELLOW}    ⚠ Directorio websocket-api no encontrado${NC}"
    fi
    
    # 5. Desplegar Ingress
    echo -e "${YELLOW}  → Desplegando Ingress...${NC}"
    if [ -d "ingress" ]; then
        kubectl apply -f ingress/
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}    ✓ Ingress desplegado${NC}"
        else
            echo -e "${YELLOW}    ⚠ Warning desplegando Ingress (puede ser normal)${NC}"
        fi
    else
        echo -e "${YELLOW}    ⚠ Directorio ingress no encontrado${NC}"
    fi
    
    cd ../..
    echo -e "${GREEN}✓ Despliegue en Kubernetes completado${NC}"
}

# Esperar y verificar pods
wait_and_verify_pods() {
    echo -e "${YELLOW}Esperando a que los pods estén listos...${NC}"
    
    # Lista de deployments a esperar
    deployments=(
        "api-nodejs:API Node.js"
        "api-python:API Python" 
        "websocket-api:WebSocket API"
    )
    
    for deployment_info in "${deployments[@]}"; do
        IFS=':' read -r deployment_name display_name <<< "$deployment_info"
        
        echo -e "${YELLOW}  → Esperando $display_name...${NC}"
        
        # Verificar si el deployment existe
        if kubectl get deployment "$deployment_name" -n so1-fase2 &>/dev/null; then
            # Esperar con timeout
            if kubectl wait --for=condition=ready pod -l "app=$deployment_name" -n so1-fase2 --timeout=120s; then
                echo -e "${GREEN}    ✓ $display_name está listo${NC}"
            else
                echo -e "${YELLOW}    ⚠ Timeout esperando $display_name${NC}"
                echo -e "${BLUE}    Logs recientes:${NC}"
                kubectl logs -l "app=$deployment_name" -n so1-fase2 --tail=3 2>/dev/null || true
            fi
        else
            echo -e "${YELLOW}    ⚠ Deployment $deployment_name no encontrado${NC}"
        fi
    done
    
    echo -e "${GREEN}✓ Verificación de pods completada${NC}"
}

# Mostrar estado final y acceso
show_final_status() {
    echo
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}║            ${YELLOW}DESPLIEGUE COMPLETADO EXITOSAMENTE${GREEN}              ║${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Estado general
    echo -e "${BLUE}📊 ESTADO DEL CLUSTER:${NC}"
    echo -e "${YELLOW}Namespace:${NC} so1-fase2"
    
    # Estado de pods
    echo -e "${BLUE}Estado de pods:${NC}"
    kubectl get pods -n so1-fase2 -o wide
    
    echo
    echo -e "${BLUE}Estado de servicios:${NC}"
    kubectl get services -n so1-fase2
    
    echo
    echo -e "${BLUE}Estado de deployments:${NC}"
    kubectl get deployments -n so1-fase2
    
    # Información de acceso
    MINIKUBE_IP=$(minikube ip)
    echo
    echo -e "${YELLOW}🌐 INFORMACIÓN DE ACCESO:${NC}"
    echo -e "${BLUE}IP de Minikube: $MINIKUBE_IP${NC}"
    echo
    echo -e "${GREEN}📱 Comandos de acceso rápido:${NC}"
    echo -e "${BLUE}minikube service api-nodejs-service -n so1-fase2${NC}     # API Node.js"
    echo -e "${BLUE}minikube service api-python-service -n so1-fase2${NC}     # API Python"
    echo -e "${BLUE}minikube service websocket-api-service -n so1-fase2${NC}  # WebSocket API"
    echo
    echo -e "${GREEN}🔧 Comandos de monitoreo:${NC}"
    echo -e "${BLUE}kubectl get all -n so1-fase2${NC}                        # Estado general"
    echo -e "${BLUE}kubectl logs -f deployment/api-nodejs -n so1-fase2${NC}   # Logs Node.js"
    echo -e "${BLUE}kubectl logs -f deployment/api-python -n so1-fase2${NC}   # Logs Python"
    echo -e "${BLUE}kubectl logs -f deployment/websocket-api -n so1-fase2${NC} # Logs WebSocket"
    echo -e "${BLUE}minikube dashboard${NC}                                   # Dashboard K8s"
    echo
    echo -e "${GREEN}📦 PRÓXIMOS PASOS:${NC}"
    echo -e "${BLUE}1. Configurar MySQL:     ${GREEN}./setup-mysql-local.sh${NC}"
    echo -e "${BLUE}2. Ejecutar Frontend:    ${GREEN}./setup-frontend-local.sh${NC}"
    echo -e "${BLUE}3. Pruebas de APIs:      ${GREEN}curl \$(minikube service api-nodejs-service -n so1-fase2 --url)/health${NC}"
    echo
    echo -e "${YELLOW}🗑️ Para limpiar todo:${NC}"
    echo -e "${RED}kubectl delete namespace so1-fase2${NC}                   # Eliminar namespace"
    echo -e "${RED}minikube delete${NC}                                      # Eliminar cluster"
    echo
}

# Función principal
main() {
    echo -e "${YELLOW}🚀 Iniciando orquestador de despliegue...${NC}"
    echo
    
    # Ejecutar flujo completo
    check_docker
    check_minikube_installation  
    setup_minikube_cluster
    build_docker_images
    deploy_to_kubernetes
    wait_and_verify_pods
    show_final_status
    
    echo -e "${GREEN}🎉 ¡Despliegue completado exitosamente!${NC}"
}

# Verificar permisos
if [ "$EUID" -eq 0 ]; then
    echo -e "${YELLOW}⚠️ No ejecutes este script como root${NC}"
    echo -e "${YELLOW}Usa: su - tu_usuario${NC}"
    exit 1
fi

# Verificar directorio
if [ ! -f "k8s/scripts/setup-minikube.sh" ] || [ ! -f "k8s/scripts/build-images.sh" ]; then
    echo -e "${RED}Error: Scripts necesarios no encontrados${NC}"
    echo -e "${YELLOW}Asegúrate de estar en el directorio raíz del proyecto${NC}"
    echo -e "${BLUE}Estructura esperada:${NC}"
    echo -e "  k8s/scripts/setup-minikube.sh"
    echo -e "  k8s/scripts/build-images.sh" 
    echo -e "  k8s/manifests/"
    exit 1
fi

# Ejecutar función principal
main "$@"