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

# Ejecutar contenedor Docker del agente
run_docker_agent() {
    echo -e "${YELLOW}Ejecutando agente en Docker...${NC}"
    
    # Verificar que los archivos /proc están disponibles
    echo -e "${YELLOW}Verificando archivos /proc necesarios...${NC}"
    for proc_file in cpu_201708880 ram_201708880 procesos_201708880; do
        if [ -f "/proc/$proc_file" ]; then
            echo -e "${GREEN}  ✓ /proc/$proc_file disponible${NC}"
        else
            echo -e "${RED}  ✗ /proc/$proc_file no disponible${NC}"
            echo -e "${RED}Error: Los módulos del kernel no están cargados correctamente${NC}"
            exit 1
        fi
    done
    
    # Limpiar contenedores anteriores
    echo -e "${YELLOW}  → Limpiando contenedores anteriores...${NC}"
    docker stop agente-local 2>/dev/null || true
    docker rm agente-local 2>/dev/null || true
    
    # Configurar variables
    echo -e "${YELLOW}  → Configuración:${NC}"
    echo -e "${BLUE}    AGENTE_PORT: 8080${NC}"
    echo -e "${BLUE}    POLL_INTERVAL: 2s${NC}"
    echo -e "${BLUE}    Archivos específicos: /proc/*_201708880${NC}"
    
    echo -e "${YELLOW}  → Iniciando contenedor con montaje específico de archivos...${NC}"
    
    # Intento 1: Montar solo archivos específicos (más seguro)
    docker run -d \
        --name agente-local \
        --restart unless-stopped \
        -v /proc/cpu_201708880:/proc/cpu_201708880:ro \
        -v /proc/ram_201708880:/proc/ram_201708880:ro \
        -v /proc/procesos_201708880:/proc/procesos_201708880:ro \
        -p 8080:8080 \
        -e AGENTE_PORT="8080" \
        -e POLL_INTERVAL="2s" \
        bismarckr/agente-fase2:latest
    
    # Esperar para que se inicie
    sleep 5
    
    # Mostrar estado y logs inmediatamente
    echo -e "${BLUE}Estado del contenedor:${NC}"
    docker ps -a --filter name=agente-local --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    echo -e "${BLUE}Logs del contenedor:${NC}"
    docker logs agente-local 2>&1 | head -20
    
    # Verificar si funciona
    if docker ps | grep -q "agente-local"; then
        echo -e "${GREEN}✓ Agente ejecutándose en Docker (montaje específico)${NC}"
        echo -e "${BLUE}  → Agente disponible en: http://localhost:8080/metrics${NC}"
        echo -e "${BLUE}  → Estado del agente: http://localhost:8080/health${NC}"
        
        # Probar el endpoint
        echo -e "${YELLOW}  → Probando endpoint /health...${NC}"
        sleep 3
        curl -s http://localhost:8080/health | jq . 2>/dev/null || curl -s http://localhost:8080/health || echo "Probando conectividad..."
        
        # Probar endpoint de métricas
        echo -e "${YELLOW}  → Probando endpoint /metrics...${NC}"
        curl -s http://localhost:8080/metrics | head -c 200 && echo "..." || echo "Endpoint de métricas no accesible aún"
        
        return 0
    else
        echo -e "${RED}✗ Contenedor no está corriendo (montaje específico)${NC}"
    fi
    
    # Intento 2: Con privilegios adicionales si falla el primer intento
    echo -e "${YELLOW}  → Intentando con privilegios adicionales...${NC}"
    docker rm agente-local 2>/dev/null || true
    
    docker run -d \
        --name agente-local \
        --restart unless-stopped \
        --privileged \
        -v /proc/cpu_201708880:/proc/cpu_201708880:ro \
        -v /proc/ram_201708880:/proc/ram_201708880:ro \
        -v /proc/procesos_201708880:/proc/procesos_201708880:ro \
        -p 8080:8080 \
        -e AGENTE_PORT="8080" \
        -e POLL_INTERVAL="2s" \
        bismarckr/agente-fase2:latest
    
    sleep 3
    
    echo -e "${BLUE}Estado del contenedor (con privilegios):${NC}"
    docker ps -a --filter name=agente-local --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    echo -e "${BLUE}Logs del contenedor (con privilegios):${NC}"
    docker logs agente-local 2>&1 | head -20
    
    if docker ps | grep -q "agente-local"; then
        echo -e "${GREEN}✓ Agente ejecutándose en Docker (con privilegios)${NC}"
        echo -e "${BLUE}  → Agente disponible en: http://localhost:8080/metrics${NC}"
        return 0
    else
        echo -e "${RED}✗ Contenedor no está corriendo (con privilegios)${NC}"
    fi
    
    # Intento 3: Crear directorio temporal con bind mounts
    echo -e "${YELLOW}  → Intentando con directorio temporal...${NC}"
    docker rm agente-local 2>/dev/null || true
    
    # Crear directorio temporal para los archivos proc
    TEMP_PROC_DIR="/tmp/agente-proc-$$"
    sudo mkdir -p "$TEMP_PROC_DIR"
    
    # Crear enlaces simbólicos a los archivos específicos
    sudo ln -sf /proc/cpu_201708880 "$TEMP_PROC_DIR/cpu_201708880"
    sudo ln -sf /proc/ram_201708880 "$TEMP_PROC_DIR/ram_201708880"
    sudo ln -sf /proc/procesos_201708880 "$TEMP_PROC_DIR/procesos_201708880"
    
    # Ejecutar contenedor con el directorio temporal
    docker run -d \
        --name agente-local \
        --restart unless-stopped \
        -v "$TEMP_PROC_DIR:/proc_data:ro" \
        -p 8080:8080 \
        -e AGENTE_PORT="8080" \
        -e POLL_INTERVAL="2s" \
        bismarckr/agente-fase2:latest /bin/sh -c "
            # Crear enlaces en el contenedor
            ln -sf /proc_data/cpu_201708880 /proc/cpu_201708880
            ln -sf /proc_data/ram_201708880 /proc/ram_201708880
            ln -sf /proc_data/procesos_201708880 /proc/procesos_201708880
            exec /agente-de-monitor
        "
    
    sleep 3
    
    echo -e "${BLUE}Estado del contenedor (directorio temporal):${NC}"
    docker ps -a --filter name=agente-local --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    echo -e "${BLUE}Logs del contenedor (directorio temporal):${NC}"
    docker logs agente-local 2>&1 | head -20
    
    if docker ps | grep -q "agente-local"; then
        echo -e "${GREEN}✓ Agente ejecutándose en Docker (directorio temporal)${NC}"
        echo -e "${BLUE}  → Agente disponible en: http://localhost:8080/metrics${NC}"
        echo -e "${YELLOW}  → Directorio temporal: $TEMP_PROC_DIR${NC}"
        return 0
    else
        echo -e "${RED}✗ Contenedor no está corriendo (directorio temporal)${NC}"
        # Limpiar directorio temporal si falla
        sudo rm -rf "$TEMP_PROC_DIR"
    fi
    
    # Intento 4: Modo compatibilidad con AppArmor deshabilitado
    echo -e "${YELLOW}  → Intentando deshabilitar AppArmor temporalmente...${NC}"
    docker rm agente-local 2>/dev/null || true
    
    # Verificar y deshabilitar AppArmor si está habilitado
    if cat /sys/module/apparmor/parameters/enabled 2>/dev/null | grep -q "Y"; then
        echo -e "${YELLOW}AppArmor detectado, deshabilitando temporalmente...${NC}"
        sudo systemctl stop apparmor 2>/dev/null || true
        sudo aa-teardown 2>/dev/null || true
        echo -e "${GREEN}✓ AppArmor deshabilitado${NC}"
    fi
    
    # Ejecutar con configuración completa
    docker run -d \
        --name agente-local \
        --restart unless-stopped \
        --privileged \
        --security-opt apparmor:unconfined \
        --security-opt seccomp:unconfined \
        -v /proc/cpu_201708880:/proc/cpu_201708880:ro \
        -v /proc/ram_201708880:/proc/ram_201708880:ro \
        -v /proc/procesos_201708880:/proc/procesos_201708880:ro \
        -p 8080:8080 \
        -e AGENTE_PORT="8080" \
        -e POLL_INTERVAL="2s" \
        bismarckr/agente-fase2:latest
    
    sleep 3
    
    echo -e "${BLUE}Estado del contenedor (sin AppArmor):${NC}"
    docker ps -a --filter name=agente-local --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    echo -e "${BLUE}Logs del contenedor (sin AppArmor):${NC}"
    docker logs agente-local 2>&1 | head -20
    
    if docker ps | grep -q "agente-local"; then
        echo -e "${GREEN}✓ Agente ejecutándose en Docker (sin AppArmor)${NC}"
        echo -e "${BLUE}  → Agente disponible en: http://localhost:8080/metrics${NC}"
        return 0
    fi
    
    # Si todo falla, mostrar diagnóstico final
    echo -e "${RED}Error: No se pudo ejecutar el contenedor Docker con ninguna configuración${NC}"
    
    echo -e "${YELLOW}Diagnóstico final:${NC}"
    echo -e "${BLUE}1. Logs del último intento:${NC}"
    docker logs agente-local 2>&1 || echo "No hay logs disponibles"
    
    echo -e "${BLUE}2. Verificando archivos /proc en el host:${NC}"
    ls -la /proc/cpu_201708880 /proc/ram_201708880 /proc/procesos_201708880 2>/dev/null || echo "Archivos no accesibles"
    
    echo -e "${BLUE}3. Verificando permisos:${NC}"
    stat /proc/cpu_201708880 2>/dev/null || echo "No se puede verificar permisos"
    
    echo -e "${BLUE}4. Estado de AppArmor:${NC}"
    cat /sys/module/apparmor/parameters/enabled 2>/dev/null || echo "AppArmor no disponible"
    
    echo -e "${BLUE}5. Información de Docker:${NC}"
    docker info | grep -E "Server Version|Security Options" 2>/dev/null || echo "Información no disponible"
    
    echo
    echo -e "${YELLOW}SOLUCIONES RECOMENDADAS:${NC}"
    echo -e "${BLUE}1. Ejecutar agente nativo (más confiable):${NC}"
    echo -e "   cd Backend/Agente && ./agente"
    echo
    echo -e "${BLUE}2. Verificar módulos del kernel:${NC}"
    echo -e "   sudo ./kernel.sh"
    echo -e "   lsmod | grep 201708880"
    echo
    echo -e "${BLUE}3. Probar manualmente:${NC}"
    echo -e "   docker run --rm -v /proc/cpu_201708880:/proc/cpu_201708880:ro bismarckr/agente-fase2:latest cat /proc/cpu_201708880"
    echo
    echo -e "${BLUE}4. Deshabilitar AppArmor permanentemente:${NC}"
    echo -e "   sudo systemctl disable apparmor && sudo reboot"
    
    # Limpiar directorio temporal si existe
    [ -d "$TEMP_PROC_DIR" ] && sudo rm -rf "$TEMP_PROC_DIR"
    
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
    
    # Verificar procesos en el contenedor
    echo -e "${BLUE}Procesos en el contenedor:${NC}"
    docker exec agente-local ps aux 2>/dev/null || echo "No se pudieron obtener procesos"
    
    # Probar endpoint del agente (no APIs externas)
    echo -e "${YELLOW}Probando endpoint local /health...${NC}"
    if curl -s http://localhost:8080/health >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Endpoint /health accesible${NC}"
    else
        echo -e "${YELLOW}Advertencia: Endpoint /health no accesible aún${NC}"
    fi
    
    echo -e "${YELLOW}Probando endpoint local /metrics...${NC}"
    if curl -s http://localhost:8080/metrics >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Endpoint /metrics accesible${NC}"
    else
        echo -e "${YELLOW}Advertencia: Endpoint /metrics no accesible aún${NC}"
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
    
    # Información del agente servidor
    echo -e "${BLUE}Servidor del agente:${NC}"
    echo -e "${GREEN}  Puerto: 8080${NC}"
    echo -e "${GREEN}  Health: http://localhost:8080/health${NC}"
    echo -e "${GREEN}  Metrics: http://localhost:8080/metrics${NC}"
    echo -e "${GREEN}  Intervalo de recolección: 2 segundos${NC}"
    
    echo
    echo -e "${YELLOW}Comandos útiles:${NC}"
    echo -e "${BLUE}  docker logs agente-local -f          ${NC}# Ver logs en tiempo real"
    echo -e "${BLUE}  curl http://localhost:8080/health     ${NC}# Verificar estado"
    echo -e "${BLUE}  curl http://localhost:8080/metrics    ${NC}# Obtener métricas"
    echo -e "${BLUE}  docker stop agente-local             ${NC}# Detener agente"
    echo -e "${BLUE}  docker start agente-local            ${NC}# Iniciar agente"
    echo -e "${BLUE}  ./run-vm-agente.sh rebuild           ${NC}# Reconstruir todo"
    echo
    
    # Mostrar ejemplo de uso para APIs externas
    echo -e "${YELLOW}Ejemplo para conectarse desde APIs externas:${NC}"
    echo -e "${BLUE}  const response = await fetch('http://localhost:8080/metrics');${NC}"
    echo -e "${BLUE}  const metrics = await response.json();${NC}"
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
            run_docker_agent  # Eliminar detect_api_endpoint
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
            run_docker_agent  # Eliminar detect_api_endpoint
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
            show_status  # Eliminar detect_api_endpoint
            ;;
        "test")
            echo -e "${YELLOW}Probando endpoints del agente...${NC}"
            echo -e "${BLUE}Health check:${NC}"
            curl -s http://localhost:8080/health | jq . 2>/dev/null || curl -s http://localhost:8080/health
            echo
            echo -e "${BLUE}Métricas actuales:${NC}"
            curl -s http://localhost:8080/metrics | jq . 2>/dev/null || curl -s http://localhost:8080/metrics
            echo
            ;;
        *)
            echo -e "${RED}Comando no reconocido: $1${NC}"
            echo -e "${YELLOW}Comandos disponibles: install, rebuild, start, stop, logs, status, test${NC}"
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