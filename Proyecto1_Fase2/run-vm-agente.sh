#!/bin/bash

# Script para configurar VM del agente con módulos de kernel y Docker
# Autor: Bismarck Romero - 201708880
# Similar al run.sh pero para VM del agente

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                            ║${NC}"
echo -e "${BLUE}║ ${YELLOW}VM AGENTE MONITOR - Bismarck Romero - 201708880${BLUE}           ║${NC}"
echo -e "${BLUE}║              ${YELLOW}MÓDULOS KERNEL + AGENTE DOCKER${BLUE}               ║${NC}"
echo -e "${BLUE}║                                                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo

# Obtener IP de esta VM
VM_IP=$(hostname -I | awk '{print $1}')
echo -e "${YELLOW}IP de esta VM: ${GREEN}$VM_IP${NC}"
echo

# Función para verificar Docker
check_docker() {
    echo -e "${YELLOW}Verificando Docker...${NC}"
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Instalando Docker...${NC}"
        sudo apt update
        sudo apt install -y docker.io
        sudo systemctl enable docker
        sudo systemctl start docker
        sudo usermod -aG docker $USER
        
        echo -e "${YELLOW}Docker instalado. Reinicia la sesión o ejecuta:${NC}"
        echo -e "${BLUE}newgrp docker${NC}"
        echo -e "${YELLOW}Luego vuelve a ejecutar este script.${NC}"
        exit 0
    else
        echo -e "${GREEN} ✓ Docker ya está instalado${NC}"
    fi
    
    # Verificar que Docker esté ejecutándose
    if ! sudo systemctl is-active --quiet docker; then
        echo -e "${YELLOW}Iniciando Docker...${NC}"
        sudo systemctl start docker
    fi
    
    # Verificar que el usuario esté en el grupo docker
    if ! groups $USER | grep -q "docker"; then
        echo -e "${YELLOW}Agregando usuario al grupo docker...${NC}"
        sudo usermod -aG docker $USER
        echo -e "${YELLOW}Ejecuta: newgrp docker${NC}"
        echo -e "${YELLOW}Luego vuelve a ejecutar este script.${NC}"
        exit 0
    fi
}

# Función para instalar módulos del kernel automáticamente
install_kernel_modules() {
    echo -e "${YELLOW}=== INSTALANDO MÓDULOS DEL KERNEL ===${NC}"
    
    # Verificar si ya están cargados
    if lsmod | grep -q "cpu_201708880" && lsmod | grep -q "ram_201708880" && lsmod | grep -q "procesos_201708880"; then
        echo -e "${GREEN} ✓ Módulos del kernel ya están cargados${NC}"
        return 0
    fi
    
    # Verificar si existe kernel.sh
    if [ ! -f "./kernel.sh" ]; then
        echo -e "${RED}Error: kernel.sh no encontrado en el directorio actual${NC}"
        echo -e "${YELLOW}Asegúrate de estar en el directorio raíz del proyecto${NC}"
        exit 1
    fi
    
    # Ejecutar kernel.sh automáticamente
    echo -e "${YELLOW}Ejecutando kernel.sh para instalar módulos...${NC}"
    sudo ./kernel.sh
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al ejecutar kernel.sh${NC}"
        exit 1
    fi
    
    # Verificar que los módulos se cargaron correctamente
    echo -e "${YELLOW}Verificando módulos cargados...${NC}"
    if lsmod | grep -q "cpu_201708880" && lsmod | grep -q "ram_201708880" && lsmod | grep -q "procesos_201708880"; then
        echo -e "${GREEN} ✓ Módulos del kernel cargados correctamente${NC}"
        
        # Mostrar archivos /proc disponibles
        echo -e "${YELLOW}Archivos /proc disponibles:${NC}"
        ls -la /proc/ | grep 201708880
        
        # Probar lectura de métricas
        echo -e "${YELLOW}Probando lectura de métricas:${NC}"
        echo -e "${BLUE}CPU:${NC}"
        cat /proc/cpu_201708880 | head -2
        echo -e "${BLUE}RAM:${NC}"
        cat /proc/ram_201708880 | head -2
        echo -e "${BLUE}Procesos:${NC}"
        cat /proc/procesos_201708880 | head -2
        
    else
        echo -e "${RED}Error: Los módulos no se cargaron correctamente${NC}"
        exit 1
    fi
}

# Función para construir imagen Docker del agente
build_agente_docker() {
    echo -e "${YELLOW}=== CONSTRUYENDO IMAGEN DOCKER DEL AGENTE ===${NC}"
    
    # Verificar que el código del agente existe
    if [ ! -f "Backend/Agente/agente-de-monitor.go" ]; then
        echo -e "${RED}Error: Backend/Agente/agente-de-monitor.go no encontrado${NC}"
        exit 1
    fi
    
    cd Backend/Agente
    
    # Crear/verificar Dockerfile
    if [ ! -f "Dockerfile" ]; then
        echo -e "${YELLOW}Creando Dockerfile para el agente...${NC}"
        cat > Dockerfile << 'EOF'
FROM golang:1.19-alpine AS builder

WORKDIR /app

# Copiar código fuente
COPY agente-de-monitor.go .

# Inicializar módulo Go si no existe
RUN go mod init agente-monitor 2>/dev/null || true
RUN go mod tidy 2>/dev/null || true

# Construir el binario
RUN go build -o agente agente-de-monitor.go

FROM alpine:latest

# Instalar ca-certificates para HTTPS
RUN apk --no-cache add ca-certificates curl

WORKDIR /root/

# Copiar el binario desde el builder
COPY --from=builder /app/agente .

# Variables de entorno por defecto
ENV API_URL="http://host.docker.internal:3000/api/data"
ENV POLL_INTERVAL="2s"

# Comando por defecto
CMD ["./agente"]
EOF
        echo -e "${GREEN} ✓ Dockerfile creado${NC}"
    fi
    
    # Construir imagen
    echo -e "${YELLOW}Construyendo imagen Docker del agente...${NC}"
    docker build -t bismarckr/agente-vm:latest .
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN} ✓ Imagen Docker del agente construida exitosamente${NC}"
    else
        echo -e "${RED}Error al construir la imagen Docker${NC}"
        cd ../..
        exit 1
    fi
    
    cd ../..
}

# Función para configurar y ejecutar el agente
run_agente_container() {
    echo -e "${YELLOW}=== CONFIGURANDO Y EJECUTANDO AGENTE ===${NC}"
    
    # Configurar URL de la API (automático según detección de red)
    if [ -n "$1" ]; then
        # Si se pasa como parámetro
        API_URL="$1"
    else
        # Detectar automáticamente
        echo -e "${YELLOW}Detectando configuración de red...${NC}"
        
        # Verificar si hay conectividad a localhost (misma VM)
        if curl -s --connect-timeout 3 http://localhost:3000/health > /dev/null 2>&1; then
            API_URL="http://host.docker.internal:3000/api/data"
            echo -e "${GREEN}Detectado: API en la misma VM${NC}"
        else
            # Buscar en la red local común (192.168.x.x)
            LOCAL_NETWORK=$(ip route | grep -E '192\.168\.' | head -1 | awk '{print $1}' | cut -d'/' -f1 | cut -d'.' -f1-3)
            if [ -n "$LOCAL_NETWORK" ]; then
                echo -e "${YELLOW}Buscando API en red local ${LOCAL_NETWORK}.x...${NC}"
                
                # Probar IPs comunes en la red local
                for i in 1 100 101 102 103 104 105; do
                    TEST_IP="${LOCAL_NETWORK}.$i"
                    if curl -s --connect-timeout 2 http://$TEST_IP:3000/health > /dev/null 2>&1; then
                        API_URL="http://$TEST_IP:3000/api/data"
                        echo -e "${GREEN}API encontrada en: $TEST_IP${NC}"
                        break
                    fi
                done
            fi
            
            # Si no se encontró, usar configuración manual
            if [ -z "$API_URL" ]; then
                echo -e "${YELLOW}No se pudo detectar la API automáticamente.${NC}"
                read -p "Ingresa la IP de la VM principal: " manual_ip
                API_URL="http://$manual_ip:3000/api/data"
            fi
        fi
    fi
    
    # Configurar intervalo de polling
    POLL_INTERVAL="2s"
    
    echo -e "${GREEN}Configuración del agente:${NC}"
    echo -e "${BLUE}  API_URL: $API_URL${NC}"
    echo -e "${BLUE}  POLL_INTERVAL: $POLL_INTERVAL${NC}"
    
    # Detener contenedor anterior si existe
    echo -e "${YELLOW}Limpiando contenedores anteriores...${NC}"
    docker stop agente-vm-monitor 2>/dev/null || true
    docker rm agente-vm-monitor 2>/dev/null || true
    
    # Ejecutar contenedor con red del host para acceso completo a /proc
    echo -e "${YELLOW}Ejecutando contenedor del agente...${NC}"
    docker run -d \
        --name agente-vm-monitor \
        --restart unless-stopped \
        --network host \
        --pid host \
        --privileged \
        -v /proc:/proc:ro \
        -v /sys:/sys:ro \
        -e API_URL="$API_URL" \
        -e POLL_INTERVAL="$POLL_INTERVAL" \
        bismarckr/agente-vm:latest
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN} ✓ Contenedor del agente iniciado correctamente${NC}"
        
        # Esperar un momento y mostrar logs
        sleep 3
        echo -e "${YELLOW}Logs iniciales del agente:${NC}"
        docker logs agente-vm-monitor | tail -10
        
    else
        echo -e "${RED}Error al iniciar el contenedor del agente${NC}"
        exit 1
    fi
}

# Función para verificar estado completo
check_status() {
    echo -e "${YELLOW}=== VERIFICANDO ESTADO COMPLETO ===${NC}"
    
    # 1. Módulos del kernel
    echo -e "${BLUE}1. Módulos del kernel:${NC}"
    if lsmod | grep -q "201708880"; then
        lsmod | grep "201708880"
        echo -e "${GREEN}   ✓ Módulos cargados correctamente${NC}"
    else
        echo -e "${RED}   ✗ Módulos no están cargados${NC}"
    fi
    
    # 2. Archivos /proc
    echo -e "${BLUE}2. Archivos /proc:${NC}"
    for proc_file in cpu_201708880 ram_201708880 procesos_201708880; do
        if [ -f "/proc/$proc_file" ]; then
            echo -e "${GREEN}   ✓ /proc/$proc_file disponible${NC}"
        else
            echo -e "${RED}   ✗ /proc/$proc_file no disponible${NC}"
        fi
    done
    
    # 3. Contenedor Docker
    echo -e "${BLUE}3. Contenedor Docker:${NC}"
    if docker ps | grep -q "agente-vm-monitor"; then
        echo -e "${GREEN}   ✓ Contenedor ejecutándose${NC}"
        echo -e "${BLUE}   Estado: $(docker ps --filter name=agente-vm-monitor --format "{{.Status}}")${NC}"
    else
        echo -e "${RED}   ✗ Contenedor no está ejecutándose${NC}"
    fi
    
    # 4. Conectividad con la API
    echo -e "${BLUE}4. Conectividad:${NC}"
    if docker exec agente-vm-monitor curl -s --connect-timeout 5 "$API_URL" > /dev/null 2>&1; then
        echo -e "${GREEN}   ✓ Conectividad con API exitosa${NC}"
    else
        echo -e "${RED}   ✗ No hay conectividad con la API${NC}"
        echo -e "${YELLOW}   URL configurada: $API_URL${NC}"
    fi
    
    # 5. Logs recientes
    echo -e "${BLUE}5. Logs recientes:${NC}"
    docker logs agente-vm-monitor --tail 5 2>/dev/null || echo -e "${RED}   No hay logs disponibles${NC}"
}

# Función para mostrar información de uso
show_usage() {
    echo -e "${YELLOW}=== INFORMACIÓN DE USO ===${NC}"
    echo
    echo -e "${GREEN}Comandos disponibles:${NC}"
    echo -e "${BLUE}  ./run-vm-agente.sh              ${NC}# Configuración e instalación completa"
    echo -e "${BLUE}  ./run-vm-agente.sh start        ${NC}# Iniciar agente existente"
    echo -e "${BLUE}  ./run-vm-agente.sh stop         ${NC}# Detener agente"
    echo -e "${BLUE}  ./run-vm-agente.sh restart      ${NC}# Reiniciar agente"
    echo -e "${BLUE}  ./run-vm-agente.sh status       ${NC}# Ver estado completo"
    echo -e "${BLUE}  ./run-vm-agente.sh logs         ${NC}# Ver logs en tiempo real"
    echo -e "${BLUE}  ./run-vm-agente.sh rebuild      ${NC}# Reconstruir imagen y reiniciar"
    echo
    echo -e "${GREEN}Comandos de debug:${NC}"
    echo -e "${BLUE}  lsmod | grep 201708880          ${NC}# Ver módulos cargados"
    echo -e "${BLUE}  cat /proc/cpu_201708880         ${NC}# Ver métricas CPU"
    echo -e "${BLUE}  cat /proc/ram_201708880         ${NC}# Ver métricas RAM"
    echo -e "${BLUE}  docker logs agente-vm-monitor   ${NC}# Ver todos los logs"
    echo
}

# Función principal
main() {
    case "${1:-install}" in
        "install"|"")
            echo -e "${YELLOW}=== INSTALACIÓN COMPLETA DE VM AGENTE ===${NC}"
            check_docker
            install_kernel_modules
            build_agente_docker
            run_agente_container "$2"
            sleep 2
            check_status
            show_usage
            ;;
        "start")
            echo -e "${YELLOW}Iniciando agente existente...${NC}"
            docker start agente-vm-monitor
            sleep 2
            check_status
            ;;
        "stop")
            echo -e "${YELLOW}Deteniendo agente...${NC}"
            docker stop agente-vm-monitor
            echo -e "${GREEN}✓ Agente detenido${NC}"
            ;;
        "restart")
            echo -e "${YELLOW}Reiniciando agente...${NC}"
            docker restart agente-vm-monitor
            sleep 2
            check_status
            ;;
        "status")
            check_status
            ;;
        "logs")
            echo -e "${YELLOW}Mostrando logs en tiempo real (Ctrl+C para salir)...${NC}"
            docker logs -f agente-vm-monitor
            ;;
        "rebuild")
            echo -e "${YELLOW}Reconstruyendo imagen y reiniciando...${NC}"
            docker stop agente-vm-monitor 2>/dev/null || true
            docker rm agente-vm-monitor 2>/dev/null || true
            docker rmi bismarckr/agente-vm:latest 2>/dev/null || true
            build_agente_docker
            run_agente_container "$2"
            sleep 2
            check_status
            ;;
        *)
            echo -e "${RED}Comando no reconocido: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
}

# Verificar si se está ejecutando como root (no recomendado)
if [ "$EUID" -eq 0 ]; then
    echo -e "${YELLOW}Advertencia: No ejecutes este script como root${NC}"
    echo -e "${YELLOW}Ejecuta: su - tu_usuario${NC}"
    echo -e "${YELLOW}Luego: ./run-vm-agente.sh${NC}"
fi

echo
# Ejecutar función principal
main "$@"

echo
echo -e "${GREEN}🎉 VM Agente configurada!${NC}"