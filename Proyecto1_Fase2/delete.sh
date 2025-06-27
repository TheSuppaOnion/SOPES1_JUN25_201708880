#!/bin/bash

# Script SIMPLE para eliminar TODO de Fase 2
# Autor: Bismarck Romero - 201708880

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║             ELIMINANDO TODO - FASE 2                      ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"

echo -e "${YELLOW}⚠️  ESTE SCRIPT ELIMINARÁ TODO:${NC}"
echo -e "${BLUE}   • Todos los contenedores Docker${NC}"
echo -e "${BLUE}   • Todas las imágenes Docker${NC}"
echo -e "${BLUE}   • Todo Minikube${NC}"
echo -e "${BLUE}   • Toda la base de datos MySQL${NC}"
echo -e "${BLUE}   • Todos los procesos relacionados${NC}"

echo
read -p "$(echo -e ${RED}¿ESTÁS SEGURO? Esto eliminará TODO (s/N): ${NC})" confirm

if [[ ! $confirm =~ ^[SsYy]$ ]]; then
    echo -e "${BLUE}Operación cancelada${NC}"
    exit 0
fi

echo
echo -e "${YELLOW}🚀 Iniciando eliminación total...${NC}"

# 1. ELIMINAR TODOS LOS CONTENEDORES DOCKER
echo -e "${YELLOW}1. Eliminando TODOS los contenedores Docker...${NC}"
if command -v docker >/dev/null 2>&1; then
    # Detener todos los contenedores
    CONTAINERS=$(docker ps -aq 2>/dev/null)
    if [ -n "$CONTAINERS" ]; then
        echo -e "${BLUE}   → Deteniendo todos los contenedores...${NC}"
        docker stop $CONTAINERS >/dev/null 2>&1 || true
        echo -e "${BLUE}   → Eliminando todos los contenedores...${NC}"
        docker rm -f $CONTAINERS >/dev/null 2>&1 || true
        echo -e "${GREEN}   ✓ Contenedores eliminados${NC}"
    else
        echo -e "${BLUE}   → No hay contenedores${NC}"
    fi
    
    # Eliminar todas las imágenes
    IMAGES=$(docker images -aq 2>/dev/null)
    if [ -n "$IMAGES" ]; then
        echo -e "${BLUE}   → Eliminando todas las imágenes...${NC}"
        docker rmi -f $IMAGES >/dev/null 2>&1 || true
        echo -e "${GREEN}   ✓ Imágenes eliminadas${NC}"
    else
        echo -e "${BLUE}   → No hay imágenes${NC}"
    fi
    
    # Limpiar todo Docker
    echo -e "${BLUE}   → Limpieza completa de Docker...${NC}"
    docker system prune -af --volumes >/dev/null 2>&1 || true
    echo -e "${GREEN}   ✓ Docker completamente limpio${NC}"
else
    echo -e "${BLUE}   → Docker no instalado${NC}"
fi

# 2. ELIMINAR MINIKUBE COMPLETAMENTE
echo -e "${YELLOW}2. Eliminando Minikube completamente...${NC}"
if command -v minikube >/dev/null 2>&1; then
    echo -e "${BLUE}   → Deteniendo Minikube...${NC}"
    minikube stop >/dev/null 2>&1 || true
    echo -e "${BLUE}   → Eliminando cluster de Minikube...${NC}"
    minikube delete >/dev/null 2>&1 || true
    echo -e "${GREEN}   ✓ Minikube eliminado${NC}"
else
    echo -e "${BLUE}   → Minikube no instalado${NC}"
fi

# 3. ELIMINAR KUBERNETES
echo -e "${YELLOW}3. Eliminando recursos de Kubernetes...${NC}"
if command -v kubectl >/dev/null 2>&1; then
    echo -e "${BLUE}   → Eliminando todos los namespaces del proyecto...${NC}"
    kubectl delete namespace so1-fase2 >/dev/null 2>&1 || true
    kubectl delete namespace monitoring >/dev/null 2>&1 || true
    kubectl delete namespace proyecto-fase2 >/dev/null 2>&1 || true
    echo -e "${GREEN}   ✓ Namespaces eliminados${NC}"
else
    echo -e "${BLUE}   → kubectl no instalado${NC}"
fi

# 4. ELIMINAR TODOS LOS PROCESOS RELACIONADOS
echo -e "${YELLOW}4. Eliminando todos los procesos relacionados...${NC}"
echo -e "${BLUE}   → Matando procesos de Python, Node, Locust...${NC}"
pkill -f "python.*app.py" >/dev/null 2>&1 || true
pkill -f "node.*index.js" >/dev/null 2>&1 || true
pkill -f "locust" >/dev/null 2>&1 || true
pkill -f "npm.*start" >/dev/null 2>&1 || true
pkill -f "serve" >/dev/null 2>&1 || true
pkill -f "agente.py" >/dev/null 2>&1 || true
echo -e "${GREEN}   ✓ Procesos eliminados${NC}"

# 5. RESETEAR MYSQL COMPLETAMENTE
echo -e "${YELLOW}5. Reseteando MySQL completamente...${NC}"
if command -v mysql >/dev/null 2>&1; then
    echo -e "${BLUE}   → Deteniendo MySQL...${NC}"
    sudo systemctl stop mysql >/dev/null 2>&1 || true
    
    echo -e "${BLUE}   → Eliminando MySQL completamente...${NC}"
    sudo apt-get purge -y mysql-server mysql-client mysql-common mysql-server-core-* mysql-client-core-* >/dev/null 2>&1 || true
    sudo rm -rf /etc/mysql /var/lib/mysql >/dev/null 2>&1 || true
    sudo apt-get autoremove -y >/dev/null 2>&1 || true
    sudo apt-get autoclean >/dev/null 2>&1 || true
    
    echo -e "${BLUE}   → Reinstalando MySQL limpio...${NC}"
    sudo apt-get update >/dev/null 2>&1 || true
    sudo apt-get install -y mysql-server >/dev/null 2>&1 || true
    
    echo -e "${BLUE}   → Iniciando MySQL...${NC}"
    sudo systemctl start mysql >/dev/null 2>&1 || true
    sudo systemctl enable mysql >/dev/null 2>&1 || true
    
    # Verificar que está limpio
    echo -e "${BLUE}   → Verificando que MySQL está limpio...${NC}"
    if sudo mysql -u root -e "SHOW DATABASES;" >/dev/null 2>&1; then
        echo -e "${GREEN}   ✓ MySQL reseteado y limpio${NC}"
    else
        echo -e "${YELLOW}   ⚠ MySQL instalado pero puede necesitar configuración${NC}"
    fi
else
    echo -e "${BLUE}   → MySQL no estaba instalado${NC}"
fi

# 6. LIMPIAR ARCHIVOS TEMPORALES
echo -e "${YELLOW}6. Limpiando archivos temporales...${NC}"
echo -e "${BLUE}   → Eliminando archivos temporales del proyecto...${NC}"
find /tmp -name "*fase2*" -delete >/dev/null 2>&1 || true
find /tmp -name "*monitor*" -delete >/dev/null 2>&1 || true
find /tmp -name "*locust*" -delete >/dev/null 2>&1 || true
find /tmp -name "*bismarckr*" -delete >/dev/null 2>&1 || true

# Limpiar archivos de proyecto
find . -name ".env.backup" -delete >/dev/null 2>&1 || true
find . -name "*.log" -delete >/dev/null 2>&1 || true
find . -path "*/Frontend/build" -exec rm -rf {} + >/dev/null 2>&1 || true
find . -path "*/Frontend/node_modules" -exec rm -rf {} + >/dev/null 2>&1 || true
find . -name "__pycache__" -exec rm -rf {} + >/dev/null 2>&1 || true
find . -name "*.pyc" -delete >/dev/null 2>&1 || true

echo -e "${GREEN}   ✓ Archivos temporales eliminados${NC}"

# 7. VERIFICACIÓN FINAL
echo -e "${YELLOW}7. Verificación final...${NC}"

# Verificar Docker
if command -v docker >/dev/null 2>&1; then
    CONTAINERS=$(docker ps -aq 2>/dev/null | wc -l)
    IMAGES=$(docker images -q 2>/dev/null | wc -l)
    echo -e "${BLUE}   → Contenedores restantes: $CONTAINERS${NC}"
    echo -e "${BLUE}   → Imágenes restantes: $IMAGES${NC}"
fi

# Verificar Minikube
if command -v minikube >/dev/null 2>&1; then
    STATUS=$(minikube status 2>/dev/null | grep -c "Running" || echo "0")
    echo -e "${BLUE}   → Minikube ejecutándose: $STATUS servicios${NC}"
fi

# Verificar MySQL
if command -v mysql >/dev/null 2>&1; then
    if sudo mysql -u root -e "SHOW DATABASES;" >/dev/null 2>&1; then
        DBS=$(sudo mysql -u root -e "SHOW DATABASES;" 2>/dev/null | grep -v -E "(Database|information_schema|performance_schema|mysql|sys)" | wc -l)
        echo -e "${BLUE}   → Bases de datos personalizadas: $DBS${NC}"
    else
        echo -e "${BLUE}   → MySQL: No accesible${NC}"
    fi
fi

echo
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    LIMPIEZA COMPLETA                      ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"

echo
echo -e "${GREEN}🎉 ¡SISTEMA COMPLETAMENTE LIMPIO!${NC}"
echo
echo -e "${YELLOW}📋 Lo que se eliminó:${NC}"
echo -e "${GREEN}   ✓ Todos los contenedores Docker${NC}"
echo -e "${GREEN}   ✓ Todas las imágenes Docker${NC}"
echo -e "${GREEN}   ✓ Todo el cluster de Minikube${NC}"
echo -e "${GREEN}   ✓ Toda la base de datos MySQL (reinstalada limpia)${NC}"
echo -e "${GREEN}   ✓ Todos los procesos relacionados${NC}"
echo -e "${GREEN}   ✓ Todos los archivos temporales${NC}"

echo
echo -e "${BLUE}💡 El sistema está listo para una instalación completamente nueva${NC}"
echo -e "${YELLOW}   Próximo paso: ./setup-mysql-local.sh${NC}"

echo
echo -e "${BLUE}Presiona Enter para salir...${NC}"
read