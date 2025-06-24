#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== PRUEBA ESPECÍFICA: 300 USUARIOS POR 3 MINUTOS ===${NC}"

# Verificar que el sistema esté activo
if ! curl -s http://localhost:3000/api/metrics/complete > /dev/null; then
    echo -e "${RED} Sistema no responde. Ejecuta primero: ./run.sh${NC}"
    exit 1
fi

echo -e "${GREEN} Sistema verificado${NC}"

# Iniciar contenedores de estrés en background
echo -e "${YELLOW} Iniciando estrés del sistema...${NC}"
cd ../..
./stress.sh &
STRESS_PID=$!
cd Proyecto1_Fase2/Locust

sleep 5  # Dar tiempo a que el estrés inicie

echo -e "${YELLOW} Iniciando Locust con configuración específica:${NC}"
echo -e "   • 300 usuarios máximo"
echo -e "   • 1 usuario nuevo por segundo"
echo -e "   • Duración: 3 minutos"
echo -e "   • Peticiones cada 1-2 segundos"
echo -e ""

# Ejecutar Locust con parámetros específicos del enunciado
locust -f locustfile.py \
       --host=http://localhost:3000 \
       --users=300 \
       --spawn-rate=1 \
       --run-time=180 \
       --headless \
       --html=report_300_users.html \
       --csv=metrics_300_users

echo -e "\n${GREEN} Prueba completada${NC}"
echo -e "${YELLOW} Reportes generados:${NC}"
echo -e "   • report_300_users.html"
echo -e "   • metrics_300_users_stats.csv"
echo -e "   • metrics_300_users_failures.csv"

# Detener estrés
kill $STRESS_PID 2>/dev/null
echo -e "${GREEN} Estrés del sistema detenido${NC}"

# Mostrar estadísticas finales
echo -e "\n${YELLOW} Conteo aproximado de registros generados:${NC}"
RECORDS=$(curl -s "http://localhost:3000/api/metrics/cpu" | jq '. | length' 2>/dev/null || echo "N/A")
echo -e "   Registros en base de datos: ${GREEN}$RECORDS${NC}"