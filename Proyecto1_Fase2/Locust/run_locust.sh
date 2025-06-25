#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== PRUEBA ESPECIFICA: 300 USUARIOS POR 3 MINUTOS ===${NC}"

# Guardar directorio actual
LOCUST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$LOCUST_DIR")"
VENV_PATH="$PROJECT_DIR/venv"

echo -e "${GREEN}Directorio de Locust: $LOCUST_DIR${NC}"
echo -e "${GREEN}Directorio del proyecto: $PROJECT_DIR${NC}"

# Verificar que locustfile.py existe
if [ ! -f "$LOCUST_DIR/locustfile.py" ]; then
    echo -e "${RED}ERROR: locustfile.py no encontrado en $LOCUST_DIR${NC}"
    exit 1
fi

# Verificar o crear entorno virtual
if [ ! -d "$VENV_PATH" ]; then
    echo -e "${YELLOW}Creando entorno virtual de Python...${NC}"
    cd "$PROJECT_DIR"
    python3 -m venv venv
    source venv/bin/activate
    pip install locust requests faker
    echo -e "${GREEN}Entorno virtual creado${NC}"
else
    echo -e "${GREEN}Activando entorno virtual...${NC}"
    source "$VENV_PATH/bin/activate"
fi

# Verificar que Locust este disponible
if ! command -v locust &> /dev/null; then
    echo -e "${RED}Locust no esta instalado en el entorno virtual${NC}"
    echo -e "${YELLOW}Instalando Locust...${NC}"
    pip install locust requests faker
fi

# Verificar que el sistema este activo
echo -e "${GREEN}Verificando que la API este disponible...${NC}"
if ! curl -s http://localhost:3000/api/metrics/complete > /dev/null; then
    echo -e "${RED}API no disponible en http://localhost:3000${NC}"
    echo -e "${YELLOW}Asegurese de que el sistema este ejecutandose con ./run.sh${NC}"
    exit 1
fi

echo -e "${GREEN}Sistema verificado${NC}"

# Buscar stress.sh en ubicaciones posibles
STRESS_SCRIPT=""
if [ -f "$PROJECT_DIR/../stress.sh" ]; then
    STRESS_SCRIPT="$PROJECT_DIR/../stress.sh"
elif [ -f "$PROJECT_DIR/stress.sh" ]; then
    STRESS_SCRIPT="$PROJECT_DIR/stress.sh"
elif [ -f "$(dirname "$PROJECT_DIR")/stress.sh" ]; then
    STRESS_SCRIPT="$(dirname "$PROJECT_DIR")/stress.sh"
fi

# Iniciar contenedores de estres en background (si existe)
STRESS_PID=""
if [ -n "$STRESS_SCRIPT" ]; then
    echo -e "${YELLOW}Iniciando estres del sistema...${NC}"
    CURRENT_DIR=$(pwd)
    cd "$(dirname "$STRESS_SCRIPT")"
    ./stress.sh &
    STRESS_PID=$!
    cd "$CURRENT_DIR"
    echo -e "${GREEN}Estres iniciado (PID: $STRESS_PID)${NC}"
    
    sleep 5  # Dar tiempo a que el estres inicie
else
    echo -e "${YELLOW}ADVERTENCIA: stress.sh no encontrado. Continuando sin estres del sistema...${NC}"
fi

echo -e "${YELLOW}Iniciando Locust con configuracion especifica:${NC}"
echo -e "   - 300 usuarios maximo"
echo -e "   - 1 usuario nuevo por segundo"
echo -e "   - Duracion: 3 minutos"
echo -e "   - Peticiones cada 1-2 segundos"
echo -e ""

# Obtener registros iniciales en la base de datos
INITIAL_RECORDS=$(docker exec mysql-monitor mysql -u monitor -pmonitor123 monitoring -se "SELECT COUNT(*) FROM cpu_metrics" 2>/dev/null || echo "0")

# Cambiar al directorio de Locust
cd "$LOCUST_DIR"

# Verificar una vez más que locustfile.py existe
echo -e "${GREEN}Verificando locustfile.py en: $(pwd)${NC}"
ls -la locustfile.py

# Ejecutar Locust con parametros especificos del enunciado
python -m locust -f locustfile.py \
       --host=http://localhost:3000 \
       --users=300 \
       --spawn-rate=1 \
       --run-time=180 \
       --headless \
       --html=report_300_users.html \
       --csv=metrics_300_users

echo -e "\n${GREEN}Prueba completada${NC}"
echo -e "${YELLOW}Reportes generados:${NC}"
echo -e "   - report_300_users.html"
echo -e "   - metrics_300_users_stats.csv"
echo -e "   - metrics_300_users_failures.csv"

# Detener estres (si se inicio)
if [ -n "$STRESS_PID" ]; then
    kill $STRESS_PID 2>/dev/null
    echo -e "${GREEN}Estres del sistema detenido${NC}"
fi

# Mostrar estadisticas finales
echo -e "\n${YELLOW}Estadisticas finales:${NC}"
FINAL_RECORDS=$(docker exec mysql-monitor mysql -u monitor -pmonitor123 monitoring -se "SELECT COUNT(*) FROM cpu_metrics" 2>/dev/null || echo "0")
NEW_RECORDS=$((FINAL_RECORDS - INITIAL_RECORDS))

echo -e "   Registros iniciales: ${GREEN}$INITIAL_RECORDS${NC}"
echo -e "   Registros finales: ${GREEN}$FINAL_RECORDS${NC}"
echo -e "   Nuevos registros: ${GREEN}$NEW_RECORDS${NC}"

# Mostrar ubicacion de reportes
echo -e "\n${YELLOW}Ubicacion de reportes:${NC}"
echo -e "   $(pwd)/report_300_users.html"
echo -e "   $(pwd)/metrics_300_users_stats.csv"
echo -e "   $(pwd)/metrics_300_users_failures.csv"

echo -e "\n${GREEN}Prueba de carga completada exitosamente${NC}"