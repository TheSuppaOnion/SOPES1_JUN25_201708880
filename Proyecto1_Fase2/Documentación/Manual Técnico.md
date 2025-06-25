
# Manual Técnico - Sistema de Monitoreo de Recursos

**Autor**: Bismarck Romero - 201708880  
**Versión**: 1.0.0  
**Fecha**: Junio 2025  

## Requisitos del Sistema

**Software**:
- Docker >= 20.10
- Docker Compose >= v2.0
- Git >= 2.25
- Paquetes: `build-essential`, `linux-headers-$(uname -r)` , `golang` , `nodejs` , `docker`, `docker-compose`

**Sistema Operativo**:
- Ubuntu 22.04 LTS
- Kernel Linux 5.15+

## Descripción General

Sistema de monitoreo en tiempo real para recursos del sistema operativo Linux. Utiliza módulos del kernel para obtener métricas de CPU y RAM, las almacena en una base de datos MySQL con mecanismos de caché para optimizar el rendimiento, y las visualiza mediante gráficos de pastel interactivos en una interfaz web.

## Prerrequisitos
- **Sistema Operativo:** Ubuntu 22.04 LTS
- **Versión del Kernel:** Linux 5.15 o superior

## Instrucciones

### Script de Auto Instalación: setup-environment.sh
Si se desea se puede usar un script para instalar todo lo necesario para correr esta app, recuerda dar permisos con chmod +x setup-environment.sh, pero si prefieres tambien se puede instalar todo manualmente, en la siguiente sección se detalla como.

```bash
#!/bin/bash

# Actualizar repositorios
sudo apt update

# Instalar paquetes esenciales
sudo apt install -y build-essential linux-headers-$(uname -r) curl wget git

# Instalar Python 3 y pip (para Locust)
sudo apt install -y python3 python3-pip python3-venv
echo "Python instalado: $(python3 --version)"
echo "Pip instalado: $(pip3 --version)"

# Crear alias para facilitar uso de Python
echo 'alias python=python3' >> ~/.bashrc
echo 'alias pip=pip3' >> ~/.bashrc

# Instalar Locust para pruebas de carga
pip3 install --user locust requests faker
echo "Locust instalado: $(python3 -m locust --version)"

# Instalar Go 1.24.4
wget https://go.dev/dl/go1.24.4.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.24.4.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.profile
source ~/.profile
rm go1.24.4.linux-amd64.tar.gz
echo "Go instalado: $(go version)"

# Instalar Node.js
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
echo "Node.js instalado: $(node -v)"
echo "NPM instalado: $(npm -v)"

# Instalar Docker y Docker Compose
sudo apt install -y docker.io docker-compose
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
echo "Docker instalado: $(docker --version)"
echo "Docker Compose instalado: $(docker-compose --version)"

echo -e "\n=== INSTALACIÓN COMPLETADA ==="
echo "Software instalado:"
echo " Python 3 y pip"
echo " Locust (para pruebas de carga)"
echo " Go 1.24.4"
echo " Node.js 20.x"
echo " Docker y Docker Compose"
echo ""
echo "IMPORTANTE:"
echo "1. Cierre la sesión y vuelva a iniciar para aplicar los cambios de grupo Docker"
echo "2. Ejecute 'source ~/.bashrc' para cargar los alias de Python"
echo "3. Después, ejecute './kernel.sh' para compilar e instalar los módulos del kernel"
echo "4. Para pruebas de carga: cd Proyecto1_Fase2/Locust && ./run_locust.sh"

```

### Paquetes Requeridos (Instalacion manual)
- **build-essential** (sin versión especificada): Herramientas esenciales para compilación
  ```bash
  sudo apt install build-essential
  ```
- **linux-headers** (sin versión especificada): Cabeceras del kernel Linux para compilar módulos
  ```bash
  sudo apt install linux-headers-$(uname -r)
  ```
- **python3 y pip3**: Python 3 y gestor de paquetes para Locust
  ```bash
  sudo apt install python3 python3-pip python3-venv
  ```
- **locust**: Herramienta para pruebas de carga y estrés
  ```bash
  pip3 install --user locust requests faker
  ```
- **golang** (1.24.4): Lenguaje de programación Go para el agente de monitoreo
  ```bash
  wget https://go.dev/dl/go1.24.4.linux-amd64.tar.gz && sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.24.4.linux-amd64.tar.gz && echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.profile && source ~/.profile
  ```
- **nodejs** (20.x LTS): Entorno de ejecución JavaScript para la API
  ```bash
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt install -y nodejs
  ```
- **docker** (20.10+): Plataforma de contenedores para desplegar servicios
  ```bash
  sudo apt install docker.io
  ```
- **docker-compose** (2.0+): Herramienta para definir aplicaciones multi-contenedor
  ```bash
  sudo apt install docker-compose
  ```
### Configuración Adicional
```bash
sudo systemctl enable --now docker
```
```bash
sudo usermod -aG docker $USER
```
```bash
# Cerrar sesión y volver a iniciar para aplicar los cambios de grupo
```

### Instalación
Luego de tener todos los prerequisitos instalados, se puede proceder a la instalación y uso del software.
1. `git clone https://github.com/username/proyecto1-fase1.git`
2. `sudo ./kernel.sh`
3. `./run.sh`
4. `docker ps`
5. Acceder a `http://localhost:8080`

### Prueba
1. `./stress.sh`
2. Ver métricas subir en la interfaz web
3. Consultar en la base de datos:  
```sh
docker exec -it mysql mysql -umonitor -pmonitor123 monitoring -e 'SELECT * FROM cpu_metrics ORDER BY timestamp DESC LIMIT 5'
```
### Pruebas de Carga con Locust
Para ejecutar pruebas de estrés con múltiples usuarios simulados:

1. **Asegurar que el sistema principal esté ejecutándose**:
   ```bash
   ./run.sh
   ```

2. **Ejecutar pruebas de carga específicas** (300 usuarios por 3 minutos):
   ```bash
   cd Proyecto1_Fase2/Locust
   ./run_locust.sh
   ```

3. **Verificar resultados**:
   - Reportes generados: `report_300_users.html`
   - Métricas: `metrics_300_users_stats.csv`
   - Fallos: `metrics_300_users_failures.csv`

**Configuración de la prueba**:
- 300 usuarios simultáneos máximo
- 1 nuevo usuario por segundo (spawn rate)
- Duración: 3 minutos (180 segundos)
- Peticiones cada 1-2 segundos por usuario
- Incluye estrés del sistema con contenedores Docker

### Desinstalación
1. `./delete.sh`
2. Confirmar eliminación de imágenes
3. Verificar con `docker ps`

**Permisos**: Requiere `sudo` para módulos del kernel

## Componentes Principales

### Módulos del Kernel

**Ubicación**: `/Proyecto1_Fase1/Modulos/`  
**Descripción**: Implementación a nivel de kernel para obtener métricas precisas del sistema.

**Archivos Principales**:
- `cpu_201708880.c`: Módulo que monitorea el uso de CPU del sistema.  
  - Implementa cálculo `(100 - idle_delta*100/total_delta)`
  - Usa `proc_ops` para exponer `/proc/cpu_201708880`
  - Mantiene estado entre llamadas

- `ram_201708880.c`: Módulo que monitorea el uso de memoria RAM.  
  - Usa `si_meminfo()`
  - Calcula memoria disponible = libre + buffers + cached
  - Datos expuestos en JSON desde `/proc/ram_201708880`

**Comandos**:
```sh
cd Modulos/ && make
sudo insmod cpu_201708880.ko && sudo insmod ram_201708880.ko
cat /proc/cpu_201708880
cat /proc/ram_201708880
```

### Agente de Monitoreo

**Ubicación**: `/Proyecto1_Fase1/Backend/Agente/`  
**Descripción**: Aplicación en Go que usa concurrencia (Productor-Consumidor) para recolectar métricas.

**Arquitectura**:
- **Productores**: Goroutines independientes para CPU y RAM
- **Consumidor**: Procesa datos y los envía a la API
- **Canales**: Comunicación concurrente eficiente

**Variables de Configuración**:
- `API_URL`: `http://localhost:3000/api/data`
- `POLL_INTERVAL`: `2s`

**Comandos clave**:
```go
monitorCPU -> lee /proc/cpu_201708880
monitorRAM -> lee /proc/ram_201708880
procesarMetricas -> envía a API
```

### API Backend

**Ubicación**: `/Proyecto1_Fase1/Backend/API/`  
**Descripción**: API RESTful en Node.js con caché y persistencia MySQL. Se utilizó como caché una tabla de la base de datos para agilizar el proceso de lectura de metricas del CPU y RAM y asi optimizar el consumo de recursos de la web app en funcionamiento.

**Endpoints**:
- `POST /api/data`: Recibe y almacena métricas
- `GET /api/metrics/cpu`: Últimas 100 métricas de CPU
- `GET /api/metrics/ram`: Últimas 100 métricas de RAM
- `GET /api/metrics/latest`: Métricas más recientes, usa caché

**Variables**:
- `DB_HOST`: `mysql`
- `DB_USER`: `monitor`
- `DB_PASSWORD`: `monitor123`
- `DB_NAME`: `monitoring`
- `SAMPLE_RATE`: `2000`

### Base de Datos

**Ubicación**: `/Proyecto1_Fase1/Backend/BD/`  
**Descripción**: MySQL para persistencia y caché.

**Tablas**:
- `cpu_metrics`: Registra uso de CPU
- `ram_metrics`: Uso de RAM, total, libre, en uso
- `metrics_cache`: Datos recientes, cacheados

**Persistencia**:
- Volumen `mysql-data` en Docker

### Frontend

**Ubicación**: `/Proyecto1_Fase1/Frontend/`  
**Descripción**: Interfaz web con Go Fiber y Chart.js

**Características**:
- Gráficos de pastel en tiempo real (AJAX cada 2s)
- Visualización responsiva
- Actualización dinámica de datos

## Infraestructura Docker
Todo el proyecto se encuentra dockerizado, se utiliza un docker-compose.yml para buildear o buscar las imagenes en dockerhub, el script de run.sh se encarga de buscar y preguntar al usuario que es lo que deasea, en cada una de las carpetas se encuentra un dockerfile correspondiente el cual tiene las instrucciones especificas para construir cada uno de los modulos de este proyecto, todo utiliza la red que maneja y crea docker por defecto a excepcion del agente de monitor o recolector como aparece en el enunciado, esto se hizo para poder acceder a los modulos de kernel en la carpeta /proc, de lo contrario no se podria ya que docker por defecto evita que se pueedan acceder a carpetas de la maquina host, mucho menos carpetas del sistema operativo como /proc. (Existe un archivo "dummy" en la carpeta /Proyecto1_Fase1/Frontend/static/ su función es simplemente dejar que el dockerfile del frontend funcione, se dejo asi por si en un futuro se quieren servir sitios estaticos)

**Archivo**: `docker-compose.yml`  
**Servicios**:
- `mysql`: Base de datos
- `api`: Backend Node.js
- `agente`: Monitor en Go
- `frontend`: Visualizador web

**Red**: `monitor-network`  
**Volumenes**: `mysql-data`

## Scripts Incluidos

- `kernel.sh`: Compila y carga módulos del kernel
- `run.sh`: Lanza la infraestructura completa
- `delete.sh`: Elimina contenedores y volúmenes
- `stress.sh`: Genera carga para probar el sistema
