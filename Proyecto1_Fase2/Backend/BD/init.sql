-- Script de inicialización de la base de datos
-- Este script se ejecutará automáticamente cuando se inicie el contenedor MySQL por primera vez

-- Crear la base de datos si no existe
CREATE DATABASE IF NOT EXISTS monitoring;
USE monitoring;

-- Tabla para métricas de CPU
CREATE TABLE IF NOT EXISTS cpu_metrics (
    id INT AUTO_INCREMENT PRIMARY KEY,
    timestamp BIGINT NOT NULL,
    porcentaje_uso INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla para métricas de RAM
CREATE TABLE IF NOT EXISTS ram_metrics (
    id INT AUTO_INCREMENT PRIMARY KEY,
    timestamp BIGINT NOT NULL,
    total BIGINT NOT NULL,
    libre BIGINT NOT NULL,
    uso BIGINT NOT NULL,
    porcentaje_uso INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla para caché de métricas más recientes
CREATE TABLE IF NOT EXISTS metrics_cache (
    id VARCHAR(20) PRIMARY KEY,
    timestamp BIGINT NOT NULL,
    data JSON NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Crear índices para mejorar el rendimiento
CREATE INDEX idx_cpu_timestamp ON cpu_metrics(timestamp);
CREATE INDEX idx_ram_timestamp ON ram_metrics(timestamp);
CREATE INDEX idx_metrics_cache_updated ON metrics_cache(updated_at);

-- Añadir usuario con permisos solo para esta base de datos
-- Esto ya se hace automáticamente a través de las variables de entorno en docker-compose
-- GRANT ALL PRIVILEGES ON monitoring.* TO 'monitor'@'%';
-- FLUSH PRIVILEGES;

-- Mensaje de confirmación
SELECT 'Base de datos de monitoreo inicializada correctamente' AS mensaje;