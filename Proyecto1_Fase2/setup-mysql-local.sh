#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}=== CONFIGURANDO MYSQL NATIVO LOCAL ===${NC}"

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
GRANT ALL PRIVILEGES ON *.* TO 'monitor'@'localhost';
GRANT ALL PRIVILEGES ON *.* TO 'monitor'@'%';
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

# Crear tablas
echo -e "${YELLOW}Creando tablas...${NC}"
mysql -u monitor -pmonitor123 <<EOF
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

SHOW TABLES;
SELECT 'Tablas creadas correctamente' AS status;
EOF

# Probar conexión final
echo -e "${YELLOW}Probando conexión final...${NC}"
if mysql -u monitor -pmonitor123 -e "USE monitoring; SELECT 'Conexión exitosa' AS test;" 2>/dev/null; then
    echo -e "${GREEN}✓ ¡MySQL configurado correctamente!${NC}"
    
    # Información de conexión
    echo
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                  CONFIGURACIÓN COMPLETA                   ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${YELLOW}Host:${NC} localhost"
    echo -e "${YELLOW}Puerto:${NC} 3306"
    echo -e "${YELLOW}Usuario:${NC} monitor"
    echo -e "${YELLOW}Contraseña:${NC} monitor123"
    echo -e "${YELLOW}Base de datos:${NC} monitoring"
    echo
    echo -e "${YELLOW}String de conexión:${NC}"
    echo -e "${BLUE}mysql://monitor:monitor123@localhost:3306/monitoring${NC}"
    echo
    echo -e "${YELLOW}Comandos de prueba:${NC}"
    echo -e "${BLUE}mysql -u monitor -pmonitor123${NC}"
    echo -e "${BLUE}mysql -u monitor -pmonitor123 -e 'USE monitoring; SHOW TABLES;'${NC}"
    
else
    echo -e "${RED}✗ Error en la conexión final${NC}"
    
    # Diagnóstico
    echo -e "${YELLOW}Diagnóstico:${NC}"
    sudo systemctl status mysql --no-pager | head -3
    mysql -u root -e "SELECT User, Host FROM mysql.user WHERE User = 'monitor';" 2>/dev/null || echo "No se pudo verificar usuario"
    
    exit 1
fi