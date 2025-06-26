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

# Verificar Node.js y npm
check_nodejs() {
    echo -e "${YELLOW}Verificando Node.js y npm...${NC}"
    
    if ! command -v node &> /dev/null; then
        echo -e "${RED}Node.js no está instalado${NC}"
        echo -e "${YELLOW}Instala Node.js desde: https://nodejs.org${NC}"
        echo -e "${YELLOW}O usa: sudo apt install nodejs npm${NC}"
        exit 1
    fi
    
    if ! command -v npm &> /dev/null; then
        echo -e "${RED}npm no está instalado${NC}"
        echo -e "${YELLOW}Instala npm: sudo apt install npm${NC}"
        exit 1
    fi
    
    NODE_VERSION=$(node --version)
    NPM_VERSION=$(npm --version)
    echo -e "${GREEN}✓ Node.js $NODE_VERSION disponible${NC}"
    echo -e "${GREEN}✓ npm $NPM_VERSION disponible${NC}"
}

# Verificar Docker
check_docker() {
    echo -e "${YELLOW}Verificando Docker...${NC}"
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker no está instalado${NC}"
        echo -e "${YELLOW}Instala Docker y vuelve a ejecutar este script${NC}"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        echo -e "${RED}Docker no está ejecutándose${NC}"
        echo -e "${YELLOW}Inicia Docker y vuelve a ejecutar este script${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Docker está disponible${NC}"
}

# Verificar estructura del proyecto React
verify_react_structure() {
    echo -e "${YELLOW}Verificando estructura del proyecto React...${NC}"
    
    cd Frontend
    
    # Verificar archivos esenciales
    if [ ! -f "package.json" ]; then
        echo -e "${RED}Error: package.json no encontrado en Frontend/${NC}"
        exit 1
    fi
    
    if [ ! -d "src" ]; then
        echo -e "${RED}Error: Directorio src/ no encontrado en Frontend/${NC}"
        exit 1
    fi
    
    if [ ! -f "src/index.js" ] && [ ! -f "src/index.tsx" ]; then
        echo -e "${RED}Error: src/index.js o src/index.tsx no encontrado${NC}"
        exit 1
    fi
    
    if [ ! -d "public" ]; then
        echo -e "${RED}Error: Directorio public/ no encontrado en Frontend/${NC}"
        exit 1
    fi
    
    if [ ! -f "public/index.html" ]; then
        echo -e "${RED}Error: public/index.html no encontrado${NC}"
        exit 1
    fi
    
    # Verificar archivos Docker
    if [ ! -f "Dockerfile" ]; then
        echo -e "${RED}Error: Dockerfile no encontrado en Frontend/${NC}"
        exit 1
    fi
    
    if [ ! -f "nginx.conf" ]; then
        echo -e "${RED}Error: nginx.conf no encontrado en Frontend/${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Estructura del proyecto React verificada${NC}"
    cd ..
}

# Configurar variables de entorno para Docker
configure_environment() {
    echo -e "${YELLOW}Configurando variables de entorno para Docker...${NC}"
    
    cd Frontend
    
    # Crear backup del .env original si existe
    if [ -f ".env" ] && [ ! -f ".env.backup" ]; then
        echo -e "${YELLOW}  → Creando backup de .env original...${NC}"
        cp .env .env.backup
    fi
    
    # Crear .env para el contenedor Docker
    echo -e "${YELLOW}  → Creando .env para Docker...${NC}"
    cat > .env << 'EOF'
# Configuración para Frontend en Docker (modo mixto)
# El frontend en Docker se comunica con APIs en Minikube

# URLs usando el proxy de nginx (definido en nginx.conf)
REACT_APP_API_URL=/api
REACT_APP_API_PYTHON_URL=/api-python  
REACT_APP_WEBSOCKET_URL=/websocket

# Puerto interno del contenedor (no cambiar)
PORT=80

# Configuración de build
GENERATE_SOURCEMAP=false
WDS_SOCKET_PORT=0
EOF
    
    echo -e "${GREEN}✓ Variables de entorno configuradas${NC}"
    cd ..
}

# Instalar dependencias de React
install_react_dependencies() {
    echo -e "${YELLOW}Instalando dependencias de React...${NC}"
    
    cd Frontend
    
    # Verificar si node_modules existe y está actualizado
    if [ ! -d "node_modules" ] || [ "package.json" -nt "node_modules" ]; then
        echo -e "${YELLOW}  → Instalando dependencias con npm...${NC}"
        
        # Limpiar caché si es necesario
        if [ -d "node_modules" ]; then
            echo -e "${YELLOW}  → Limpiando node_modules existente...${NC}"
            rm -rf node_modules package-lock.json
        fi
        
        # Instalar dependencias
        npm install
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}Error al instalar dependencias de React${NC}"
            exit 1
        fi
        
        echo -e "${GREEN}  ✓ Dependencias instaladas correctamente${NC}"
    else
        echo -e "${GREEN}  ✓ Dependencias ya están instaladas${NC}"
    fi
    
    cd ..
}

# Verificar y probar compilación de React
verify_react_build() {
    echo -e "${YELLOW}Verificando compilación de React...${NC}"
    
    cd Frontend
    
    # Verificar que las dependencias están instaladas
    if [ ! -d "node_modules" ]; then
        echo -e "${RED}Error: node_modules no encontrado. Ejecutando instalación...${NC}"
        install_react_dependencies
    fi
    
    # Probar compilación
    echo -e "${YELLOW}  → Probando compilación de React (npm run build)...${NC}"
    
    # Limpiar build anterior si existe
    if [ -d "build" ]; then
        echo -e "${YELLOW}  → Limpiando build anterior...${NC}"
        rm -rf build/
    fi
    
    # Ejecutar build
    npm run build
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error en la compilación de React${NC}"
        echo -e "${YELLOW}Revisa los errores anteriores y corrige el código React${NC}"
        exit 1
    fi
    
    # Verificar que el build se creó correctamente
    if [ ! -d "build" ]; then
        echo -e "${RED}Error: Directorio build/ no se creó${NC}"
        exit 1
    fi
    
    if [ ! -f "build/index.html" ]; then
        echo -e "${RED}Error: build/index.html no se generó${NC}"
        exit 1
    fi
    
    # Verificar tamaño del build
    BUILD_SIZE=$(du -sh build/ | cut -f1)
    echo -e "${GREEN}  ✓ Build de React generado correctamente (tamaño: $BUILD_SIZE)${NC}"
    
    # Verificar contenido del build
    echo -e "${YELLOW}  → Verificando contenido del build...${NC}"
    if ls build/static/js/*.js &> /dev/null; then
        JS_FILES=$(ls build/static/js/*.js | wc -l)
        echo -e "${GREEN}  ✓ Archivos JavaScript generados: $JS_FILES${NC}"
    fi
    
    if ls build/static/css/*.css &> /dev/null; then
        CSS_FILES=$(ls build/static/css/*.css | wc -l)
        echo -e "${GREEN}  ✓ Archivos CSS generados: $CSS_FILES${NC}"
    fi
    
    echo -e "${GREEN}✓ Compilación de React verificada exitosamente${NC}"
    cd ..
}

# Construir imagen Docker del Frontend
build_frontend_image() {
    echo -e "${YELLOW}Construyendo imagen Docker del Frontend...${NC}"
    
    cd Frontend
    
    # Verificar que el build existe
    if [ ! -d "build" ]; then
        echo -e "${RED}Error: Directorio build/ no encontrado${NC}"
        echo -e "${YELLOW}Ejecutando verificación de build primero...${NC}"
        verify_react_build
    fi
    
    # Mostrar información del build antes de dockerizar
    echo -e "${YELLOW}  → Información del build a dockerizar:${NC}"
    echo -e "${BLUE}    Build size: $(du -sh build/ | cut -f1)${NC}"
    echo -e "${BLUE}    Files count: $(find build/ -type f | wc -l)${NC}"
    
    # Construir imagen Docker
    echo -e "${YELLOW}  → Ejecutando: docker build -t bismarckr/frontend-fase2:latest .${NC}"
    docker build -t bismarckr/frontend-fase2:latest .
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Imagen Docker del Frontend construida exitosamente${NC}"
        
        # Mostrar información de la imagen
        IMAGE_SIZE=$(docker images bismarckr/frontend-fase2:latest --format "table {{.Size}}" | tail -1)
        echo -e "${BLUE}  Tamaño de la imagen Docker: $IMAGE_SIZE${NC}"
    else
        echo -e "${RED}Error al construir la imagen Docker del Frontend${NC}"
        exit 1
    fi
    
    cd ..
}

# Ejecutar contenedor del Frontend
run_frontend_container() {
    echo -e "${YELLOW}Ejecutando contenedor del Frontend...${NC}"
    
    # Detener contenedor anterior si existe
    echo -e "${YELLOW}Limpiando contenedores anteriores...${NC}"
    docker stop frontend-local 2>/dev/null || true
    docker rm frontend-local 2>/dev/null || true
    
    # Obtener IP de Minikube para conectar con las APIs
    MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "192.168.49.2")
    echo -e "${BLUE}IP de Minikube detectada: $MINIKUBE_IP${NC}"
    
    # Ejecutar contenedor con conexión a Minikube
    echo -e "${YELLOW}Iniciando contenedor del Frontend...${NC}"
    docker run -d \
        --name frontend-local \
        --restart unless-stopped \
        -p 3001:80 \
        --add-host=api-nodejs-service:$MINIKUBE_IP \
        --add-host=api-python-service:$MINIKUBE_IP \
        --add-host=websocket-api-service:$MINIKUBE_IP \
        bismarckr/frontend-fase2:latest
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Contenedor del Frontend iniciado correctamente${NC}"
        
        # Esperar un momento para que el contenedor se inicie
        sleep 3
        
        # Verificar que está corriendo
        if docker ps | grep -q "frontend-local"; then
            echo -e "${GREEN}✓ Frontend ejecutándose correctamente${NC}"
        else
            echo -e "${RED}Error: El contenedor no está ejecutándose${NC}"
            echo -e "${YELLOW}Logs del contenedor:${NC}"
            docker logs frontend-local
            exit 1
        fi
    else
        echo -e "${RED}Error al iniciar el contenedor del Frontend${NC}"
        exit 1
    fi
}

# Verificar estado y mostrar información
show_status() {
    echo -e "${YELLOW}=== ESTADO DEL FRONTEND ===${NC}"
    
    # Estado del contenedor
    echo -e "${BLUE}Contenedor Docker:${NC}"
    if docker ps | grep -q "frontend-local"; then
        echo -e "${GREEN}✓ Contenedor ejecutándose${NC}"
        docker ps --filter name=frontend-local --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    else
        echo -e "${RED}✗ Contenedor no está ejecutándose${NC}"
    fi
    
    # Verificar conectividad
    echo -e "${BLUE}Verificando conectividad:${NC}"
    sleep 2
    if curl -s --connect-timeout 5 http://localhost:3001/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Frontend accesible en http://localhost:3001${NC}"
    elif curl -s --connect-timeout 5 http://localhost:3001/ > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Frontend accesible en http://localhost:3001${NC}"
        echo -e "${YELLOW}  (endpoint /health no disponible, pero la app responde)${NC}"
    else
        echo -e "${YELLOW}⚠ Frontend puede estar iniciando, intenta acceder en unos momentos${NC}"
    fi
    
    # Información del build
    if [ -d "Frontend/build" ]; then
        BUILD_SIZE=$(du -sh Frontend/build/ | cut -f1)
        echo -e "${BLUE}Build React: ${GREEN}✓ Disponible (tamaño: $BUILD_SIZE)${NC}"
    else
        echo -e "${BLUE}Build React: ${RED}✗ No disponible${NC}"
    fi
    
    # Logs recientes
    echo -e "${BLUE}Logs recientes:${NC}"
    docker logs frontend-local --tail 5 2>/dev/null || echo -e "${RED}No hay logs disponibles${NC}"
}

# Función para mostrar información de uso
show_usage() {
    echo -e "${YELLOW}=== INFORMACIÓN DE USO ===${NC}"
    echo
    echo -e "${GREEN}Comandos disponibles:${NC}"
    echo -e "${BLUE}  ./setup-frontend-local.sh           ${NC}# Configuración e instalación completa"
    echo -e "${BLUE}  ./setup-frontend-local.sh start     ${NC}# Iniciar contenedor existente"
    echo -e "${BLUE}  ./setup-frontend-local.sh stop      ${NC}# Detener contenedor"
    echo -e "${BLUE}  ./setup-frontend-local.sh restart   ${NC}# Reiniciar contenedor"
    echo -e "${BLUE}  ./setup-frontend-local.sh status    ${NC}# Ver estado"
    echo -e "${BLUE}  ./setup-frontend-local.sh logs      ${NC}# Ver logs en tiempo real"
    echo -e "${BLUE}  ./setup-frontend-local.sh rebuild   ${NC}# Reconstruir imagen y reiniciar"
    echo
    echo -e "${GREEN}URLs de acceso:${NC}"
    echo -e "${BLUE}  Frontend: http://localhost:3001${NC}"
    echo -e "${BLUE}  Health check: http://localhost:3001/health${NC}"
    echo
    echo -e "${GREEN}Comandos útiles:${NC}"
    echo -e "${BLUE}  docker logs frontend-local          ${NC}# Ver logs"
    echo -e "${BLUE}  docker exec -it frontend-local sh   ${NC}# Acceder al contenedor"
    echo -e "${BLUE}  npm start (en Frontend/)            ${NC}# Desarrollo local"
    echo
    echo -e "${GREEN}Desarrollo local:${NC}"
    echo -e "${BLUE}  cd Frontend && npm start            ${NC}# Servidor desarrollo (puerto 3000)"
    echo -e "${BLUE}  cd Frontend && npm run build        ${NC}# Solo compilar"
    echo
}

# Función principal
main() {
    case "${1:-install}" in
        "install"|"")
            echo -e "${YELLOW}=== INSTALACIÓN COMPLETA DEL FRONTEND DOCKER ===${NC}"
            check_nodejs
            check_docker
            verify_react_structure
            configure_environment
            install_react_dependencies
            verify_react_build
            build_frontend_image
            run_frontend_container
            show_status
            show_usage
            ;;
        "start")
            echo -e "${YELLOW}Iniciando contenedor del Frontend...${NC}"
            docker start frontend-local
            sleep 2
            show_status
            ;;
        "stop")
            echo -e "${YELLOW}Deteniendo contenedor del Frontend...${NC}"
            docker stop frontend-local
            echo -e "${GREEN}✓ Frontend detenido${NC}"
            ;;
        "restart")
            echo -e "${YELLOW}Reiniciando contenedor del Frontend...${NC}"
            docker restart frontend-local
            sleep 3
            show_status
            ;;
        "status")
            show_status
            ;;
        "logs")
            echo -e "${YELLOW}Mostrando logs en tiempo real (Ctrl+C para salir)...${NC}"
            docker logs -f frontend-local
            ;;
        "rebuild")
            echo -e "${YELLOW}Reconstruyendo imagen y reiniciando...${NC}"
            docker stop frontend-local 2>/dev/null || true
            docker rm frontend-local 2>/dev/null || true
            docker rmi bismarckr/frontend-fase2:latest 2>/dev/null || true
            configure_environment
            verify_react_build
            build_frontend_image
            run_frontend_container
            show_status
            ;;
        "build-only")
            echo -e "${YELLOW}Solo construyendo la aplicación React...${NC}"
            check_nodejs
            verify_react_structure
            configure_environment
            install_react_dependencies
            verify_react_build
            echo -e "${GREEN}✓ Build de React completado${NC}"
            ;;
        *)
            echo -e "${RED}Comando no reconocido: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
}

echo
# Ejecutar función principal
main "$@"

echo
echo -e "${GREEN}🎉 Frontend Docker configurado!${NC}"