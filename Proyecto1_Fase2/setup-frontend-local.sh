#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                            ║${NC}"
echo -e "${BLUE}║ ${YELLOW}FRONTEND REACT CON DOCKER - Bismarck Romero - 201708880${BLUE}  ║${NC}"
echo -e "${BLUE}║                                                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo

# Verificar Docker
check_docker() {
    echo -e "${YELLOW}Verificando Docker...${NC}"
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}✗ Docker no está instalado${NC}"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        echo -e "${RED}✗ Docker no está ejecutándose${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Docker está disponible${NC}"
}

# Hacer build usando Docker (CORREGIDO - sin npm ci)
build_with_docker() {
    echo -e "${YELLOW}Construyendo build de React a partir del src existente...${NC}"
    cd Frontend
    docker run --rm -v "$PWD":/app -w /app node:18-alpine sh -c "npm install --silent && npm run build"
    cd ..
}

# Construir imagen Docker del Frontend (usando multi-stage build directamente)
build_frontend_image() {
    echo -e "${YELLOW}Intentando obtener la imagen desde Docker Hub...${NC}"
    if docker pull bismarckr/frontend-fase2:latest; then
        echo -e "${GREEN}✓ Imagen encontrada en Docker Hub${NC}"
        echo -n "¿Deseas descargar la imagen de Docker Hub (d) o buildear localmente (b)? [d/b]: "
        read opcion
        if [[ "$opcion" =~ ^[bB]$ ]]; then
            echo -e "${YELLOW}→ Buildeando imagen localmente...${NC}"
            docker build -t bismarckr/frontend-fase2:latest Frontend
        else
            echo -e "${YELLOW}→ Usando imagen descargada de Docker Hub${NC}"
        fi
    else
        echo -e "${YELLOW}No se encontró la imagen en Docker Hub. Buildeando localmente...${NC}"
        docker build -t bismarckr/frontend-fase2:latest Frontend
    fi
}

# Ejecutar contenedor del Frontend
run_frontend_container() {
    echo -e "${YELLOW}Ejecutando contenedor del Frontend...${NC}"
    docker stop frontend-local 2>/dev/null || true
    docker rm frontend-local 2>/dev/null || true
    docker run -d \
        --name frontend-local \
        --restart unless-stopped \
        -p 3001:80 \
        bismarckr/frontend-fase2:latest

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Contenedor iniciado correctamente${NC}"
        sleep 3
        if docker ps | grep -q "frontend-local"; then
            echo -e "${GREEN}✓ Frontend ejecutándose en http://localhost:3001${NC}"
        fi
    else
        echo -e "${RED}✗ Error al iniciar contenedor${NC}"
        exit 1
    fi
}

# Mostrar estado
show_status() {
    echo -e "${YELLOW}=== ESTADO DEL FRONTEND ===${NC}"
    
    if docker ps | grep -q "frontend-local"; then
        echo -e "${GREEN}✓ Contenedor ejecutándose${NC}"
        docker ps --filter name=frontend-local --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    else
        echo -e "${RED}✗ Contenedor no ejecutándose${NC}"
    fi
    
    if [ -d "Frontend/build" ]; then
        BUILD_SIZE=$(du -sh Frontend/build/ | cut -f1)
        echo -e "${BLUE}Build React: ✓ Disponible (tamaño: $BUILD_SIZE)${NC}"
    else
        echo -e "${BLUE}Build React: ✗ No disponible${NC}"
    fi
    
    if curl -s --connect-timeout 5 http://localhost:3001/ > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Frontend accesible en http://localhost:3001${NC}"
    else
        echo -e "${YELLOW}⚠ Frontend puede estar iniciando${NC}"
    fi
}

# Función principal
main() {
    case "${1:-install}" in
        "install"|"")
            echo -e "${YELLOW}=== INSTALACIÓN DEL FRONTEND ===${NC}"
            check_docker
            build_frontend_image
            build_with_docker
            run_frontend_container
            show_status
            echo
            echo -e "${GREEN}✓ Frontend listo en http://localhost:3001${NC}"
            ;;
        "build")
            check_docker
            build_with_docker
            echo -e "${GREEN}✓ Build completado${NC}"
            ;;
        "start")
            docker start frontend-local
            show_status
            ;;
        "stop")
            docker stop frontend-local
            echo -e "${GREEN}✓ Frontend detenido${NC}"
            ;;
        "restart")
            docker restart frontend-local
            sleep 3
            show_status
            ;;
        "status")
            show_status
            ;;
        "logs")
            docker logs -f frontend-local
            ;;
        "rebuild")
            check_docker
            docker stop frontend-local 2>/dev/null || true
            docker rm frontend-local 2>/dev/null || true
            docker rmi bismarckr/frontend-fase2:latest 2>/dev/null || true
            build_frontend_image
            build_with_docker
            run_frontend_container
            show_status
            ;;
        *)
            echo -e "${RED}✗ Comando no reconocido: $1${NC}"
            echo -e "${YELLOW}Comandos disponibles: install, build, start, stop, restart, status, logs, rebuild${NC}"
            exit 1
            ;;
    esac
}

# Ejecutar función principal
main "$@"

echo
echo -e "${GREEN}✓ Frontend React con Docker configurado${NC}"