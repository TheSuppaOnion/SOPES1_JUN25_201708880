#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=== CONFIGURANDO MYSQL NATIVO LOCAL ===${NC}"

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
fi

# Crear base de datos y usuario
echo -e "${YELLOW}Configurando base de datos y usuario...${NC}"

mysql -u monitor -p <<EOF
-- Crear base de datos
CREATE DATABASE IF NOT EXISTS monitoring;

-- Crear usuario monitor
CREATE USER IF NOT EXISTS 'monitor'@'localhost' IDENTIFIED BY 'monitor123';
CREATE USER IF NOT EXISTS 'monitor'@'%' IDENTIFIED BY 'monitor123';

-- Dar permisos
GRANT ALL PRIVILEGES ON monitoring.* TO 'monitor'@'localhost';
GRANT ALL PRIVILEGES ON monitoring.* TO 'monitor'@'%';
FLUSH PRIVILEGES;

-- Crear tablas
USE monitoring;

CREATE TABLE IF NOT EXISTS cpu_metrics (
    id INT AUTO_INCREMENT PRIMARY KEY,
    timestamp BIGINT NOT NULL,
    porcentaje_uso FLOAT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_timestamp (timestamp)
);

CREATE TABLE IF NOT EXISTS ram_metrics (
    id INT AUTO_INCREMENT PRIMARY KEY,
    timestamp BIGINT NOT NULL,
    total_bytes BIGINT NOT NULL,
    libre_bytes BIGINT NOT NULL,
    uso_bytes BIGINT NOT NULL,
    porcentaje_uso FLOAT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_timestamp (timestamp)
);

CREATE TABLE IF NOT EXISTS process_metrics (
    id INT AUTO_INCREMENT PRIMARY KEY,
    timestamp BIGINT NOT NULL,
    procesos_corriendo INT NOT NULL,
    total_procesos INT NOT NULL,
    procesos_durmiendo INT NOT NULL,
    procesos_zombie INT NOT NULL,
    procesos_parados INT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_timestamp (timestamp)
);

CREATE TABLE IF NOT EXISTS metrics_cache (
    id INT AUTO_INCREMENT PRIMARY KEY,
    timestamp BIGINT NOT NULL,
    data JSON NOT NULL,
    type ENUM('cpu', 'ram', 'procesos') NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_timestamp_type (timestamp, type)
);

-- Verificar creación
SHOW TABLES;
SELECT 'Base de datos configurada correctamente' AS status;
EOF

echo -e "${GREEN}MySQL configurado correctamente${NC}"
echo -e "${YELLOW}Conexión de prueba:${NC}"
echo -e "Host: localhost"
echo -e "Puerto: 3306"
echo -e "Usuario: monitor"
echo -e "Contraseña: monitor123"
echo -e "Base de datos: monitoring"

# Probar conexión
mysql -u monitor -pmonitor123 -e "USE monitoring; SELECT 'Conexión exitosa' AS test;" 2>/dev/null && {
    echo -e "${GREEN}✓ Conexión de prueba exitosa${NC}"
} || {
    echo -e "${RED}✗ Error en conexión de prueba${NC}"
}