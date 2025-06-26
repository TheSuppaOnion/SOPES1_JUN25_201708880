#!/bin/bash

# Script para ejecutar el Agente de Monitoreo en Docker
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
echo -e "${BLUE}║ ${YELLOW}AGENTE DE MONITOREO - Bismarck Romero - 201708880${BLUE}        ║${NC}"
echo -e "${BLUE}║                     ${YELLOW}SO1 FASE 2 - DOCKER${BLUE}                      ║${NC}"
echo -e "${BLUE}║                                                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo

echo -e "${YELLOW}=== EJECUTANDO AGENTE DE MONITOREO EN DOCKER ===${NC}"
echo -e "${BLUE}Este agente lee /proc del HOST y envía datos a las APIs${NC}"
echo

# Verificar Docker
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

# Verificar Go (para compilar el agente)
check_golang() {
    echo -e "${YELLOW}Verificando Go...${NC}"
    
    # Actualizar PATH para incluir Go si está instalado en /usr/local/go
    if [ -d "/usr/local/go/bin" ] && [[ ":$PATH:" != *":/usr/local/go/bin:"* ]]; then
        export PATH=$PATH:/usr/local/go/bin
        echo -e "${BLUE}  → PATH actualizado para incluir Go${NC}"
    fi
    
    # Verificar si Go está disponible
    if ! go version &> /dev/null; then
        echo -e "${RED}Go no está instalado o no está en el PATH${NC}"
        echo -e "${YELLOW}Opciones para instalar Go:${NC}"
        echo -e "${BLUE}  1. Automático: sudo apt install golang-go${NC}"
        echo -e "${BLUE}  2. Manual desde: https://golang.org/dl/${NC}"
        echo -e "${BLUE}  3. Script automático (recomendado):${NC}"
        echo
        echo -e "${YELLOW}¿Desea instalar Go automáticamente? (y/n): ${NC}"
        read -r install_go
        
        if [[ $install_go =~ ^[Yy]$ ]]; then
            install_golang_auto
        else
            echo -e "${RED}Go es requerido para compilar el agente${NC}"
            exit 1
        fi
    fi
    
    GO_VERSION=$(go version | awk '{print $3}')
    echo -e "${GREEN}✓ Go $GO_VERSION disponible${NC}"
}

# Función para instalar Go automáticamente
install_golang_auto() {
    echo -e "${YELLOW}Instalando Go automáticamente...${NC}"
    
    # Crear directorio temporal
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Descargar Go 1.21.0 (versión estable)
    echo -e "${YELLOW}  → Descargando Go 1.21.0...${NC}"
    wget -q https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al descargar Go${NC}"
        echo -e "${YELLOW}Intentando con apt...${NC}"
        sudo apt update && sudo apt install -y golang-go
        cd - && rm -rf "$TEMP_DIR"
        return
    fi
    
    # Remover instalación anterior si existe
    echo -e "${YELLOW}  → Removiendo instalación anterior...${NC}"
    sudo rm -rf /usr/local/go
    
    # Instalar Go
    echo -e "${YELLOW}  → Instalando Go en /usr/local/go...${NC}"
    sudo tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
    
    # Actualizar PATH
    echo -e "${YELLOW}  → Actualizando PATH...${NC}"
    export PATH=$PATH:/usr/local/go/bin
    
    # Agregar al .profile si no está
    if ! grep -q "/usr/local/go/bin" ~/.profile; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.profile
        echo -e "${BLUE}  → PATH agregado a ~/.profile${NC}"
    fi
    
    # Limpiar
    cd - && rm -rf "$TEMP_DIR"
    
    # Verificar instalación
    if go version &> /dev/null; then
        echo -e "${GREEN}✓ Go instalado correctamente${NC}"
    else
        echo -e "${RED}Error en la instalación de Go${NC}"
        echo -e "${YELLOW}Instale Go manualmente y vuelva a ejecutar este script${NC}"
        exit 1
    fi
}

# Verificar módulos del kernel
check_kernel_modules() {
    echo -e "${YELLOW}Verificando módulos del kernel...${NC}"
    
    # Verificar si los módulos están cargados
    modules_loaded=0
    for module in cpu_201708880 ram_201708880 procesos_201708880; do
        if lsmod | grep -q "$module"; then
            echo -e "${GREEN}  ✓ Módulo $module cargado${NC}"
            ((modules_loaded++))
        else
            echo -e "${RED}  ✗ Módulo $module NO cargado${NC}"
        fi
    done
    
    if [ $modules_loaded -ne 3 ]; then
        echo -e "${YELLOW}Los módulos del kernel no están completamente cargados.${NC}"
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
        echo -e "${GREEN}✓ Todos los módulos del kernel están cargados${NC}"
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

# Verificar estructura del agente
verify_agent_structure() {
    echo -e "${YELLOW}Verificando estructura del agente...${NC}"
    
    if [ ! -d "Backend/Agente" ]; then
        echo -e "${RED}Error: Directorio Backend/Agente/ no encontrado${NC}"
        exit 1
    fi
    
    cd Backend/Agente
    
    if [ ! -f "agente-de-monitor.go" ]; then
        echo -e "${RED}Error: agente-de-monitor.go no encontrado${NC}"
        exit 1
    fi
    
    if [ ! -f "Dockerfile" ]; then
        echo -e "${RED}Error: Dockerfile no encontrado en Backend/Agente/${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Estructura del agente verificada${NC}"
    cd ../..
}

# Compilar agente nativo (para verificar que funciona)
compile_agent() {
    echo -e "${YELLOW}Compilando agente nativo para verificación...${NC}"
    
    cd Backend/Agente
    
    # Limpiar binario anterior
    if [ -f "agente" ]; then
        rm -f agente
    fi
    
    # Compilar
    echo -e "${YELLOW}  → Ejecutando: go build -o agente agente-de-monitor.go${NC}"
    go build -o agente agente-de-monitor.go
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Agente compilado exitosamente${NC}"
        
        # Verificar que el binario se creó
        if [ -f "agente" ]; then
            echo -e "${GREEN}  ✓ Binario 'agente' creado${NC}"
        else
            echo -e "${RED}  ✗ Binario 'agente' no se creó${NC}"
            exit 1
        fi
    else
        echo -e "${RED}Error al compilar el agente${NC}"
        exit 1
    fi
    
    cd ../..
}

# Construir imagen Docker del agente
build_agent_image() {
    echo -e "${YELLOW}Construyendo imagen Docker del agente...${NC}"
    
    cd Backend/Agente
    
    # Construir imagen
    echo -e "${YELLOW}  → Ejecutando: docker build -t bismarckr/agente-monitor:latest .${NC}"
    docker build -t bismarckr/agente-monitor:latest .
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Imagen Docker del agente construida exitosamente${NC}"
        
        # Mostrar información de la imagen
        IMAGE_SIZE=$(docker images bismarckr/agente-monitor:latest --format "table {{.Size}}" | tail -1)
        echo -e "${BLUE}  Tamaño de la imagen Docker: $IMAGE_SIZE${NC}"
    else
        echo -e "${RED}Error al construir la imagen Docker del agente${NC}"
        exit 1
    fi
    
    cd ../..
}

# Detectar API disponible
detect_api_endpoint() {
    echo -e "${YELLOW}Detectando endpoint de la API...${NC}"
    
    # Prioridades de conexión
    API_ENDPOINTS=(
        "http://localhost:3000/api/data"                    # API local directa
        "http://$(minikube ip 2>/dev/null):30000/api/data"  # Minikube NodePort
        "http://host.docker.internal:3000/api/data"         # Docker Desktop
        "http://172.17.0.1:3000/api/data"                   # Docker bridge
    )
    
    API_URL=""
    
    for endpoint in "${API_ENDPOINTS[@]}"; do
        echo -e "${YELLOW}  → Probando: $endpoint${NC}"
        
        # Probar conectividad básica
        if curl -s --connect-timeout 5 "$endpoint" &> /dev/null; then
            API_URL="$endpoint"
            echo -e "${GREEN}  ✓ API accesible en: $API_URL${NC}"
            break
        else
            echo -e "${RED}  ✗ No accesible${NC}"
        fi
    done
    
    if [ -z "$API_URL" ]; then
        echo -e "${YELLOW}No se detectó API automáticamente${NC}"
        echo -e "${YELLOW}Usando endpoint por defecto: http://localhost:3000/api/data${NC}"
        API_URL="http://localhost:3000/api/data"
    fi
}

# Ejecutar agente en Docker
run_agent_container() {
    echo -e "${YELLOW}Ejecutando agente en Docker...${NC}"
    
    # Detener contenedor anterior si existe
    echo -e "${YELLOW}Limpiando contenedores anteriores...${NC}"
    docker stop agente-local 2>/dev/null || true
    docker rm agente-local 2>/dev/null || true
    
    # Configurar variables de entorno
    echo -e "${YELLOW}Configurando variables de entorno...${NC}"
    echo -e "${BLUE}  API_URL: $API_URL${NC}"
    echo -e "${BLUE}  POLL_INTERVAL: 2s${NC}"
    
    # Verificar si AppArmor está causando problemas
    echo -e "${YELLOW}Verificando configuración del sistema...${NC}"
    
    # Ejecutar contenedor del agente con configuración para evitar problemas de AppArmor
    echo -e "${YELLOW}Iniciando contenedor del agente...${NC}"
    docker run -d \
        --name agente-local \
        --restart unless-stopped \
        --pid host \
        --privileged \
        --security-opt apparmor=unconfined \
        --security-opt seccomp=unconfined \
        -v /proc:/proc:ro \
        -v /sys:/sys:ro \
        -e API_URL="$API_URL" \
        -e POLL_INTERVAL="2s" \
        bismarckr/agente-monitor:latest
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Contenedor del agente iniciado correctamente${NC}"
        
        # Esperar un momento para que el contenedor se inicie
        sleep 3
        
        # Verificar que está corriendo
        if docker ps | grep -q "agente-local"; then
            echo -e "${GREEN}✓ Agente ejecutándose correctamente${NC}"
        else
            echo -e "${RED}Error: El contenedor no está ejecutándose${NC}"
            echo -e "${YELLOW}Intentando con configuración alternativa...${NC}"
            
            # Intentar sin algunas opciones de seguridad
            docker run -d \
                --name agente-local-alt \
                --restart unless-stopped \
                --pid host \
                --privileged \
                -v /proc:/proc:ro \
                -e API_URL="$API_URL" \
                -e POLL_INTERVAL="2s" \
                bismarckr/agente-monitor:latest
            
            if docker ps | grep -q "agente-local-alt"; then
                echo -e "${GREEN}✓ Agente iniciado con configuración alternativa${NC}"
                # Renombrar contenedor
                docker stop agente-local-alt
                docker rename agente-local-alt agente-local
                docker start agente-local
            else
                echo -e "${RED}Error: No se pudo iniciar el contenedor${NC}"
                echo -e "${YELLOW}Logs del contenedor:${NC}"
                docker logs agente-local-alt 2>/dev/null || docker logs agente-local 2>/dev/null
                
                # Mostrar información de debug
                echo -e "${YELLOW}Información de debug:${NC}"
                echo -e "${BLUE}Docker version:${NC}"
                docker version --format '{{.Server.Version}}' 2>/dev/null || echo "No disponible"
                echo -e "${BLUE}Sistema operativo:${NC}"
                uname -a
                echo -e "${BLUE}AppArmor status:${NC}"
                cat /sys/module/apparmor/parameters/enabled 2>/dev/null || echo "AppArmor no disponible"
                
                exit 1
            fi
        fi
    else
        echo -e "${RED}Error al iniciar el contenedor del agente${NC}"
        echo -e "${YELLOW}Intentando diagnóstico del problema...${NC}"
        
        # Diagnóstico adicional
        echo -e "${BLUE}Verificando permisos de Docker:${NC}"
        docker info | grep -E "Server Version|Operating System|Security Options" || true
        
        exit 1
    fi
}

# Verificar funcionamiento del agente
verify_agent_operation() {
    echo -e "${YELLOW}Verificando funcionamiento del agente...${NC}"
    
    # Verificar logs del contenedor
    echo -e "${BLUE}Logs recientes del agente:${NC}"
    docker logs agente-local --tail 10
    
    # Verificar procesos en el contenedor
    echo -e "${BLUE}Procesos en el contenedor:${NC}"
    docker exec agente-local ps aux 2>/dev/null || echo -e "${YELLOW}No se pudieron obtener procesos${NC}"
    
    # Verificar conectividad desde el contenedor
    echo -e "${YELLOW}Probando conectividad desde el contenedor...${NC}"
    docker exec agente-local curl -s --connect-timeout 5 "$API_URL" &> /dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Agente puede conectarse a la API${NC}"
    else
        echo -e "${YELLOW}Problemas de conectividad con la API${NC}"
    fi
}

# Mostrar estado del agente
show_agent_status() {
    echo -e "${YELLOW}=== ESTADO DEL AGENTE ===${NC}"
    
    # Estado del contenedor
    echo -e "${BLUE}Contenedor Docker:${NC}"
    if docker ps | grep -q "agente-local"; then
        echo -e "${GREEN}✓ Contenedor ejecutándose${NC}"
        docker ps --filter name=agente-local --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
    else
        echo -e "${RED}✗ Contenedor no está ejecutándose${NC}"
    fi
    
    # Información de la imagen
    IMAGE_INFO=$(docker images bismarckr/agente-monitor:latest --format "table {{.Size}}\t{{.CreatedAt}}" | tail -1)
    echo -e "${BLUE}Imagen Docker: ${GREEN}bismarckr/agente-monitor:latest ($IMAGE_INFO)${NC}"
    
    # Archivos /proc disponibles
    echo -e "${BLUE}Archivos /proc disponibles:${NC}"
    for proc_file in cpu_201708880 ram_201708880 procesos_201708880; do
        if [ -f "/proc/$proc_file" ]; then
            echo -e "${GREEN}  ✓ /proc/$proc_file${NC}"
        else
            echo -e "${RED}  ✗ /proc/$proc_file${NC}"
        fi
    done
    
    # Endpoint API
    echo -e "${BLUE}Endpoint API: ${GREEN}$API_URL${NC}"
}

# Función para mostrar información de uso
show_usage() {
    echo -e "${YELLOW}=== INFORMACIÓN DE USO ===${NC}"
    echo
    echo -e "${GREEN}Comandos disponibles:${NC}"
    echo -e "${BLUE}  ./run-vm-agente.sh              ${NC}# Configuración e instalación completa"
    echo -e "${BLUE}  ./run-vm-agente.sh start        ${NC}# Iniciar contenedor existente"
    echo -e "${BLUE}  ./run-vm-agente.sh stop         ${NC}# Detener contenedor"
    echo -e "${BLUE}  ./run-vm-agente.sh restart      ${NC}# Reiniciar contenedor"
    echo -e "${BLUE}  ./run-vm-agente.sh status       ${NC}# Ver estado"
    echo -e "${BLUE}  ./run-vm-agente.sh logs         ${NC}# Ver logs en tiempo real"
    echo -e "${BLUE}  ./run-vm-agente.sh rebuild      ${NC}# Reconstruir imagen y reiniciar"
    echo -e "${BLUE}  ./run-vm-agente.sh native       ${NC}# Ejecutar agente nativo (sin Docker)"
    echo
    echo -e "${GREEN}Comandos útiles:${NC}"
    echo -e "${BLUE}  docker logs agente-local        ${NC}# Ver logs"
    echo -e "${BLUE}  docker exec -it agente-local sh ${NC}# Acceder al contenedor"
    echo -e "${BLUE}  lsmod | grep 201708880          ${NC}# Ver módulos del kernel"
    echo
    echo -e "${GREEN}Desarrollo/Debug:${NC}"
    echo -e "${BLUE}  ./run-vm-agente.sh native       ${NC}# Probar agente compilado nativamente"
    echo
}

# Función principal
main() {
    case "${1:-install}" in
        "install"|"")
            echo -e "${YELLOW}=== INSTALACIÓN COMPLETA DEL AGENTE DOCKER ===${NC}"
            check_docker
            check_golang
            check_kernel_modules
            verify_agent_structure
            compile_agent
            build_agent_image
            detect_api_endpoint
            run_agent_container
            verify_agent_operation
            show_agent_status
            show_usage
            ;;
        "start")
            echo -e "${YELLOW}Iniciando contenedor del agente...${NC}"
            docker start agente-local
            sleep 2
            show_agent_status
            ;;
        "stop")
            echo -e "${YELLOW}Deteniendo contenedor del agente...${NC}"
            docker stop agente-local
            echo -e "${GREEN}✓ Agente detenido${NC}"
            ;;
        "restart")
            echo -e "${YELLOW}Reiniciando contenedor del agente...${NC}"
            docker restart agente-local
            sleep 3
            show_agent_status
            ;;
        "status")
            detect_api_endpoint
            show_agent_status
            ;;
        "logs")
            echo -e "${YELLOW}Mostrando logs en tiempo real (Ctrl+C para salir)...${NC}"
            docker logs -f agente-local
            ;;
        "rebuild")
            echo -e "${YELLOW}Reconstruyendo imagen y reiniciando...${NC}"
            docker stop agente-local 2>/dev/null || true
            docker rm agente-local 2>/dev/null || true
            docker rmi bismarckr/agente-monitor:latest 2>/dev/null || true
            check_kernel_modules
            compile_agent
            build_agent_image
            detect_api_endpoint
            run_agent_container
            show_agent_status
            ;;
        "native")
            echo -e "${YELLOW}Ejecutando agente nativo (sin Docker)...${NC}"
            check_golang
            check_kernel_modules
            compile_agent
            detect_api_endpoint
            echo -e "${YELLOW}Iniciando agente nativo...${NC}"
            cd Backend/Agente
            API_URL="$API_URL" POLL_INTERVAL="2s" ./agente &
            AGENT_PID=$!
            echo -e "${GREEN}✓ Agente nativo iniciado con PID: $AGENT_PID${NC}"
            echo -e "${YELLOW}Para detener: kill $AGENT_PID${NC}"
            cd ../..
            ;;
        *)
            echo -e "${RED}Comando no reconocido: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
}

# Función para mostrar información final
show_final_info() {
    echo
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}║              ${YELLOW}AGENTE DE MONITOREO ACTIVO${GREEN}                   ║${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${YELLOW}El agente está enviando métricas del sistema cada 2 segundos${NC}"
    echo -e "${YELLOW}Endpoint API: $API_URL${NC}"
    echo -e "${YELLOW}Para ver logs: ${GREEN}./run-vm-agente.sh logs${NC}"
    echo -e "${YELLOW}Para detener: ${GREEN}./run-vm-agente.sh stop${NC}"
    echo
}

# Verificar permisos
if [ "$EUID" -eq 0 ]; then
    echo -e "${YELLOW}No ejecutes este script como root${NC}"
    echo -e "${YELLOW}Usa: su - tu_usuario${NC}"
    exit 1
fi

echo
# Ejecutar función principal
main "$@"

# Mostrar información final solo en instalación completa
if [ "${1:-install}" == "install" ] || [ "${1:-install}" == "" ]; then
    show_final_info
fi