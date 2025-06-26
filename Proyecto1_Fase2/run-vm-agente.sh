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

echo -e "${YELLOW}=== AGENTE DE MONITOREO EN DOCKER ===${NC}"
echo -e "${BLUE}Este script compila e instala todo lo necesario para el agente${NC}"
echo

# Verificar que estamos en el directorio correcto
check_directory() {
    echo -e "${YELLOW}Verificando directorio del proyecto...${NC}"
    
    if [ ! -f "kernel.sh" ]; then
        echo -e "${RED}Error: kernel.sh no encontrado${NC}"
        echo -e "${YELLOW}Ejecuta este script desde el directorio raíz del proyecto${NC}"
        exit 1
    fi
    
    if [ ! -d "Backend/Agente" ]; then
        echo -e "${RED}Error: Directorio Backend/Agente/ no encontrado${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Directorio del proyecto verificado${NC}"
}

# Verificar dependencias del sistema
check_dependencies() {
    echo -e "${YELLOW}Verificando dependencias del sistema...${NC}"
    
    # Verificar Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Error: Docker no está instalado${NC}"
        echo -e "${YELLOW}Instala Docker: sudo apt install docker.io${NC}"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        echo -e "${RED}Error: Docker no está ejecutándose${NC}"
        echo -e "${YELLOW}Inicia Docker: sudo systemctl start docker${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Docker disponible${NC}"
    
    # Verificar Go
    if [ -d "/usr/local/go/bin" ] && [[ ":$PATH:" != *":/usr/local/go/bin:"* ]]; then
        export PATH=$PATH:/usr/local/go/bin
    fi
    
    if ! go version &> /dev/null; then
        echo -e "${RED}Error: Go no está instalado${NC}"
        echo -e "${YELLOW}Instala Go: sudo apt install golang-go${NC}"
        echo -e "${YELLOW}O descarga desde: https://golang.org/dl/${NC}"
        exit 1
    fi
    
    GO_VERSION=$(go version | awk '{print $3}')
    echo -e "${GREEN}✓ Go $GO_VERSION disponible${NC}"
    
    # Verificar herramientas de compilación
    if ! command -v make &> /dev/null; then
        echo -e "${RED}Error: make no está instalado${NC}"
        echo -e "${YELLOW}Instala: sudo apt install build-essential${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Herramientas de compilación disponibles${NC}"
}

# Compilar e instalar módulos del kernel
build_kernel_modules() {
    echo -e "${YELLOW}Compilando e instalando módulos del kernel...${NC}"
    
    # Verificar que kernel.sh existe y es ejecutable
    if [ ! -f "kernel.sh" ]; then
        echo -e "${RED}Error: kernel.sh no encontrado${NC}"
        exit 1
    fi
    
    if [ ! -x "kernel.sh" ]; then
        echo -e "${YELLOW}Haciendo kernel.sh ejecutable...${NC}"
        chmod +x kernel.sh
    fi
    
    # Ejecutar kernel.sh
    echo -e "${YELLOW}Ejecutando: sudo ./kernel.sh${NC}"
    sudo ./kernel.sh
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al compilar/instalar módulos del kernel${NC}"
        exit 1
    fi
    
    # Verificar que los módulos están cargados
    echo -e "${YELLOW}Verificando módulos cargados...${NC}"
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
        echo -e "${RED}Error: No todos los módulos están cargados${NC}"
        exit 1
    fi
    
    # Verificar archivos /proc
    echo -e "${YELLOW}Verificando archivos /proc...${NC}"
    for proc_file in cpu_201708880 ram_201708880 procesos_201708880; do
        if [ -f "/proc/$proc_file" ]; then
            echo -e "${GREEN}  ✓ /proc/$proc_file disponible${NC}"
        else
            echo -e "${RED}  ✗ /proc/$proc_file no disponible${NC}"
            exit 1
        fi
    done
    
    echo -e "${GREEN}✓ Módulos del kernel instalados y funcionando${NC}"
}

# Verificar estructura del agente Go
verify_go_agent() {
    echo -e "${YELLOW}Verificando estructura del agente Go...${NC}"
    
    cd Backend/Agente
    
    if [ ! -f "agente-de-monitor.go" ]; then
        echo -e "${RED}Error: agente-de-monitor.go no encontrado${NC}"
        exit 1
    fi
    
    if [ ! -f "Dockerfile" ]; then
        echo -e "${RED}Error: Dockerfile no encontrado${NC}"
        exit 1
    fi
    
    if [ ! -f "go.mod" ]; then
        echo -e "${YELLOW}Inicializando módulo Go...${NC}"
        go mod init agente-monitor
    fi
    
    echo -e "${GREEN}✓ Estructura del agente verificada${NC}"
    cd ../..
}

# Compilar agente Go
compile_go_agent() {
    echo -e "${YELLOW}Compilando agente Go...${NC}"
    
    cd Backend/Agente
    
    # Limpiar binario anterior
    if [ -f "agente" ]; then
        rm -f agente
    fi
    
    # Descargar dependencias
    echo -e "${YELLOW}  → Descargando dependencias Go...${NC}"
    go mod tidy
    
    # Compilar
    echo -e "${YELLOW}  → Compilando: go build -o agente agente-de-monitor.go${NC}"
    go build -o agente agente-de-monitor.go
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al compilar el agente Go${NC}"
        cd ../..
        exit 1
    fi
    
    # Verificar binario
    if [ ! -f "agente" ]; then
        echo -e "${RED}Error: Binario 'agente' no se creó${NC}"
        cd ../..
        exit 1
    fi
    
    # Probar ejecución básica (muy rápido)
    echo -e "${YELLOW}  → Probando binario compilado...${NC}"
    timeout 2s ./agente --help &>/dev/null || timeout 2s ./agente --version &>/dev/null || true
    
    echo -e "${GREEN}✓ Agente Go compilado exitosamente${NC}"
    cd ../..
}

# Construir imagen Docker del agente
build_docker_image() {
    echo -e "${YELLOW}Construyendo imagen Docker del agente...${NC}"
    
    cd Backend/Agente
    
    # Limpiar imagen anterior
    echo -e "${YELLOW}  → Limpiando imagen anterior...${NC}"
    docker rmi bismarckr/agente-fase2:latest 2>/dev/null || true
    
    # Construir nueva imagen
    echo -e "${YELLOW}  → Ejecutando: docker build -t bismarckr/agente-fase2:latest .${NC}"
    docker build -t bismarckr/agente-fase2:latest .
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al construir imagen Docker${NC}"
        cd ../..
        exit 1
    fi
    
    # Verificar imagen creada
    if ! docker images | grep -q "bismarckr/agente-fase2"; then
        echo -e "${RED}Error: Imagen Docker no se creó correctamente${NC}"
        cd ../..
        exit 1
    fi
    
    # Mostrar información de la imagen
    IMAGE_SIZE=$(docker images bismarckr/agente-fase2:latest --format "table {{.Size}}" | tail -1)
    echo -e "${GREEN}✓ Imagen Docker construida exitosamente${NC}"
    echo -e "${BLUE}  Tamaño: $IMAGE_SIZE${NC}"
    
    cd ../..
}

# Detectar endpoint de API
detect_api_endpoint() {
    echo -e "${YELLOW}Detectando endpoint de API...${NC}"
    
    # Lista de endpoints posibles
    API_ENDPOINTS=(
        "http://localhost:3000/api/data"
        "http://172.17.0.1:3000/api/data"
        "http://host.docker.internal:3000/api/data"
    )
    
    API_URL=""
    
    for endpoint in "${API_ENDPOINTS[@]}"; do
        echo -e "${YELLOW}  → Probando: $endpoint${NC}"
        if curl -s --connect-timeout 3 "$endpoint" &>/dev/null; then
            API_URL="$endpoint"
            echo -e "${GREEN}  ✓ API accesible en: $API_URL${NC}"
            break
        else
            echo -e "${RED}  ✗ No accesible${NC}"
        fi
    done
    
    if [ -z "$API_URL" ]; then
        echo -e "${YELLOW}No se detectó API disponible${NC}"
        echo -e "${YELLOW}Usando endpoint por defecto: http://localhost:3000/api/data${NC}"
        API_URL="http://localhost:3000/api/data"
    fi
}

# Ejecutar contenedor Docker del agente
run_docker_agent() {
    echo -e "${YELLOW}Ejecutando agente en Docker...${NC}"
    
    # Limpiar contenedores anteriores
    echo -e "${YELLOW}  → Limpiando contenedores anteriores...${NC}"
    docker stop agente-local 2>/dev/null || true
    docker rm agente-local 2>/dev/null || true
    
    # Configurar variables
    echo -e "${YELLOW}  → Configuración:${NC}"
    echo -e "${BLUE}    API_URL: $API_URL${NC}"
    echo -e "${BLUE}    POLL_INTERVAL: 2s${NC}"
    
    # Ejecutar contenedor con múltiples intentos
    echo -e "${YELLOW}  → Iniciando contenedor...${NC}"
    
    # Intento 1: Configuración completa
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
        bismarckr/agente-fase2:latest 2>/dev/null
    
    sleep 2
    
    # Verificar si funciona
    if docker ps | grep -q "agente-local"; then
        echo -e "${GREEN}✓ Agente ejecutándose en Docker${NC}"
        return 0
    fi
    
    # Intento 2: Sin opciones de seguridad
    echo -e "${YELLOW}  → Intentando configuración alternativa...${NC}"
    docker stop agente-local 2>/dev/null || true
    docker rm agente-local 2>/dev/null || true
    
    docker run -d \
        --name agente-local \
        --restart unless-stopped \
        --pid host \
        --privileged \
        -v /proc:/proc:ro \
        -e API_URL="$API_URL" \
        -e POLL_INTERVAL="2s" \
        bismarckr/agente-fase2:latest 2>/dev/null
    
    sleep 2
    
    if docker ps | grep -q "agente-local"; then
        echo -e "${GREEN}✓ Agente ejecutándose en Docker (configuración alternativa)${NC}"
        return 0
    fi
    
    # Intento 3: Configuración mínima
    echo -e "${YELLOW}  → Intentando configuración mínima...${NC}"
    docker stop agente-local 2>/dev/null || true
    docker rm agente-local 2>/dev/null || true
    
    docker run -d \
        --name agente-local \
        --privileged \
        -v /proc:/proc:ro \
        -e API_URL="$API_URL" \
        -e POLL_INTERVAL="2s" \
        bismarckr/agente-fase2:latest 2>/dev/null
    
    sleep 2
    
    if docker ps | grep -q "agente-local"; then
        echo -e "${GREEN}✓ Agente ejecutándose en Docker (configuración mínima)${NC}"
        return 0
    fi
    
    # Si todo falla
    echo -e "${RED}Error: No se pudo ejecutar el contenedor Docker${NC}"
    echo -e "${YELLOW}Logs del último intento:${NC}"
    docker logs agente-local 2>/dev/null || echo "No hay logs disponibles"
    
    echo -e "${YELLOW}Información del sistema:${NC}"
    echo -e "${BLUE}Docker: $(docker --version)${NC}"
    echo -e "${BLUE}Kernel: $(uname -r)${NC}"
    echo -e "${BLUE}OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)${NC}"
    
    exit 1
}

# Verificar funcionamiento del agente
verify_agent() {
    echo -e "${YELLOW}Verificando funcionamiento del agente...${NC}"
    
    # Verificar que el contenedor está corriendo
    if ! docker ps | grep -q "agente-local"; then
        echo -e "${RED}Error: Contenedor no está ejecutándose${NC}"
        return 1
    fi
    
    # Mostrar logs recientes
    echo -e "${BLUE}Logs recientes:${NC}"
    docker logs agente-local --tail 5
    
    # Verificar procesos
    echo -e "${BLUE}Procesos en el contenedor:${NC}"
    docker exec agente-local ps aux 2>/dev/null || echo "No se pudieron obtener procesos"
    
    # Probar conectividad
    echo -e "${YELLOW}Probando conectividad a API...${NC}"
    if docker exec agente-local wget -q --spider "$API_URL" 2>/dev/null; then
        echo -e "${GREEN}✓ Conectividad a API exitosa${NC}"
    else
        echo -e "${YELLOW}Advertencia: Problemas de conectividad a API${NC}"
    fi
    
    echo -e "${GREEN}✓ Agente funcionando correctamente${NC}"
}

# Mostrar estado final
show_status() {
    echo
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}║              ${YELLOW}AGENTE DE MONITOREO ACTIVO${GREEN}                   ║${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Estado del contenedor
    if docker ps | grep -q "agente-local"; then
        echo -e "${GREEN}✓ Contenedor Docker: EJECUTÁNDOSE${NC}"
        docker ps --filter name=agente-local --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    else
        echo -e "${RED}✗ Contenedor Docker: NO EJECUTÁNDOSE${NC}"
    fi
    
    # Módulos del kernel
    echo -e "${BLUE}Módulos del kernel:${NC}"
    for module in cpu_201708880 ram_201708880 procesos_201708880; do
        if lsmod | grep -q "$module"; then
            echo -e "${GREEN}  ✓ $module${NC}"
        else
            echo -e "${RED}  ✗ $module${NC}"
        fi
    done
    
    # Endpoint API
    echo -e "${BLUE}Endpoint API: ${GREEN}$API_URL${NC}"
    echo -e "${BLUE}Intervalo: ${GREEN}2 segundos${NC}"
    
    echo
    echo -e "${YELLOW}Comandos útiles:${NC}"
    echo -e "${BLUE}  docker logs agente-local -f     ${NC}# Ver logs en tiempo real"
    echo -e "${BLUE}  docker stop agente-local        ${NC}# Detener agente"
    echo -e "${BLUE}  docker start agente-local       ${NC}# Iniciar agente"
    echo -e "${BLUE}  ./run-vm-agente.sh rebuild      ${NC}# Reconstruir todo"
    echo
}

# Función para comandos
handle_command() {
    case "${1:-install}" in
        "install"|"")
            echo -e "${YELLOW}=== INSTALACIÓN COMPLETA DEL AGENTE ===${NC}"
            check_directory
            check_dependencies
            build_kernel_modules
            verify_go_agent
            compile_go_agent
            build_docker_image
            detect_api_endpoint
            run_docker_agent
            verify_agent
            show_status
            ;;
        "rebuild")
            echo -e "${YELLOW}=== RECONSTRUYENDO AGENTE ===${NC}"
            docker stop agente-local 2>/dev/null || true
            docker rm agente-local 2>/dev/null || true
            docker rmi bismarckr/agente-fase2:latest 2>/dev/null || true
            compile_go_agent
            build_docker_image
            detect_api_endpoint
            run_docker_agent
            show_status
            ;;
        "start")
            echo -e "${YELLOW}Iniciando agente...${NC}"
            docker start agente-local
            sleep 2
            show_status
            ;;
        "stop")
            echo -e "${YELLOW}Deteniendo agente...${NC}"
            docker stop agente-local
            echo -e "${GREEN}✓ Agente detenido${NC}"
            ;;
        "logs")
            echo -e "${YELLOW}Logs del agente (Ctrl+C para salir):${NC}"
            docker logs -f agente-local
            ;;
        "status")
            detect_api_endpoint
            show_status
            ;;
        *)
            echo -e "${RED}Comando no reconocido: $1${NC}"
            echo -e "${YELLOW}Comandos disponibles: install, rebuild, start, stop, logs, status${NC}"
            exit 1
            ;;
    esac
}

# Verificar permisos
if [ "$EUID" -eq 0 ]; then
    echo -e "${YELLOW}No ejecutes este script como root${NC}"
    echo -e "${YELLOW}Usa: su - tu_usuario${NC}"
    exit 1
fi

# Ejecutar comando
handle_command "$@"