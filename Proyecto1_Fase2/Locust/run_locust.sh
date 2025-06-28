#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=== PRUEBA LOCUST: GENERAR Y ENVIAR JSON AL INGRESS ===${NC}"

LOCUST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$LOCUST_DIR")"
VENV_PATH="$PROJECT_DIR/venv"

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

echo -e "${YELLOW}Ejecutando Locust para recolectar métricas...${NC}"

python -m locust -f locustfile.py \
    --host=http://localhost:3000 \
    --users=300 \
    --spawn-rate=1 \
    --run-time=180 \
    --headless

echo -e "${GREEN}Prueba Locust finalizada${NC}"

# Enviar el archivo JSON generado al Ingress (ajusta el nombre y URL)
if [ -f metrics_collected.json ]; then
    INGRESS_URL="http://TU_INGRESS_URL/api/data"
    echo -e "${YELLOW}Enviando metrics_collected.json al Ingress...${NC}"
    curl -X POST -H "Content-Type: application/json" --data-binary @metrics_collected.json "$INGRESS_URL"
    echo -e "${GREEN}✓ Archivo enviado al Ingress${NC}"
else
    echo -e "${RED}No se encontró metrics_collected.json para enviar al Ingress${NC}"
fi

echo -e "${GREEN}Script completado.${NC}"