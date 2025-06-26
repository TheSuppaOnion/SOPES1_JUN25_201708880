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

# Función para instalar Go manualmente
install_go_manually() {
    echo -e "${YELLOW}Instalando Go manualmente...${NC}"
    
    # Detectar arquitectura
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) GO_ARCH="amd64" ;;
        aarch64) GO_ARCH="arm64" ;;
        armv7l) GO_ARCH="armv6l" ;;
        *) 
            echo -e "${RED}Arquitectura no soportada: $ARCH${NC}"
            echo -e "${YELLOW}Instala Go manualmente desde: https://golang.org/dl/${NC}"
            exit 1
            ;;
    esac
    
    # Versión de Go a descargar
    GO_VERSION="1.21.5"
    GO_FILENAME="go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
    GO_URL="https://golang.org/dl/${GO_FILENAME}"
    
    echo -e "${YELLOW}  → Descargando Go ${GO_VERSION} para ${GO_ARCH}...${NC}"
    
    # Crear directorio temporal
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Descargar Go
    if command -v wget &> /dev/null; then
        wget -q --show-progress "$GO_URL"
    elif command -v curl &> /dev/null; then
        curl -L -o "$GO_FILENAME" "$GO_URL"
    else
        echo -e "${RED}Error: wget o curl no están disponibles${NC}"
        echo -e "${YELLOW}Instala manualmente: sudo apt install wget curl${NC}"
        exit 1
    fi
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al descargar Go${NC}"
        echo -e "${YELLOW}Descarga manualmente desde: https://golang.org/dl/${NC}"
        exit 1
    fi
    
    # Verificar descarga
    if [ ! -f "$GO_FILENAME" ]; then
        echo -e "${RED}Error: Archivo Go no se descargó${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}  → Instalando Go en /usr/local/go...${NC}"
    
    # Remover instalación anterior si existe
    sudo rm -rf /usr/local/go
    
    # Extraer Go
    sudo tar -C /usr/local -xzf "$GO_FILENAME"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al extraer Go${NC}"
        exit 1
    fi
    
    # Agregar Go al PATH
    if ! grep -q "/usr/local/go/bin" ~/.bashrc; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
        echo -e "${YELLOW}  → Agregado Go al PATH en ~/.bashrc${NC}"
    fi
    
    # Agregar al PATH actual
    export PATH=$PATH:/usr/local/go/bin
    
    # Limpiar archivos temporales
    cd - > /dev/null
    rm -rf "$TEMP_DIR"
    
    # Verificar instalación
    if go version &> /dev/null; then
        GO_VERSION_INSTALLED=$(go version | awk '{print $3}')
        echo -e "${GREEN}✓ Go $GO_VERSION_INSTALLED instalado exitosamente${NC}"
        echo -e "${YELLOW}  → Reinicia la terminal o ejecuta: source ~/.bashrc${NC}"
    else
        echo -e "${RED}Error: Go no se instaló correctamente${NC}"
        echo -e "${YELLOW}Verifica manualmente: /usr/local/go/bin/go version${NC}"
        exit 1
    fi
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
    
    # Verificar Go (solo si vamos a compilar)
    if [ "${BUILD_MODE}" = "compile" ]; then
        # Verificar si Go ya está en PATH
        if [ -d "/usr/local/go/bin" ] && [[ ":$PATH:" != *":/usr/local/go/bin:"* ]]; then
            export PATH=$PATH:/usr/local/go/bin
        fi
        
        if ! go version &> /dev/null; then
            echo -e "${YELLOW}Go no está instalado. Instalando automáticamente...${NC}"
            
            # Opción 1: Intentar instalar desde repositorio
            echo -e "${YELLOW}  → Intentando instalar desde repositorio...${NC}"
            if command -v apt &> /dev/null; then
                sudo apt update && sudo apt install -y golang-go
                
                # Verificar si la instalación funcionó
                if go version &> /dev/null; then
                    GO_VERSION=$(go version | awk '{print $3}')
                    echo -e "${GREEN}✓ Go $GO_VERSION instalado desde repositorio${NC}"
                else
                    echo -e "${YELLOW}Instalación desde repositorio falló. Descargando versión oficial...${NC}"
                    install_go_manually
                fi
            else
                echo -e "${YELLOW}apt no disponible. Descargando Go manualmente...${NC}"
                install_go_manually
            fi
        else
            GO_VERSION=$(go version | awk '{print $3}')
            echo -e "${GREEN}✓ Go $GO_VERSION disponible${NC}"
        fi
        
        # Verificar herramientas de compilación
        if ! command -v make &> /dev/null; then
            echo -e "${YELLOW}Instalando herramientas de compilación...${NC}"
            if command -v apt &> /dev/null; then
                sudo apt update && sudo apt install -y build-essential
            else
                echo -e "${RED}Error: No se pueden instalar herramientas de compilación automáticamente${NC}"
                echo -e "${YELLOW}Instala manualmente: sudo apt install build-essential${NC}"
                exit 1
            fi
        fi
        
        echo -e "${GREEN}✓ Herramientas de compilación disponibles${NC}"
    fi
}

# Verificar si existe imagen en Docker Hub
check_dockerhub_image() {
    echo -e "${YELLOW}Verificando si existe imagen en Docker Hub...${NC}"
    
    IMAGE_NAME="bismarckr/agente-fase2"
    
    echo -e "${YELLOW}  → Buscando imagen: $IMAGE_NAME${NC}"
    
    # Intentar obtener información de la imagen
    if docker manifest inspect "$IMAGE_NAME:latest" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Imagen encontrada en Docker Hub: $IMAGE_NAME:latest${NC}"
        
        # Obtener información básica de la imagen
        echo -e "${BLUE}Información de la imagen:${NC}"
        SIZE_INFO=$(docker manifest inspect "$IMAGE_NAME:latest" 2>/dev/null | grep -o '"size":[0-9]*' | head -1 | cut -d':' -f2)
        if [ ! -z "$SIZE_INFO" ]; then
            SIZE_MB=$((SIZE_INFO / 1024 / 1024))
            echo -e "${BLUE}  Tamaño aproximado: ${SIZE_MB}MB${NC}"
        fi
        
        return 0
    else
        echo -e "${YELLOW}✗ Imagen no encontrada en Docker Hub${NC}"
        return 1
    fi
}

# Descargar imagen desde Docker Hub
download_dockerhub_image() {
    echo -e "${YELLOW}Descargando imagen desde Docker Hub...${NC}"
    
    IMAGE_NAME="bismarckr/agente-fase2:latest"
    
    echo -e "${YELLOW}  → Descargando: docker pull $IMAGE_NAME${NC}"
    docker pull "$IMAGE_NAME"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al descargar imagen desde Docker Hub${NC}"
        return 1
    fi
    
    # Verificar que la imagen se descargó correctamente
    if ! docker images | grep -q "bismarckr/agente-fase2"; then
        echo -e "${RED}Error: Imagen no se descargó correctamente${NC}"
        return 1
    fi
    
    # Mostrar información de la imagen descargada
    IMAGE_SIZE=$(docker images bismarckr/agente-fase2:latest --format "table {{.Size}}" | tail -1)
    IMAGE_ID=$(docker images bismarckr/agente-fase2:latest --format "table {{.ID}}" | tail -1)
    
    echo -e "${GREEN}✓ Imagen descargada exitosamente${NC}"
    echo -e "${BLUE}  ID: $IMAGE_ID${NC}"
    echo -e "${BLUE}  Tamaño: $IMAGE_SIZE${NC}"
    
    return 0
}

# Función para preguntar al usuario qué opción elegir
choose_image_option() {
    echo
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║                   OPCIONES DE INSTALACIÓN                 ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${BLUE}Se encontró una imagen pre-compilada en Docker Hub.${NC}"
    echo -e "${BLUE}¿Qué opción prefieres?${NC}"
    echo
    echo -e "${GREEN}1) Descargar imagen desde Docker Hub ${YELLOW}(más rápido)${NC}"
    echo -e "${GREEN}2) Compilar localmente ${YELLOW}(más control)${NC}"
    echo -e "${GREEN}3) Ver información de ambas opciones${NC}"
    echo
    
    while true; do
        read -p "$(echo -e ${YELLOW}Selecciona una opción [1-3]: ${NC})" choice
        
        case $choice in
            1)
                echo -e "${GREEN}✓ Opción seleccionada: Descargar desde Docker Hub${NC}"
                return 1  # Descargar
                ;;
            2)
                echo -e "${GREEN}✓ Opción seleccionada: Compilar localmente${NC}"
                return 2  # Compilar
                ;;
            3)
                show_image_options_info
                ;;
            *)
                echo -e "${RED}Opción no válida. Selecciona 1, 2 o 3.${NC}"
                ;;
        esac
    done
}

# Mostrar información de las opciones
show_image_options_info() {
    echo
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                  INFORMACIÓN DE OPCIONES                  ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${GREEN}OPCIÓN 1: Descargar desde Docker Hub${NC}"
    echo -e "${BLUE}  ✓ Más rápido (solo descarga)${NC}"
    echo -e "${BLUE}  ✓ Imagen pre-compilada y probada${NC}"
    echo -e "${BLUE}  ✓ No requiere compilación local${NC}"
    echo -e "${BLUE}  ✓ Menos uso de recursos${NC}"
    echo -e "${YELLOW}  ⚠ Depende de conectividad a internet${NC}"
    echo -e "${YELLOW}  ⚠ Menos control sobre el proceso${NC}"
    echo
    echo -e "${GREEN}OPCIÓN 2: Compilar localmente${NC}"
    echo -e "${BLUE}  ✓ Control total del proceso${NC}"
    echo -e "${BLUE}  ✓ Optimización para tu sistema${NC}"
    echo -e "${BLUE}  ✓ No depende de internet${NC}"
    echo -e "${BLUE}  ✓ Puedes modificar el código${NC}"
    echo -e "${YELLOW}  ⚠ Más lento (compilación + build)${NC}"
    echo -e "${YELLOW}  ⚠ Requiere herramientas de desarrollo${NC}"
    echo -e "${YELLOW}  ⚠ Más uso de recursos${NC}"
    echo
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
    
    # Probar ejecución básica
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

# Función para compilar y construir localmente
compile_and_build_locally() {
    echo -e "${YELLOW}Iniciando compilación local...${NC}"
    BUILD_MODE="compile"
    verify_go_agent
    compile_go_agent
    build_docker_image
}

# Función principal de instalación con opciones
install_agent_with_options() {
    echo -e "${YELLOW}=== INSTALACIÓN INTELIGENTE DEL AGENTE ===${NC}"
    
    # Verificaciones básicas
    check_directory
    check_dependencies
    build_kernel_modules
    
    # Verificar si existe imagen en Docker Hub
    if check_dockerhub_image; then
        # Imagen disponible en Docker Hub
        choose_image_option
        option=$?
        
        case $option in
            1)
                # Descargar desde Docker Hub
                echo -e "${YELLOW}Descargando imagen desde Docker Hub...${NC}"
                if download_dockerhub_image; then
                    echo -e "${GREEN}✓ Imagen descargada correctamente${NC}"
                else
                    echo -e "${RED}Error al descargar. Compilando localmente...${NC}"
                    compile_and_build_locally
                fi
                ;;
            2)
                # Compilar localmente
                echo -e "${YELLOW}Compilando localmente...${NC}"
                compile_and_build_locally
                ;;
        esac
    else
        # No hay imagen en Docker Hub, compilar localmente
        echo -e "${YELLOW}No se encontró imagen en Docker Hub. Compilando localmente...${NC}"
        compile_and_build_locally
    fi
    
    # Ejecutar agente
    run_docker_agent
    verify_agent
    show_status
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
        
        # Intento 2: Con privilegios adicionales
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
        
        if docker ps | grep -q "agente-local"; then
            echo -e "${GREEN}✓ Agente ejecutándose en Docker (con privilegios)${NC}"
            return 0
        else
            echo -e "${RED}Error: No se pudo ejecutar el contenedor Docker${NC}"
            exit 1
        fi
    fi
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
    
    # Probar endpoint del agente
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

# Función de ayuda
show_help() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    AYUDA DEL SCRIPT                       ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${YELLOW}COMANDOS DISPONIBLES:${NC}"
    echo
    echo -e "${GREEN}install${NC}   - Instalación inteligente"
    echo -e "${BLUE}            Detecta si hay imagen en Docker Hub y te permite elegir${NC}"
    echo
    echo -e "${GREEN}download${NC}  - Descargar desde Docker Hub"
    echo -e "${BLUE}            Fuerza la descarga de la imagen pre-compilada${NC}"
    echo
    echo -e "${GREEN}compile${NC}   - Compilar localmente"
    echo -e "${BLUE}            Fuerza la compilación local del código fuente${NC}"
    echo
    echo -e "${GREEN}rebuild${NC}   - Reconstruir completamente"
    echo -e "${BLUE}            Elimina todo y recompila desde cero${NC}"
    echo
    echo -e "${GREEN}start${NC}     - Iniciar agente"
    echo -e "${GREEN}stop${NC}      - Detener agente"
    echo -e "${GREEN}logs${NC}      - Ver logs en tiempo real"
    echo -e "${GREEN}status${NC}    - Ver estado actual"
    echo -e "${GREEN}test${NC}      - Probar endpoints del agente"
    echo -e "${GREEN}update${NC}    - Actualizar imagen desde Docker Hub"
    echo -e "${GREEN}help${NC}      - Mostrar esta ayuda"
    echo
    echo -e "${YELLOW}EJEMPLOS:${NC}"
    echo -e "${BLUE}  ./run-vm-agente.sh install   # Instalación inteligente${NC}"
    echo -e "${BLUE}  ./run-vm-agente.sh download  # Solo descargar${NC}"
    echo -e "${BLUE}  ./run-vm-agente.sh compile   # Solo compilar${NC}"
    echo -e "${BLUE}  ./run-vm-agente.sh test      # Probar endpoints${NC}"
    echo
}

# Función mejorada para manejar comandos
handle_command() {
    case "${1:-install}" in
        "install"|"")
            install_agent_with_options
            ;;
        "download")
            echo -e "${YELLOW}=== DESCARGA DESDE DOCKER HUB ===${NC}"
            check_directory
            check_dependencies
            build_kernel_modules
            if check_dockerhub_image; then
                download_dockerhub_image
                run_docker_agent
                verify_agent
                show_status
            else
                echo -e "${RED}No se encontró imagen en Docker Hub${NC}"
                echo -e "${YELLOW}Usa: ./run-vm-agente.sh compile${NC}"
                exit 1
            fi
            ;;
        "compile")
            echo -e "${YELLOW}=== COMPILACIÓN LOCAL ===${NC}"
            check_directory
            BUILD_MODE="compile"
            check_dependencies
            build_kernel_modules
            compile_and_build_locally
            run_docker_agent
            verify_agent
            show_status
            ;;
        "rebuild")
            echo -e "${YELLOW}=== RECONSTRUYENDO AGENTE ===${NC}"
            docker stop agente-local 2>/dev/null || true
            docker rm agente-local 2>/dev/null || true
            docker rmi bismarckr/agente-fase2:latest 2>/dev/null || true
            BUILD_MODE="compile"
            check_dependencies
            compile_and_build_locally
            run_docker_agent
            show_status
            ;;
        "start")
            echo -e "${YELLOW}Iniciando agente...${NC}"
            if ! docker images | grep -q "bismarckr/agente-fase2"; then
                echo -e "${RED}Error: No hay imagen disponible${NC}"
                echo -e "${YELLOW}Ejecuta primero: ./run-vm-agente.sh install${NC}"
                exit 1
            fi
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
            show_status
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
        "update")
            echo -e "${YELLOW}Actualizando imagen desde Docker Hub...${NC}"
            docker stop agente-local 2>/dev/null || true
            docker rm agente-local 2>/dev/null || true
            docker rmi bismarckr/agente-fase2:latest 2>/dev/null || true
            if download_dockerhub_image; then
                run_docker_agent
                show_status
            else
                echo -e "${RED}Error al actualizar imagen${NC}"
                exit 1
            fi
            ;;
        "help")
            show_help
            ;;
        *)
            echo -e "${RED}Comando no reconocido: $1${NC}"
            echo -e "${YELLOW}Comandos disponibles:${NC}"
            echo -e "${BLUE}  install  - Instalación inteligente (detecta Docker Hub)${NC}"
            echo -e "${BLUE}  download - Forzar descarga desde Docker Hub${NC}"
            echo -e "${BLUE}  compile  - Forzar compilación local${NC}"
            echo -e "${BLUE}  rebuild  - Reconstruir completamente${NC}"
            echo -e "${BLUE}  start    - Iniciar agente${NC}"
            echo -e "${BLUE}  stop     - Detener agente${NC}"
            echo -e "${BLUE}  logs     - Ver logs${NC}"
            echo -e "${BLUE}  status   - Ver estado${NC}"
            echo -e "${BLUE}  test     - Probar endpoints${NC}"
            echo -e "${BLUE}  update   - Actualizar desde Docker Hub${NC}"
            echo -e "${BLUE}  help     - Mostrar ayuda${NC}"
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