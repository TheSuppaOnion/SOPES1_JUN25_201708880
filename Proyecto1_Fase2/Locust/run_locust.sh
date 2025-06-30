#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SKIP_FASE1=0

# Revisar argumentos
for arg in "$@"; do
    if [ "$arg" == "--skip-fase1" ]; then
        SKIP_FASE1=1
    fi
done

echo -e "${YELLOW}=== PRUEBA LOCUST: GENERAR Y ENVIAR JSON AL INGRESS ===${NC}"

LOCUST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$LOCUST_DIR")"
VENV_PATH="$PROJECT_DIR/venv"

# Verificar que locustfile.py existe
if [ ! -f "$LOCUST_DIR/locustfile.py" ]; then
    echo -e "${RED}ERROR: locustfile.py no encontrado en $LOCUST_DIR${NC}"
    exit 1
fi

# Verificar que locustfile_send.py existe
if [ ! -f "$LOCUST_DIR/locustfile_send.py" ]; then
    echo -e "${RED}ERROR: locustfile_send.py no encontrado en $LOCUST_DIR${NC}"
    exit 1
fi

# Verificar o crear entorno virtual
if [ ! -d "$VENV_PATH" ]; then
    echo -e "${YELLOW}Creando entorno virtual de Python...${NC}"
    cd "$PROJECT_DIR"
    python3 -m venv venv
    source venv/bin/activate
    pip install locust requests
    echo -e "${GREEN}Entorno virtual creado${NC}"
else
    echo -e "${GREEN}Activando entorno virtual...${NC}"
    source "$VENV_PATH/bin/activate"
fi

# Verificar que Locust esté disponible
if ! command -v locust &> /dev/null; then
    echo -e "${RED}Locust no está instalado en el entorno virtual${NC}"
    echo -e "${YELLOW}Instalando Locust...${NC}"
    pip install locust requests
fi

cd "$LOCUST_DIR"

if [ "$SKIP_FASE1" -eq 0 ]; then
    echo -e "${YELLOW}Fase 1: Recolectando métricas...${NC}"
    python -m locust -f locustfile.py \
        --users=300 \
        --spawn-rate=1 \
        --run-time=180 \
        --headless

    echo -e "${GREEN}Fase 1 completada. Archivo metrics_collected.json generado.${NC}"
else
    echo -e "${YELLOW}Saltando Fase 1 (recolección de métricas) por argumento --skip-fase1${NC}"
fi

echo -e "${YELLOW}Fase 2: Enviando métricas una por una al Ingress...${NC}"
python -m locust -f locustfile_send.py \
    --users=150 \
    --spawn-rate=1 \
    --run-time=120 \
    --headless

echo -e "${GREEN}Fase 2 completada.${NC}"
echo -e "${GREEN}Script completado.${NC}"