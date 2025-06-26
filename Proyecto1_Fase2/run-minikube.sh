#!/bin/bash

# Script para desplegar APIs en Kubernetes (Minikube)
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
echo -e "${BLUE}║ ${YELLOW}APIs EN KUBERNETES - Bismarck Romero - 201708880${BLUE}          ║${NC}"
echo -e "${BLUE}║                    ${YELLOW}SO1 FASE 2 - MINIKUBE${BLUE}                     ║${NC}"
echo -e "${BLUE}║                                                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo

echo -e "${YELLOW}=== DESPLEGANDO SOLO APIS EN KUBERNETES ===${NC}"
echo -e "${BLUE}Nota: Frontend y Agente se manejan por separado${NC}"
echo

# Verificar si Docker está instalado
check_docker() {
    echo -e "${YELLOW}Verificando Docker...${NC}"
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

# Verificar módulos del kernel
check_kernel_modules() {
    echo -e "${YELLOW}Verificando módulos del kernel...${NC}"
    if ! lsmod | grep -q "cpu_201708880" || ! lsmod | grep -q "ram_201708880" || ! lsmod | grep -q "procesos_201708880"; then
        echo -e "${YELLOW}Los módulos del kernel no están cargados.${NC}"
        echo -e "${YELLOW}Ejecutando script de instalación de módulos...${NC}"
        
        if [ ! -f "./kernel.sh" ]; then
            echo -e "${RED}Error: kernel.sh no encontrado${NC}"
            echo -e "${YELLOW}Asegúrate de estar en el directorio raíz del proyecto${NC}"
            exit 1
        fi
        
        sudo ./kernel.sh
        if [ $? -ne 0 ]; then
            echo -e "${RED}Error al cargar los módulos del kernel.${NC}"
            exit 1
        fi
        echo -e "${GREEN}✓ Módulos del kernel cargados correctamente${NC}"
    else
        echo -e "${GREEN}✓ Módulos del kernel ya están cargados${NC}"
    fi
    
    # Verificar que /proc está disponible
    echo -e "${YELLOW}Verificando archivos /proc...${NC}"
    for proc_file in cpu_201708880 ram_201708880 procesos_201708880; do
        if [ -f "/proc/$proc_file" ]; then
            echo -e "${GREEN}  ✓ /proc/$proc_file disponible${NC}"
        else
            echo -e "${RED}  ✗ /proc/$proc_file no disponible${NC}"
            exit 1
        fi
    done
}

# Configurar Minikube
setup_minikube() {
    echo -e "${YELLOW}Verificando Minikube...${NC}"
    if ! command -v minikube &> /dev/null; then
        echo -e "${RED}Minikube no está instalado.${NC}"
        echo -e "${YELLOW}Descargando e instalando Minikube automáticamente...${NC}"
        
        if [ ! -f "./k8s/scripts/setup-minikube.sh" ]; then
            echo -e "${RED}Error: k8s/scripts/setup-minikube.sh no encontrado${NC}"
            exit 1
        fi
        
        ./k8s/scripts/setup-minikube.sh
        if [ $? -ne 0 ]; then
            echo -e "${RED}Error al instalar y configurar Minikube.${NC}"
            exit 1
        fi
        echo -e "${GREEN}✓ Minikube instalado correctamente${NC}"
    else
        echo -e "${GREEN}✓ Minikube ya está instalado${NC}"
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
        echo -e "${GREEN}✓ Minikube iniciado correctamente${NC}"
    else
        echo -e "${GREEN}✓ Minikube ya está ejecutándose${NC}"
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
    
    echo -e "${GREEN}✓ Minikube configurado y conectado${NC}"
}

# Construir imágenes Docker para las APIs
build_api_images() {
    echo -e "${YELLOW}Construyendo imágenes Docker para las APIs...${NC}"
    
    if [ ! -f "./k8s/scripts/build-images.sh" ]; then
        echo -e "${RED}Error: k8s/scripts/build-images.sh no encontrado${NC}"
        exit 1
    fi
    
    ./k8s/scripts/build-images.sh
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al construir imágenes.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Imágenes Docker construidas exitosamente${NC}"
}

# Desplegar APIs en Kubernetes
deploy_apis_to_kubernetes() {
    echo -e "${YELLOW}Desplegando APIs en Kubernetes...${NC}"
    
    cd k8s/manifests

    # Crear namespace
    echo -e "${YELLOW}  → Creando namespace so1-fase2...${NC}"
    kubectl apply -f namespace.yaml
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al crear namespace${NC}"
        exit 1
    fi

    # Desplegar API Node.js
    echo -e "${YELLOW}  → Desplegando API Node.js...${NC}"
    kubectl apply -f api-nodejs/
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al desplegar API Node.js${NC}"
        exit 1
    fi

    # Desplegar API Python
    echo -e "${YELLOW}  → Desplegando API Python...${NC}"
    kubectl apply -f api-python/
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al desplegar API Python${NC}"
        exit 1
    fi

    # Desplegar WebSocket API
    echo -e "${YELLOW}  → Desplegando WebSocket API...${NC}"
    kubectl apply -f websocket-api/
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al desplegar WebSocket API${NC}"
        exit 1
    fi

    # Desplegar Ingress
    echo -e "${YELLOW}  → Desplegando Ingress...${NC}"
    kubectl apply -f ingress/
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al desplegar Ingress${NC}"
        exit 1
    fi

    cd ../..
    echo -e "${GREEN}✓ APIs desplegadas en Kubernetes${NC}"
}

# Esperar a que los pods estén listos
wait_for_pods() {
    echo -e "${YELLOW}Esperando a que las APIs estén listas...${NC}"
    
    echo -e "${YELLOW}  → Esperando API Node.js...${NC}"
    kubectl wait --for=condition=ready pod -l app=api-nodejs -n so1-fase2 --timeout=180s
    if [ $? -ne 0 ]; then
        echo -e "${RED}Timeout esperando API Node.js${NC}"
        kubectl logs -l app=api-nodejs -n so1-fase2 --tail=5
        exit 1
    fi
    
    echo -e "${YELLOW}  → Esperando API Python...${NC}"
    kubectl wait --for=condition=ready pod -l app=api-python -n so1-fase2 --timeout=180s
    if [ $? -ne 0 ]; then
        echo -e "${RED}Timeout esperando API Python${NC}"
        kubectl logs -l app=api-python -n so1-fase2 --tail=5
        exit 1
    fi
    
    echo -e "${YELLOW}  → Esperando WebSocket API...${NC}"
    kubectl wait --for=condition=ready pod -l app=websocket-api -n so1-fase2 --timeout=180s
    if [ $? -ne 0 ]; then
        echo -e "${RED}Timeout esperando WebSocket API${NC}"
        kubectl logs -l app=websocket-api -n so1-fase2 --tail=5
        exit 1
    fi
    
    echo -e "${GREEN}✓ Todas las APIs están listas${NC}"
}

# Verificar estado final
verify_deployment() {
    echo -e "${YELLOW}Verificando estado del despliegue...${NC}"
    
    # Estado de pods
    echo -e "${BLUE}Estado de los pods:${NC}"
    kubectl get pods -n so1-fase2
    
    # Estado de servicios
    echo -e "${BLUE}Estado de los servicios:${NC}"
    kubectl get services -n so1-fase2
    
    # Verificar conectividad básica
    echo -e "${YELLOW}Verificando conectividad básica...${NC}"
    
    # Obtener IP de Minikube
    MINIKUBE_IP=$(minikube ip)
    echo -e "${BLUE}IP de Minikube: $MINIKUBE_IP${NC}"
    
    # Verificar que MySQL sea accesible desde un pod
    echo -e "${YELLOW}Probando conectividad a MySQL desde pods...${NC}"
    POD_NAME=$(kubectl get pods -n so1-fase2 -l app=api-nodejs -o jsonpath='{.items[0].metadata.name}')
    if [ -n "$POD_NAME" ]; then
        kubectl exec $POD_NAME -n so1-fase2 -- ping -c 1 host.minikube.internal &> /dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}  ✓ Conectividad host.minikube.internal OK${NC}"
        else
            echo -e "${YELLOW}  ⚠ Conectividad host.minikube.internal puede tener problemas${NC}"
        fi
    fi
    
    echo -e "${GREEN}✓ Verificación completada${NC}"
}

# Mostrar información de acceso
show_access_info() {
    echo
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}║              ${YELLOW}APIS DESPLEGADAS EXITOSAMENTE${GREEN}                 ║${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${YELLOW}📋 APIS DESPLEGADAS EN KUBERNETES:${NC}"
    echo -e "${GREEN}  ✓ API Node.js      (puerto 3000)${NC}"
    echo -e "${GREEN}  ✓ API Python       (puerto 5000)${NC}"
    echo -e "${GREEN}  ✓ WebSocket API    (puerto 4000)${NC}"
    echo -e "${GREEN}  ✓ Ingress          (balanceador de carga)${NC}"
    echo
    echo -e "${YELLOW}🌐 ACCESO A LAS APIS:${NC}"
    echo -e "${BLUE}Para acceder desde el host:${NC}"
    MINIKUBE_IP=$(minikube ip)
    echo -e "   ${GREEN}API Node.js:     http://$MINIKUBE_IP:30000${NC}"
    echo -e "   ${GREEN}API Python:      http://$MINIKUBE_IP:30001${NC}"  
    echo -e "   ${GREEN}WebSocket API:   http://$MINIKUBE_IP:30002${NC}"
    echo
    echo -e "${BLUE}Usando minikube service:${NC}"
    echo -e "   ${GREEN}minikube service api-nodejs-service -n so1-fase2${NC}"
    echo -e "   ${GREEN}minikube service api-python-service -n so1-fase2${NC}"
    echo -e "   ${GREEN}minikube service websocket-api-service -n so1-fase2${NC}"
    echo
    echo -e "${YELLOW}🔧 COMANDOS ÚTILES:${NC}"
    echo -e "${BLUE}Ver estado:          ${GREEN}kubectl get pods -n so1-fase2${NC}"
    echo -e "${BLUE}Ver logs Node.js:    ${GREEN}kubectl logs -f deployment/api-nodejs -n so1-fase2${NC}"
    echo -e "${BLUE}Ver logs Python:     ${GREEN}kubectl logs -f deployment/api-python -n so1-fase2${NC}"
    echo -e "${BLUE}Ver logs WebSocket:  ${GREEN}kubectl logs -f deployment/websocket-api -n so1-fase2${NC}"
    echo
    echo -e "${YELLOW}📦 PRÓXIMOS PASOS:${NC}"
    echo -e "${BLUE}1. Configurar MySQL:     ${GREEN}./setup-mysql-local.sh${NC}"
    echo -e "${BLUE}2. Ejecutar Frontend:    ${GREEN}./setup-frontend-local.sh${NC}"
    echo -e "${BLUE}3. Configurar Agente:    ${GREEN}./run-vm-agente.sh${NC} ${YELLOW}(opcional)${NC}"
    echo -e "${BLUE}4. Pruebas de carga:     ${GREEN}cd Locust && ./run_locust.sh${NC}"
    echo
    echo -e "${YELLOW}🗑️ Para limpiar todo:     ${RED}./delete.sh${NC}"
    echo
}

# Función principal
main() {
    echo -e "${YELLOW}Iniciando despliegue de APIs en Minikube...${NC}"
    echo
    
    # Ejecutar todas las verificaciones y despliegue
    check_docker
    check_kernel_modules
    setup_minikube
    build_api_images
    deploy_apis_to_kubernetes
    wait_for_pods
    verify_deployment
    show_access_info
}

# Verificar permisos
if [ "$EUID" -eq 0 ]; then
    echo -e "${YELLOW}⚠️ No ejecutes este script como root${NC}"
    echo -e "${YELLOW}Usa: su - tu_usuario${NC}"
    exit 1
fi

echo
# Ejecutar función principal
main "$@"