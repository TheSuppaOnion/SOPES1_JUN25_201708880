#!/bin/bash

# Script para eliminar todos los servicios utilizados
# Autor: Bismarck Romero - 201708880
# Fecha: Junio 2025 - SO1 Fase 2

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                            ║${NC}"
echo -e "${BLUE}║ ${RED}LIMPIEZA COMPLETA DEL SISTEMA - SO1 FASE 2${BLUE}               ║${NC}"
echo -e "${BLUE}║              ${YELLOW}Bismarck Romero - 201708880${BLUE}                  ║${NC}"
echo -e "${BLUE}║                                                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo

# Función para verificar qué componentes están activos
check_active_components() {
    echo -e "${YELLOW}=== DETECTANDO COMPONENTES ACTIVOS ===${NC}"
    
    COMPONENTS_FOUND=()
    
    # 1. Verificar Kubernetes/Minikube
    if command -v kubectl &> /dev/null && kubectl get namespace so1-fase2 &> /dev/null; then
        COMPONENTS_FOUND+=("Kubernetes: Namespace so1-fase2 con pods")
    fi
    
    if command -v minikube &> /dev/null && minikube status &> /dev/null; then
        COMPONENTS_FOUND+=("Minikube: Cluster ejecutándose")
    fi
    
    # 2. Verificar contenedores Docker
    if command -v docker &> /dev/null; then
        if docker ps -a | grep -q "frontend-local"; then
            COMPONENTS_FOUND+=("Docker: Contenedor frontend-local")
        fi
        
        if docker ps -a | grep -q "agente-vm-monitor"; then
            COMPONENTS_FOUND+=("Docker: Contenedor agente-vm-monitor")
        fi
        
        if docker ps -a | grep -q "agente-local"; then
            COMPONENTS_FOUND+=("Docker: Contenedor agente-local")
        fi
        
        # Verificar imágenes del proyecto
        if docker images | grep -q "bismarckr.*fase2"; then
            COMPONENTS_FOUND+=("Docker: Imágenes del proyecto bismarckr/*-fase2")
        fi
    fi
    
    # 3. Verificar MySQL
    if systemctl is-active --quiet mysql 2>/dev/null; then
        if mysql -u monitor -pmonitor123 -e "USE monitoring;" &> /dev/null; then
            COMPONENTS_FOUND+=("MySQL: Base de datos 'monitoring' con usuario 'monitor'")
        fi
    fi
    
    # 4. Verificar módulos del kernel
    if lsmod | grep -q "201708880"; then
        MODULES=$(lsmod | grep "201708880" | awk '{print $1}' | tr '\n' ', ' | sed 's/,$//')
        COMPONENTS_FOUND+=("Kernel: Módulos cargados ($MODULES)")
    fi
    
    # 5. Verificar procesos del agente nativo
    if pgrep -f "agente-de-monitor" > /dev/null; then
        COMPONENTS_FOUND+=("Procesos: Agente nativo ejecutándose")
    fi
    
    # 6. Verificar Locust
    if pgrep -f "locust" > /dev/null; then
        COMPONENTS_FOUND+=("Procesos: Locust ejecutándose")
    fi
    
    # 7. Verificar archivos temporales y logs
    if [ -d "Frontend/build" ]; then
        COMPONENTS_FOUND+=("Archivos: Build del Frontend React")
    fi
    
    if [ -f "Backend/Agente/agente" ]; then
        COMPONENTS_FOUND+=("Archivos: Binario del agente compilado")
    fi
    
    if ls Modulos/*.ko &> /dev/null; then
        COMPONENTS_FOUND+=("Archivos: Módulos del kernel compilados (.ko)")
    fi
    
    if [ -d "Locust/reports" ]; then
        COMPONENTS_FOUND+=("Archivos: Reportes de Locust")
    fi
    
    # Mostrar componentes encontrados
    if [ ${#COMPONENTS_FOUND[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ No se encontraron componentes activos del proyecto${NC}"
        echo -e "${YELLOW}El sistema ya está limpio.${NC}"
        exit 0
    else
        echo -e "${RED}Se encontraron ${#COMPONENTS_FOUND[@]} componentes activos:${NC}"
        for component in "${COMPONENTS_FOUND[@]}"; do
            echo -e "${YELLOW}  ✗ $component${NC}"
        done
    fi
}

# Función principal de limpieza
perform_cleanup() {
    echo -e "${YELLOW}=== INICIANDO LIMPIEZA COMPLETA ===${NC}"
    
    # 1. Detener y eliminar contenedores Docker
    echo -e "${BLUE}1. Limpiando contenedores Docker...${NC}"
    if command -v docker &> /dev/null; then
        # Detener contenedores del proyecto
        for container in frontend-local agente-vm-monitor agente-local agente-monitor; do
            if docker ps -a | grep -q "$container"; then
                echo -e "${YELLOW}  → Deteniendo y eliminando $container...${NC}"
                docker stop "$container" 2>/dev/null || true
                docker rm "$container" 2>/dev/null || true
            fi
        done
        
        # Eliminar imágenes del proyecto
        images=$(docker images | grep "bismarckr.*fase2" | awk '{print $3}')
        if [ -n "$images" ]; then
            echo -e "${YELLOW}  → Eliminando imágenes del proyecto...${NC}"
            docker rmi -f $images 2>/dev/null || true
        fi
        
        # Eliminar imágenes del agente
        agente_images=$(docker images | grep "agente" | grep "bismarckr\|local" | awk '{print $3}')
        if [ -n "$agente_images" ]; then
            echo -e "${YELLOW}  → Eliminando imágenes del agente...${NC}"
            docker rmi -f $agente_images 2>/dev/null || true
        fi
        
        echo -e "${GREEN}  ✓ Contenedores Docker limpiados${NC}"
    else
        echo -e "${YELLOW}  ℹ Docker no encontrado${NC}"
    fi
    
    # 2. Limpiar Kubernetes
    echo -e "${BLUE}2. Limpiando Kubernetes...${NC}"
    if command -v kubectl &> /dev/null; then
        if kubectl get namespace so1-fase2 &> /dev/null; then
            echo -e "${YELLOW}  → Eliminando namespace so1-fase2...${NC}"
            kubectl delete namespace so1-fase2 --timeout=60s 2>/dev/null || true
        fi
        echo -e "${GREEN}  ✓ Namespace Kubernetes eliminado${NC}"
    else
        echo -e "${YELLOW}  ℹ kubectl no encontrado${NC}"
    fi
    
    # 3. Detener Minikube
    echo -e "${BLUE}3. Deteniendo Minikube...${NC}"
    if command -v minikube &> /dev/null; then
        if minikube status &> /dev/null; then
            echo -e "${YELLOW}  → Deteniendo Minikube...${NC}"
            minikube stop
            echo -e "${GREEN}  ✓ Minikube detenido${NC}"
        else
            echo -e "${GREEN}  ✓ Minikube ya estaba detenido${NC}"
        fi
    else
        echo -e "${YELLOW}  ℹ Minikube no encontrado${NC}"
    fi
    
    # 4. Detener procesos nativos
    echo -e "${BLUE}4. Deteniendo procesos nativos...${NC}"
    
    # Detener agente nativo
    if pgrep -f "agente-de-monitor" > /dev/null; then
        echo -e "${YELLOW}  → Deteniendo agente nativo...${NC}"
        pkill -f "agente-de-monitor" 2>/dev/null || true
    fi
    
    # Detener Locust
    if pgrep -f "locust" > /dev/null; then
        echo -e "${YELLOW}  → Deteniendo Locust...${NC}"
        pkill -f "locust" 2>/dev/null || true
    fi
    
    echo -e "${GREEN}  ✓ Procesos nativos detenidos${NC}"
    
    # 5. Limpiar módulos del kernel
    echo -e "${BLUE}5. Descargando módulos del kernel...${NC}"
    modules_removed=0
    
    for module in cpu_201708880 ram_201708880 procesos_201708880; do
        if lsmod | grep -q "$module"; then
            echo -e "${YELLOW}  → Descargando módulo $module...${NC}"
            sudo rmmod "$module" 2>/dev/null || true
            ((modules_removed++))
        fi
    done
    
    if [ $modules_removed -eq 0 ]; then
        echo -e "${GREEN}  ✓ No había módulos cargados${NC}"
    else
        echo -e "${GREEN}  ✓ $modules_removed módulos descargados${NC}"
    fi
    
    # 6. Limpiar base de datos MySQL (opcional)
    echo -e "${BLUE}6. Limpiando base de datos MySQL...${NC}"
    read -p "¿Eliminar la base de datos 'monitoring' de MySQL? (s/N): " cleanup_mysql
    if [[ $cleanup_mysql =~ ^[Ss]$ ]]; then
        if command -v mysql &> /dev/null; then
            echo -e "${YELLOW}  → Eliminando base de datos monitoring...${NC}"
            mysql -u root -p -e "DROP DATABASE IF EXISTS monitoring;" 2>/dev/null || true
            echo -e "${YELLOW}  → Eliminando usuario monitor...${NC}"
            mysql -u root -p -e "DROP USER IF EXISTS 'monitor'@'%';" 2>/dev/null || true
            echo -e "${GREEN}  ✓ Base de datos MySQL limpiada${NC}"
        else
            echo -e "${YELLOW}  ℹ MySQL no encontrado${NC}"
        fi
    else
        echo -e "${YELLOW}  ℹ Base de datos MySQL conservada${NC}"
    fi
    
    # 7. Limpiar archivos temporales
    echo -e "${BLUE}7. Limpiando archivos temporales...${NC}"
    
    # Build del Frontend
    if [ -d "Frontend/build" ]; then
        echo -e "${YELLOW}  → Eliminando Frontend/build/...${NC}"
        rm -rf Frontend/build/
    fi
    
    # Binario del agente
    if [ -f "Backend/Agente/agente" ]; then
        echo -e "${YELLOW}  → Eliminando binario del agente...${NC}"
        rm -f Backend/Agente/agente
    fi
    
    # Módulos compilados
    if ls Modulos/*.ko &> /dev/null; then
        echo -e "${YELLOW}  → Eliminando módulos compilados (.ko)...${NC}"
        rm -f Modulos/*.ko
        rm -f Modulos/*.o Modulos/*.mod.c Modulos/.*.cmd 2>/dev/null || true
        rm -rf Modulos/.tmp_versions/ 2>/dev/null || true
    fi
    
    # Reportes de Locust
    if [ -d "Locust/reports" ]; then
        echo -e "${YELLOW}  → Eliminando reportes de Locust...${NC}"
        rm -rf Locust/reports/
    fi
    
    # Logs y archivos temporales
    rm -f *.log nohup.out 2>/dev/null || true
    
    echo -e "${GREEN}  ✓ Archivos temporales limpiados${NC}"
    
    # 8. Limpiar configuraciones temporales
    echo -e "${BLUE}8. Limpiando configuraciones temporales...${NC}"
    
    # Restaurar .env original del Frontend si existe backup
    if [ -f "Frontend/.env.backup" ]; then
        echo -e "${YELLOW}  → Restaurando Frontend/.env original...${NC}"
        mv Frontend/.env.backup Frontend/.env
    fi
    
    echo -e "${GREEN}  ✓ Configuraciones limpiadas${NC}"
}

# Función para mostrar resumen final
show_final_summary() {
    echo
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}║              ${YELLOW}LIMPIEZA COMPLETA FINALIZADA${GREEN}                 ║${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${GREEN}✅ Todos los componentes del proyecto han sido eliminados:${NC}"
    echo -e "${BLUE}   • Contenedores Docker detenidos y eliminados${NC}"
    echo -e "${BLUE}   • Imágenes Docker del proyecto eliminadas${NC}"
    echo -e "${BLUE}   • Namespace de Kubernetes eliminado${NC}"
    echo -e "${BLUE}   • Minikube detenido${NC}"
    echo -e "${BLUE}   • Módulos del kernel descargados${NC}"
    echo -e "${BLUE}   • Procesos nativos detenidos${NC}"
    echo -e "${BLUE}   • Archivos temporales eliminados${NC}"
    echo
    echo -e "${YELLOW}Para volver a desplegar el proyecto:${NC}"
    echo -e "${BLUE}   1. ./setup-mysql-local.sh${NC}"
    echo -e "${BLUE}   2. ./run-minikube.sh${NC}"
    echo -e "${BLUE}   3. ./setup-frontend-local.sh${NC}"
    echo -e "${BLUE}   4. Ejecutar agente (nativo o docker)${NC}"
    echo
}

# MAIN - Función principal
main() {
    # Verificar componentes activos
    check_active_components
    
    echo
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                     ⚠️  ADVERTENCIA  ⚠️                     ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${RED}Esta operación eliminará COMPLETAMENTE todos los componentes del proyecto:${NC}"
    echo
    echo -e "${YELLOW}🗑️  Componentes que serán eliminados:${NC}"
    echo -e "${BLUE}   • Namespace Kubernetes (so1-fase2) con todos sus pods${NC}"
    echo -e "${BLUE}   • Contenedores Docker (frontend-local, agente-*)${NC}"
    echo -e "${BLUE}   • Imágenes Docker del proyecto (bismarckr/*-fase2)${NC}"
    echo -e "${BLUE}   • Minikube cluster (será detenido)${NC}"
    echo -e "${BLUE}   • Módulos del kernel (cpu/ram/procesos_201708880)${NC}"
    echo -e "${BLUE}   • Procesos nativos (agente, locust)${NC}"
    echo -e "${BLUE}   • Archivos compilados y temporales${NC}"
    echo -e "${BLUE}   • Configuraciones temporales${NC}"
    echo
    echo -e "${YELLOW}📋 Se preguntará opcionalmente por:${NC}"
    echo -e "${BLUE}   • Base de datos MySQL 'monitoring'${NC}"
    echo
    echo -e "${RED}⚠️  Esta acción NO se puede deshacer ⚠️${NC}"
    echo
    
    # Confirmación principal
    read -p "¿Estás completamente seguro de continuar con la limpieza? (escriba 'CONFIRMAR'): " confirmacion
    
    if [[ "$confirmacion" != "CONFIRMAR" ]]; then
        echo
        echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║                   OPERACIÓN CANCELADA                     ║${NC}"
        echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
        echo -e "${YELLOW}No se realizaron cambios en el sistema.${NC}"
        exit 0
    fi
    
    # Confirmación final
    echo
    read -p "Última confirmación - ¿Proceder con la eliminación? (s/N): " final_confirmation
    
    if [[ ! $final_confirmation =~ ^[Ss]$ ]]; then
        echo -e "${YELLOW}Operación cancelada por el usuario.${NC}"
        exit 0
    fi
    
    echo
    echo -e "${YELLOW}⏳ Iniciando limpieza completa en 3 segundos...${NC}"
    sleep 1
    echo -e "${YELLOW}⏳ 2...${NC}"
    sleep 1  
    echo -e "${YELLOW}⏳ 1...${NC}"
    sleep 1
    echo
    
    # Ejecutar limpieza
    perform_cleanup
    
    # Mostrar resumen final
    show_final_summary
}

# Verificar permisos
if [ "$EUID" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Ejecutándose como root. Algunos comandos pueden requerir permisos de usuario.${NC}"
fi

# Ejecutar función principal
main "$@"