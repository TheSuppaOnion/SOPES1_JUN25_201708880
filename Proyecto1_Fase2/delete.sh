#!/bin/bash

# Script para eliminar todos los servicios de Fase 2
# Autor: Bismarck Romero - 201708880
# Fecha: Junio 2025

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║               LIMPIEZA COMPLETA - FASE 2                  ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"

# Función para verificar si un comando existe
command_exists() {
    command -v "$1" &> /dev/null
}

# Función para limpiar MySQL de manera más eficiente
cleanup_mysql() {
    echo -e "${YELLOW}6. Limpiando base de datos MySQL...${NC}"
    
    if ! command_exists mysql; then
        echo -e "${BLUE}  → MySQL no está instalado, saltando...${NC}"
        return
    fi
    
    if ! sudo systemctl is-active --quiet mysql; then
        echo -e "${YELLOW}  → MySQL no está ejecutándose${NC}"
        read -p "$(echo -e ${BLUE}¿Quieres intentar iniciarlo para limpiar? (s/N): ${NC})" start_mysql
        
        if [[ $start_mysql =~ ^[SsYy]$ ]]; then
            sudo systemctl start mysql
            sleep 3
        else
            echo -e "${BLUE}  → Saltando limpieza de MySQL${NC}"
            return
        fi
    fi
    
    read -p "$(echo -e ${YELLOW}¿Eliminar la base de datos 'monitoring' de MySQL? (s/N): ${NC})" delete_db
    
    if [[ $delete_db =~ ^[SsYy]$ ]]; then
        echo -e "${YELLOW}  → Intentando métodos de autenticación...${NC}"
        
        # Método 1: Sin contraseña (más común en instalaciones locales)
        echo -e "${BLUE}    Método 1: Acceso directo como root...${NC}"
        if mysql -u root -e "SELECT 1;" &>/dev/null; then
            echo -e "${GREEN}    ✓ Acceso directo exitoso${NC}"
            mysql -u root <<EOF
DROP DATABASE IF EXISTS monitoring;
DROP USER IF EXISTS 'monitor'@'localhost';
DROP USER IF EXISTS 'monitor'@'%';
FLUSH PRIVILEGES;
SELECT 'Base de datos y usuario eliminados correctamente' AS status;
EOF
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}  ✓ Base de datos MySQL limpiada (método directo)${NC}"
                return
            fi
        fi
        
        # Método 2: Con sudo
        echo -e "${BLUE}    Método 2: Acceso con sudo...${NC}"
        if sudo mysql -u root -e "SELECT 1;" &>/dev/null; then
            echo -e "${GREEN}    ✓ Acceso con sudo exitoso${NC}"
            sudo mysql -u root <<EOF
DROP DATABASE IF EXISTS monitoring;
DROP USER IF EXISTS 'monitor'@'localhost';
DROP USER IF EXISTS 'monitor'@'%';
FLUSH PRIVILEGES;
SELECT 'Base de datos y usuario eliminados correctamente' AS status;
EOF
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}  ✓ Base de datos MySQL limpiada (método sudo)${NC}"
                return
            fi
        fi
        
        # Método 3: Como usuario monitor (si existe)
        echo -e "${BLUE}    Método 3: Usando usuario monitor...${NC}"
        if mysql -u monitor -pmonitor123 -e "SELECT 1;" &>/dev/null; then
            echo -e "${GREEN}    ✓ Usuario monitor accesible${NC}"
            mysql -u monitor -pmonitor123 -e "DROP DATABASE IF EXISTS monitoring;" &>/dev/null
            
            # Para eliminar el usuario necesitamos root
            if mysql -u root -e "DROP USER IF EXISTS 'monitor'@'localhost'; DROP USER IF EXISTS 'monitor'@'%'; FLUSH PRIVILEGES;" &>/dev/null; then
                echo -e "${GREEN}  ✓ Base de datos eliminada y usuario limpiado${NC}"
                return
            elif sudo mysql -u root -e "DROP USER IF EXISTS 'monitor'@'localhost'; DROP USER IF EXISTS 'monitor'@'%'; FLUSH PRIVILEGES;" &>/dev/null; then
                echo -e "${GREEN}  ✓ Base de datos eliminada y usuario limpiado (con sudo)${NC}"
                return
            else
                echo -e "${YELLOW}  ⚠ Base de datos eliminada, pero no se pudo limpiar usuario${NC}"
                return
            fi
        fi
        
        # Método 4: Solicitar contraseña manualmente
        echo -e "${BLUE}    Método 4: Contraseña manual...${NC}"
        echo -e "${YELLOW}    Ingresa la contraseña de root de MySQL:${NC}"
        read -s mysql_root_password
        
        if mysql -u root -p"$mysql_root_password" -e "SELECT 1;" &>/dev/null; then
            echo -e "${GREEN}    ✓ Contraseña correcta${NC}"
            mysql -u root -p"$mysql_root_password" <<EOF
DROP DATABASE IF EXISTS monitoring;
DROP USER IF EXISTS 'monitor'@'localhost';
DROP USER IF EXISTS 'monitor'@'%';
FLUSH PRIVILEGES;
SELECT 'Base de datos y usuario eliminados correctamente' AS status;
EOF
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}  ✓ Base de datos MySQL limpiada (método contraseña)${NC}"
                return
            fi
        else
            echo -e "${RED}    ✗ Contraseña incorrecta${NC}"
        fi
        
        echo -e "${RED}  ✗ No se pudo acceder a MySQL para limpiar${NC}"
        echo -e "${YELLOW}  → Para limpiar manualmente:${NC}"
        echo -e "${BLUE}    mysql -u root -p${NC}"
        echo -e "${BLUE}    DROP DATABASE IF EXISTS monitoring;${NC}"
        echo -e "${BLUE}    DROP USER IF EXISTS 'monitor'@'localhost';${NC}"
        echo -e "${BLUE}    DROP USER IF EXISTS 'monitor'@'%';${NC}"
        echo -e "${BLUE}    FLUSH PRIVILEGES;${NC}"
    else
        echo -e "${BLUE}  → Saltando limpieza de base de datos${NC}"
    fi
}

# Función para verificar limpieza
verify_cleanup() {
    echo -e "${YELLOW}9. Verificando limpieza...${NC}"
    
    # Verificar Docker
    if command_exists docker; then
        PROJECT_CONTAINERS=$(docker ps -a --filter "name=fase2" --format "{{.Names}}" 2>/dev/null | wc -l)
        PROJECT_IMAGES=$(docker images | grep -E "(fase2|bismarckr.*fase2)" | wc -l)
        
        echo -e "${BLUE}  → Contenedores del proyecto: $PROJECT_CONTAINERS${NC}"
        echo -e "${BLUE}  → Imágenes del proyecto: $PROJECT_IMAGES${NC}"
    fi
    
    # Verificar Kubernetes
    if command_exists kubectl; then
        NAMESPACES=$(kubectl get namespaces | grep -E "(so1-fase2|monitoring)" | wc -l)
        echo -e "${BLUE}  → Namespaces del proyecto: $NAMESPACES${NC}"
    fi
    
    # Verificar Minikube
    if command_exists minikube; then
        MINIKUBE_STATUS=$(minikube status 2>/dev/null | grep -E "(Running|Stopped)" | head -1 | awk '{print $2}' || echo "No disponible")
        echo -e "${BLUE}  → Estado de Minikube: $MINIKUBE_STATUS${NC}"
    fi
    
    # Verificar MySQL
    if command_exists mysql; then
        if mysql -u monitor -pmonitor123 -e "USE monitoring; SELECT 1;" &>/dev/null; then
            echo -e "${RED}  ⚠ Base de datos 'monitoring' aún existe${NC}"
        elif mysql -u root -e "USE monitoring; SELECT 1;" &>/dev/null; then
            echo -e "${RED}  ⚠ Base de datos 'monitoring' aún existe${NC}"
        elif sudo mysql -u root -e "USE monitoring; SELECT 1;" &>/dev/null; then
            echo -e "${RED}  ⚠ Base de datos 'monitoring' aún existe${NC}"
        else
            echo -e "${GREEN}  ✓ Base de datos 'monitoring' eliminada${NC}"
        fi
    fi
    
    # Verificar archivos temporales
    TEMP_FILES=0
    if [ -d "/tmp" ]; then
        TEMP_FILES=$(find /tmp -name "*fase2*" -o -name "*monitor*" -o -name "*locust*" 2>/dev/null | wc -l)
    fi
    echo -e "${BLUE}  → Archivos temporales del proyecto: $TEMP_FILES${NC}"
}

# INICIO DE LIMPIEZA

echo -e "${BLUE}Iniciando limpieza completa del proyecto Fase 2...${NC}"
echo

# 1. Limpiar Docker Compose
echo -e "${YELLOW}1. Limpiando Docker Compose...${NC}"
if [ -f "docker-compose.yml" ]; then
    echo -e "${YELLOW}  → Deteniendo servicios de Docker Compose...${NC}"
    docker-compose down -v --remove-orphans &>/dev/null
    echo -e "${GREEN}  ✓ Docker Compose limpiado${NC}"
else
    echo -e "${BLUE}  → No hay docker-compose.yml${NC}"
fi

# 2. Limpiar contenedores Docker
echo -e "${YELLOW}2. Limpiando contenedores Docker...${NC}"
if command_exists docker; then
    # Detener contenedores del proyecto
    CONTAINERS=$(docker ps -a --filter "name=fase2" --format "{{.ID}}" 2>/dev/null)
    if [ -n "$CONTAINERS" ]; then
        echo -e "${YELLOW}  → Deteniendo y eliminando contenedores...${NC}"
        echo "$CONTAINERS" | xargs docker rm -f &>/dev/null
        echo -e "${GREEN}  ✓ Contenedores eliminados${NC}"
    else
        echo -e "${BLUE}  → No hay contenedores del proyecto${NC}"
    fi
    
    # Eliminar imágenes del proyecto
    read -p "$(echo -e ${YELLOW}¿Eliminar imágenes Docker del proyecto? (s/N): ${NC})" delete_images
    if [[ $delete_images =~ ^[SsYy]$ ]]; then
        IMAGES=$(docker images | grep -E "(fase2|bismarckr.*fase2)" | awk '{print $3}' 2>/dev/null)
        if [ -n "$IMAGES" ]; then
            echo -e "${YELLOW}  → Eliminando imágenes...${NC}"
            echo "$IMAGES" | xargs docker rmi -f &>/dev/null
            echo -e "${GREEN}  ✓ Imágenes eliminadas${NC}"
        else
            echo -e "${BLUE}  → No hay imágenes del proyecto${NC}"
        fi
    fi
    
    # Limpiar volúmenes
    echo -e "${YELLOW}  → Limpiando volúmenes...${NC}"
    docker volume prune -f &>/dev/null
    echo -e "${GREEN}  ✓ Volúmenes limpiados${NC}"
else
    echo -e "${BLUE}  → Docker no está instalado${NC}"
fi

# 3. Limpiar Kubernetes
echo -e "${YELLOW}3. Limpiando Kubernetes...${NC}"
if command_exists kubectl; then
    # Eliminar namespace del proyecto
    NAMESPACES=("so1-fase2" "monitoring" "proyecto-fase2")
    for ns in "${NAMESPACES[@]}"; do
        if kubectl get namespace "$ns" &>/dev/null; then
            echo -e "${YELLOW}  → Eliminando namespace $ns...${NC}"
            kubectl delete namespace "$ns" --grace-period=0 --force &>/dev/null
            echo -e "${GREEN}  ✓ Namespace $ns eliminado${NC}"
        fi
    done
    
    # Limpiar recursos huérfanos
    echo -e "${YELLOW}  → Limpiando recursos huérfanos...${NC}"
    kubectl delete pods --all-namespaces --field-selector=status.phase=Failed &>/dev/null || true
    echo -e "${GREEN}  ✓ Recursos huérfanos limpiados${NC}"
else
    echo -e "${BLUE}  → kubectl no está instalado${NC}"
fi

# 4. Limpiar Minikube
echo -e "${YELLOW}4. Limpiando Minikube...${NC}"
if command_exists minikube; then
    echo -e "${YELLOW}  → Deteniendo Minikube...${NC}"
    minikube stop &>/dev/null
    
    read -p "$(echo -e ${YELLOW}¿Eliminar completamente el cluster de Minikube? (s/N): ${NC})" delete_minikube
    if [[ $delete_minikube =~ ^[SsYy]$ ]]; then
        echo -e "${YELLOW}  → Eliminando cluster de Minikube...${NC}"
        minikube delete &>/dev/null
        echo -e "${GREEN}  ✓ Minikube eliminado completamente${NC}"
    else
        echo -e "${GREEN}  ✓ Minikube detenido${NC}"
    fi
else
    echo -e "${BLUE}  → Minikube no está instalado${NC}"
fi

# 5. Detener procesos nativos
echo -e "${YELLOW}5. Deteniendo procesos nativos...${NC}"
PROCESSES=("locust" "python.*app.py" "node.*index.js" "python.*agente.py")

for process in "${PROCESSES[@]}"; do
    PIDS=$(pgrep -f "$process" 2>/dev/null || true)
    if [ -n "$PIDS" ]; then
        echo -e "${YELLOW}  → Deteniendo proceso: $process${NC}"
        echo "$PIDS" | xargs kill -9 &>/dev/null || true
    fi
done

echo -e "${GREEN}  ✓ Procesos nativos detenidos${NC}"

# 6. Limpiar MySQL (función mejorada)
cleanup_mysql

# 7. Limpiar archivos temporales
echo -e "${YELLOW}7. Limpiando archivos temporales...${NC}"
TEMP_PATTERNS=("/tmp/*fase2*" "/tmp/*monitor*" "/tmp/*locust*" "/tmp/docker_build_*")

for pattern in "${TEMP_PATTERNS[@]}"; do
    find ${pattern%/*} -name "${pattern##*/}" -type f -exec rm -f {} \; 2>/dev/null || true
done

echo -e "${GREEN}  ✓ Archivos temporales limpiados${NC}"

# 8. Limpiar configuraciones temporales
echo -e "${YELLOW}8. Limpiando configuraciones temporales...${NC}"

# Limpiar archivos .env.backup
find . -name ".env.backup" -type f -exec rm -f {} \; 2>/dev/null || true

# Limpiar logs locales
find . -name "*.log" -path "*/logs/*" -exec rm -f {} \; 2>/dev/null || true

# Limpiar archivos de build temporales
find . -name "build" -type d -path "*/Frontend/*" -exec rm -rf {} \; 2>/dev/null || true
find . -name "node_modules" -path "*/Frontend/*" -exec rm -rf {} \; 2>/dev/null || true

echo -e "${GREEN}  ✓ Configuraciones limpiadas${NC}"

# Verificar limpieza
verify_cleanup

echo
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}║              LIMPIEZA COMPLETA FINALIZADA                 ║${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"

echo
echo -e "${GREEN}✅ Todos los componentes del proyecto Fase 2 han sido procesados:${NC}"
echo -e "${BLUE}   • Contenedores Docker detenidos y eliminados${NC}"
echo -e "${BLUE}   • Imágenes Docker del proyecto eliminadas (si se seleccionó)${NC}"
echo -e "${BLUE}   • Namespaces de Kubernetes eliminados${NC}"
echo -e "${BLUE}   • Minikube detenido/eliminado${NC}"
echo -e "${BLUE}   • Procesos nativos detenidos${NC}"
echo -e "${BLUE}   • Base de datos MySQL limpiada (si fue posible)${NC}"
echo -e "${BLUE}   • Archivos temporales eliminados${NC}"
echo

echo -e "${YELLOW}📋 Para verificar manualmente:${NC}"
echo -e "${BLUE}   docker ps -a | grep fase2${NC}"
echo -e "${BLUE}   kubectl get namespaces${NC}"
echo -e "${BLUE}   minikube status${NC}"
echo -e "${BLUE}   mysql -u root -e 'SHOW DATABASES;'${NC}"

echo
echo -e "${GREEN}¡Limpieza completada! El sistema está listo para una nueva instalación.${NC}"