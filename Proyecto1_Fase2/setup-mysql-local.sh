#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}=== CONFIGURANDO MYSQL PARA TABLA METRICS UNIFICADA ===${NC}"
echo -e "${BLUE}Configuración para JSON: total_ram, ram_libre, uso_ram, porcentaje_ram, etc.${NC}"

# Función para resetear contraseña de MySQL root
reset_mysql_root_password() {
    echo -e "${YELLOW}Reseteando contraseña de MySQL root...${NC}"
    
    # 1. Detener MySQL
    echo -e "${YELLOW}1. Deteniendo MySQL...${NC}"
    sudo systemctl stop mysql
    
    # 2. Iniciar MySQL en modo seguro
    echo -e "${YELLOW}2. Iniciando MySQL en modo seguro...${NC}"
    sudo mysqld_safe --skip-grant-tables --skip-networking &
    MYSQL_PID=$!
    
    # Esperar a que MySQL inicie
    sleep 5
    
    # 3. Conectar y cambiar contraseña
    echo -e "${YELLOW}3. Cambiando contraseña de root...${NC}"
    mysql -u root <<EOF
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '';
FLUSH PRIVILEGES;
EOF
    
    # 4. Detener MySQL modo seguro
    echo -e "${YELLOW}4. Deteniendo modo seguro...${NC}"
    sudo kill $MYSQL_PID 2>/dev/null || true
    sudo pkill -f mysqld_safe 2>/dev/null || true
    sudo pkill -f mysqld 2>/dev/null || true
    sleep 3
    
    # 5. Iniciar MySQL normalmente
    echo -e "${YELLOW}5. Iniciando MySQL normalmente...${NC}"
    sudo systemctl start mysql
    sleep 3
    
    echo -e "${GREEN}✓ Contraseña de root reseteada (ahora está vacía)${NC}"
}

# Verificar si MySQL está instalado
if ! command -v mysql &> /dev/null; then
    echo -e "${YELLOW}Instalando MySQL Server...${NC}"
    sudo apt update
    sudo apt install -y mysql-server mysql-client
    
    # Configurar MySQL
    sudo systemctl enable mysql
    sudo systemctl start mysql
    
    echo -e "${GREEN}MySQL instalado y iniciado${NC}"
else
    echo -e "${GREEN}MySQL ya está instalado${NC}"
    sudo systemctl start mysql 2>/dev/null || true
fi

# Verificar estado de MySQL
if ! sudo systemctl is-active --quiet mysql; then
    echo -e "${RED}Error: MySQL no está ejecutándose${NC}"
    echo -e "${YELLOW}Intentando iniciar...${NC}"
    sudo systemctl start mysql
    sleep 3
    
    if ! sudo systemctl is-active --quiet mysql; then
        echo -e "${RED}No se pudo iniciar MySQL${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ MySQL está ejecutándose${NC}"

# Verificar acceso root
echo -e "${YELLOW}Verificando acceso root a MySQL...${NC}"

ROOT_ACCESS=false
ROOT_CMD=""

# Método 1: Sin contraseña
if mysql -u root -e "SELECT 1;" &>/dev/null; then
    echo -e "${GREEN}✓ Acceso root sin contraseña${NC}"
    ROOT_ACCESS=true
    ROOT_CMD="mysql -u root"
# Método 2: Con sudo
elif sudo mysql -u root -e "SELECT 1;" &>/dev/null; then
    echo -e "${GREEN}✓ Acceso root con sudo${NC}"
    ROOT_ACCESS=true
    ROOT_CMD="sudo mysql -u root"
else
    echo -e "${RED}✗ No se puede acceder como root${NC}"
    echo -e "${YELLOW}¿Quieres resetear la contraseña de root? (s/n)${NC}"
    read -r reset_choice
    
    if [[ $reset_choice =~ ^[SsYy]$ ]]; then
        reset_mysql_root_password
        
        # Verificar nuevamente
        if mysql -u root -e "SELECT 1;" &>/dev/null; then
            echo -e "${GREEN}✓ Acceso root sin contraseña (después del reset)${NC}"
            ROOT_ACCESS=true
            ROOT_CMD="mysql -u root"
        else
            echo -e "${RED}Error: Aún no se puede acceder después del reset${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}Intenta manualmente:${NC}"
        echo -e "${BLUE}sudo mysql_secure_installation${NC}"
        echo -e "${BLUE}sudo mysql -u root${NC}"
        exit 1
    fi
fi

if [ "$ROOT_ACCESS" = false ]; then
    echo -e "${RED}Error: No se pudo obtener acceso root${NC}"
    exit 1
fi

# Crear base de datos y usuario
echo -e "${YELLOW}Configurando base de datos y usuario...${NC}"

$ROOT_CMD <<EOF
-- Crear base de datos
CREATE DATABASE IF NOT EXISTS monitoring;

-- Eliminar usuario si existe
DROP USER IF EXISTS 'monitor'@'localhost';
DROP USER IF EXISTS 'monitor'@'%';

-- Crear usuario monitor
CREATE USER 'monitor'@'localhost' IDENTIFIED BY 'monitor123';
CREATE USER 'monitor'@'%' IDENTIFIED BY 'monitor123';

-- Dar permisos completos
GRANT ALL PRIVILEGES ON monitoring.* TO 'monitor'@'localhost';
GRANT ALL PRIVILEGES ON monitoring.* TO 'monitor'@'%';
FLUSH PRIVILEGES;

-- Verificar creación
SELECT User, Host FROM mysql.user WHERE User = 'monitor';
SELECT 'Usuario monitor creado correctamente' AS status;
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Usuario monitor creado correctamente${NC}"
else
    echo -e "${RED}✗ Error al crear usuario monitor${NC}"
    exit 1
fi

# Crear tabla unificada METRICS
echo -e "${YELLOW}Creando tabla unificada METRICS...${NC}"
mysql -u monitor -pmonitor123 <<EOF
USE monitoring;

-- Eliminar tablas antiguas si existen
DROP TABLE IF EXISTS cpu_metrics;
DROP TABLE IF EXISTS ram_metrics; 
DROP TABLE IF EXISTS process_metrics;
DROP TABLE IF EXISTS metrics_cache;

-- Crear tabla unificada que coincide EXACTAMENTE con tu JSON
CREATE TABLE IF NOT EXISTS metrics (
    id INT AUTO_INCREMENT PRIMARY KEY,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    -- Campos EXACTOS de tu JSON
    total_ram BIGINT NOT NULL DEFAULT 0,           -- 2072
    ram_libre BIGINT NOT NULL DEFAULT 0,          -- 1110552576
    uso_ram BIGINT NOT NULL DEFAULT 0,            -- 442
    porcentaje_ram FLOAT NOT NULL DEFAULT 0,      -- 22
    porcentaje_cpu_uso FLOAT NOT NULL DEFAULT 0,  -- 22
    porcentaje_cpu_libre FLOAT NOT NULL DEFAULT 0,-- 88
    procesos_corriendo INT NOT NULL DEFAULT 0,    -- 123
    total_procesos INT NOT NULL DEFAULT 0,        -- 233
    procesos_durmiendo INT NOT NULL DEFAULT 0,    -- 65
    procesos_zombie INT NOT NULL DEFAULT 0,       -- 65
    procesos_parados INT NOT NULL DEFAULT 0,      -- 65
    hora DATETIME NOT NULL,                       -- "2025-06-17 02:21:54"
    
    -- Metadatos para tracking
    api_source VARCHAR(50) DEFAULT 'unknown',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    -- Índices para optimización
    INDEX idx_timestamp (timestamp),
    INDEX idx_hora (hora),
    INDEX idx_api_source (api_source),
    INDEX idx_recent (timestamp DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Insertar datos de prueba con tu formato EXACTO
INSERT INTO metrics (
    total_ram, ram_libre, uso_ram, porcentaje_ram,
    porcentaje_cpu_uso, porcentaje_cpu_libre,
    procesos_corriendo, total_procesos, procesos_durmiendo,
    procesos_zombie, procesos_parados, hora, api_source
) VALUES (
    2072, 1110552576, 442, 22.0,
    22.0, 78.0,
    123, 233, 65,
    65, 65, '2025-06-17 02:21:54', 'test_inicial'
);

-- Verificar estructura y datos
DESCRIBE metrics;
SELECT 'Estructura de tabla:' AS info;
SELECT 
    total_ram, ram_libre, uso_ram, porcentaje_ram,
    porcentaje_cpu_uso, porcentaje_cpu_libre,
    procesos_corriendo, total_procesos, procesos_durmiendo,
    procesos_zombie, procesos_parados, hora, api_source
FROM metrics 
ORDER BY id DESC LIMIT 1;

SELECT 'Tabla metrics creada correctamente con formato JSON exacto' AS status;
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Tabla metrics creada correctamente${NC}"
else
    echo -e "${RED}✗ Error al crear tabla metrics${NC}"
    exit 1
fi

# Configurar MySQL para conexiones externas
echo -e "${YELLOW}Configurando MySQL para conexiones externas...${NC}"

# Backup del archivo de configuración
sudo cp /etc/mysql/mysql.conf.d/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf.backup 2>/dev/null || true

# Configurar bind-address
echo -e "${YELLOW}  → Configurando bind-address...${NC}"
sudo sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf 2>/dev/null || true

# Si no existe la línea, agregarla
if ! grep -q "bind-address" /etc/mysql/mysql.conf.d/mysqld.cnf; then
    echo "bind-address = 0.0.0.0" | sudo tee -a /etc/mysql/mysql.conf.d/mysqld.cnf > /dev/null
fi

# Reiniciar MySQL
echo -e "${YELLOW}  → Reiniciando MySQL...${NC}"
sudo systemctl restart mysql
sleep 5

# Verificar que está escuchando en todas las interfaces
if sudo netstat -tlnp | grep ":3306.*0.0.0.0" > /dev/null; then
    echo -e "${GREEN}✓ MySQL configurado para conexiones externas${NC}"
else
    echo -e "${YELLOW}⚠ MySQL puede no estar escuchando en todas las interfaces${NC}"
    echo -e "${BLUE}Estado actual:${NC}"
    sudo netstat -tlnp | grep ":3306" || echo "Puerto 3306 no encontrado"
fi

# Probar conexión final
echo -e "${YELLOW}Probando conexión final...${NC}"
if mysql -u monitor -pmonitor123 -e "USE monitoring; SELECT COUNT(*) as registros FROM metrics;" 2>/dev/null; then
    echo -e "${GREEN}✓ ¡MySQL configurado correctamente con tabla unificada!${NC}"
    
    # Mostrar información de conexión
    echo
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                  CONFIGURACIÓN COMPLETA                      ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${YELLOW}📋 Configuración de Base de Datos:${NC}"
    echo -e "${BLUE}   Host:${NC} localhost"
    echo -e "${BLUE}   Puerto:${NC} 3306" 
    echo -e "${BLUE}   Usuario:${NC} monitor"
    echo -e "${BLUE}   Contraseña:${NC} monitor123"
    echo -e "${BLUE}   Base de datos:${NC} monitoring"
    echo -e "${BLUE}   Tabla principal:${NC} metrics"
    
    # Mostrar IP de la máquina
    echo
    echo -e "${YELLOW}🌐 IP de esta máquina para APIs:${NC}"
    VM_IP=$(hostname -I | awk '{print $1}')
    echo -e "${GREEN}   ${VM_IP}${NC}"
    echo
    echo -e "${YELLOW}📝 String de conexión para APIs:${NC}"
    echo -e "${BLUE}   host: '${VM_IP}' // Usar esta IP en las APIs${NC}"
    echo
    echo -e "${YELLOW}🔧 Comandos de prueba:${NC}"
    echo -e "${BLUE}   mysql -u monitor -pmonitor123${NC}"
    echo -e "${BLUE}   mysql -u monitor -pmonitor123 -e 'USE monitoring; SELECT * FROM metrics;'${NC}"
    echo
    echo -e "${YELLOW}📊 Formato JSON que acepta la tabla:${NC}"
    echo -e "${BLUE}   {${NC}"
    echo -e "${BLUE}     \"total_ram\": 2072,${NC}"
    echo -e "${BLUE}     \"ram_libre\": 1110552576,${NC}"
    echo -e "${BLUE}     \"uso_ram\": 442,${NC}"
    echo -e "${BLUE}     \"porcentaje_ram\": 22,${NC}"
    echo -e "${BLUE}     \"porcentaje_cpu_uso\": 22,${NC}"
    echo -e "${BLUE}     \"porcentaje_cpu_libre\": 88,${NC}"
    echo -e "${BLUE}     \"procesos_corriendo\": 123,${NC}"
    echo -e "${BLUE}     \"total_procesos\": 233,${NC}"
    echo -e "${BLUE}     \"procesos_durmiendo\": 65,${NC}"
    echo -e "${BLUE}     \"procesos_zombie\": 65,${NC}"
    echo -e "${BLUE}     \"procesos_parados\": 65,${NC}"
    echo -e "${BLUE}     \"hora\": \"2025-06-17 02:21:54\"${NC}"
    echo -e "${BLUE}   }${NC}"
    echo
    echo -e "${YELLOW}🔄 Próximos pasos:${NC}"
    echo -e "${GREEN}   1. Actualizar las APIs con la IP: ${VM_IP}${NC}"
    echo -e "${GREEN}   2. Reconstruir imágenes Docker${NC}"
    echo -e "${GREEN}   3. Redesplegar en Kubernetes${NC}"
    echo -e "${GREEN}   4. Probar con Locust${NC}"
    
    # Verificar datos de prueba
    echo
    echo -e "${YELLOW}📊 Datos de prueba en la tabla:${NC}"
    mysql -u monitor -pmonitor123 -e "USE monitoring; SELECT total_ram, porcentaje_cpu_uso, porcentaje_ram, total_procesos, api_source, hora FROM metrics ORDER BY id DESC LIMIT 3;" 2>/dev/null || echo "No se pudieron mostrar datos"
    
else
    echo -e "${RED}✗ Error en la conexión final${NC}"
    
    # Diagnóstico
    echo -e "${YELLOW}Diagnóstico:${NC}"
    sudo systemctl status mysql --no-pager | head -3
    mysql -u root -e "SELECT User, Host FROM mysql.user WHERE User = 'monitor';" 2>/dev/null || echo "No se pudo verificar usuario"
    
    exit 1
fi

echo
echo -e "${GREEN}🎉 ¡Configuración de MySQL completada exitosamente!${NC}"
echo -e "${BLUE}La tabla 'metrics' está lista para recibir datos en formato JSON${NC}"