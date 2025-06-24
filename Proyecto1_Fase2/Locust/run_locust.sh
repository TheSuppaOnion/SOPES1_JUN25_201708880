#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Verificar que el sistema principal esté ejecutándose
echo -e "${YELLOW}Verificando que el sistema de monitoreo esté activo...${NC}"

# Verificar API
if curl -s http://localhost:3000/api/metrics/latest > /dev/null; then
    echo -e "${GREEN}✓ API respondiendo en puerto 3000${NC}"
else
    echo -e "${RED}✗ API no responde. Asegúrate de ejecutar primero: ./run.sh${NC}"
    exit 1
fi

# Verificar Frontend
if curl -s http://localhost:8080 > /dev/null; then
    echo -e "${GREEN}✓ Frontend respondiendo en puerto 8080${NC}"
else
    echo -e "${RED}✗ Frontend no responde. Asegúrate de ejecutar primero: ./run.sh${NC}"
    exit 1
fi

echo -e "\n${YELLOW}=== INICIANDO LOCUST ===${NC}"
echo -e "${GREEN}Interfaz web estará disponible en: http://localhost:8089${NC}"
echo -e "${YELLOW}Configuraciones recomendadas:${NC}"
echo -e "  • Usuarios normales: 10-50"
echo -e "  • Spawn rate: 2-5 usuarios/segundo"
echo -e "  • Para pruebas intensas: 100+ usuarios"
echo -e "\n${YELLOW}Presiona Ctrl+C para detener${NC}\n"

# Ejecutar Locust apuntando al frontend (que proxy a la API)
locust -f locustfile.py --host=http://localhost:8080 --web-host=0.0.0.0 --web-port=8089