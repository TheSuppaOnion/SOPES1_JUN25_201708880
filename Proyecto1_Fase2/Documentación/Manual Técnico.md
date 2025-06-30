# Manual Técnico - Sistema de Monitoreo de Recursos Fase 2

**Autor**: Bismarck Romero - 201708880  
**Versión**: 2.0.0  
**Fecha**: Junio 2025  

---

## Requisitos del Sistema

**Software**:
- Docker >= 20.10
- Docker Compose >= v2.0
- Kubernetes (Minikube o GKE)
- kubectl
- Node.js >= 18.x
- Go >= 1.24.4
- Python >= 3.10
- MySQL >= 8.0
- Git >= 2.25

**Sistema Operativo**:
- Ubuntu 22.04 LTS (recomendado)
- Kernel Linux 5.15+

---

## Descripción General

Sistema de monitoreo distribuido en tiempo real para recursos del sistema operativo Linux.  
En esta fase, el sistema soporta múltiples APIs (Node.js y Python), transmisión de métricas en vivo vía WebSocket, balanceo de carga, despliegue en Kubernetes y visualización avanzada en React.

---

## Prerrequisitos

- **Sistema Operativo:** Ubuntu 22.04 LTS
- **Versión del Kernel:** Linux 5.15 o superior
- **Acceso a Google Cloud Platform** (para despliegue en Cloud Run y GKE)
- **Permisos de red** para exponer servicios

---

### Script de Auto Instalación: setup-environment.sh
Si se desea se puede usar un script para instalar todo lo necesario para correr esta app, recuerda dar permisos con chmod +x setup-environment.sh, pero si prefieres tambien se puede instalar todo manualmente, en la siguiente sección se detalla como.

```bash
#!/bin/bash

# Script de auto-instalación para Fase 2
# Autor: Bismarck Romero - 201708880

echo "Actualizando repositorios..."
sudo apt update

echo "Instalando paquetes esenciales..."
sudo apt install -y build-essential linux-headers-$(uname -r) curl wget git

echo "Instalando Go 1.24.4..."
wget https://go.dev/dl/go1.24.4.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.24.4.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.profile
source ~/.profile
rm go1.24.4.linux-amd64.tar.gz
echo "Go instalado: $(go version)"

echo "Instalando Node.js..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
echo "Node.js instalado: $(node -v)"
echo "NPM instalado: $(npm -v)"

echo "Instalando Python 3 y pip..."
sudo apt install -y python3 python3-pip
echo "Python instalado: $(python3 --version)"
echo "pip instalado: $(pip3 --version)"

echo "Instalando Docker y Docker Compose..."
sudo apt install -y docker.io docker-compose
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
echo "Docker instalado: $(docker --version)"
echo "Docker Compose instalado: $(docker-compose --version)"

echo "Instalando kubectl y Minikube..."
sudo apt install -y apt-transport-https ca-certificates gnupg
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt install -y kubectl
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64
echo "kubectl instalado: $(kubectl version --client --short)"
echo "minikube instalado: $(minikube version)"

echo -e "\nInstalación completada. Cierre la sesión y vuelva a iniciar para aplicar los cambios de grupo Docker."
echo "Después, ejecute './kernel.sh' para compilar e instalar los módulos del kernel y siga el manual para el despliegue de la infraestructura."

```

## Estructura Completa del Proyecto

```
Proyecto1_Fase2/
├── Backend/
│   ├── Agente/
│   │   ├── agente-de-monitor.go
│   │   ├── Dockerfile
│   │   └── go.mod
│   ├── API/
│   │   ├── index.js
│   │   ├── package.json
│   │   ├── Dockerfile
│   ├── API-Python/
│   │   ├── app.py
│   │   ├── requirements.txt
│   │   ├── Dockerfile
│   └── WebSocket-API/
│       ├── index.js
│       ├── package.json
│       ├── Dockerfile
├── Documentación/
│   └── Manual Técnico.md
├── Frontend/
│   ├── .env
│   ├── Dockerfile
│   ├── package.json
│   ├── public/
│   │   └── index.html
│   └── src/
│       ├── App.js
│       ├── config.js
│       ├── index.js
│       ├── App.css
├── k8s/
│   ├── manifests/
│   │   ├── websocket-api/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   ├── ingress/
│   │   │   ├── ingress-main.yaml
│   │   │   ├── traffic-split.yaml
│   └── scripts/
│       ├── build-images.sh
│       └── setup-minikube.sh
├── Locust/
│   ├── locustfile.py
│   ├── locustfile_send.py
│   ├── requirements.txt
│   └── run_locust.sh
├── Modulos/
│   ├── cpu_201708880.c
│   ├── ram_201708880.c
│   ├── procesos_201708880.c
│   ├── Makefile
│   └── README.md
├── delete.sh
├── kernel.sh
├── run-minikube.sh
├── run-vm-agente.sh
├── setup-frontend-local.sh
├── setup-mysql-local.sh
├── stress.sh
├── zombie.c
```

## Componentes Principales

### Módulos del Kernel

**Ubicación**: `/Proyecto1_Fase2/Modulos/`  
**Descripción**: Implementación a nivel de kernel para obtener métricas precisas y en tiempo real del sistema, incluyendo CPU, RAM y procesos (corriendo, durmiendo, zombie y parados).

**Archivos Principales**:
- `cpu_201708880.c`: Módulo que monitorea el uso de CPU del sistema.  
  - Implementa cálculo `(100 - idle_delta*100/total_delta)` para obtener el porcentaje de uso.
  - Usa `proc_ops` para exponer `/proc/cpu_201708880`.
  - Mantiene estado entre llamadas para calcular diferencias de uso.
  - Expone los datos en formato JSON.

- `ram_201708880.c`: Módulo que monitorea el uso de memoria RAM.  
  - Utiliza la función `si_meminfo()` para obtener información de memoria.
  - Calcula memoria disponible como la suma de libre, buffers y cached.
  - Expone datos en formato JSON desde `/proc/ram_201708880`.

- `procesos_201708880.c`: Módulo que monitorea el estado de los procesos del sistema.  
  - Recorre la lista de procesos del kernel usando `for_each_process`.
  - Cuenta procesos en cada estado: corriendo, durmiendo, zombie y parados.
  - Expone los datos en formato JSON desde `/proc/procesos_201708880`.
  - Permite al agente y a otros usuarios del sistema consultar en tiempo real la cantidad de procesos en cada estado.

**Comandos**:
```sh
cd Modulos/ && make
sudo insmod cpu_201708880.ko
sudo insmod ram_201708880.ko
sudo insmod procesos_201708880.ko

cat /proc/cpu_201708880
cat /proc/ram_201708880
cat /proc/procesos_201708880
```
---
### Agente de Monitoreo

**Ubicación**: `/Proyecto1_Fase2/Backend/Agente/`  
**Descripción**: Aplicación en Go que utiliza concurrencia (Productor-Consumidor) para recolectar métricas de CPU, RAM y procesos a través de los módulos del kernel, y las envía periódicamente a las APIs (Node.js y Python) para su almacenamiento y visualización.

**Arquitectura**:
- **Productores**: Tres goroutines independientes para CPU, RAM y procesos, cada una leyendo su respectivo archivo en `/proc/`.
- **Consumidor**: Goroutine que procesa y consolida las métricas recibidas de los canales y las envía a las APIs configuradas.
- **Canales**: Comunicación concurrente eficiente entre productores y consumidor para evitar bloqueos y pérdida de datos.
- **Servidor HTTP**: Expone endpoints `/metrics` y `/health` para monitoreo y pruebas locales.

**Variables de Configuración**:
- `API_URL_NODEJS`: URL de la API Node.js para enviar métricas (ejemplo: `http://localhost:3000/api/data`)
- `API_URL_PYTHON`: URL de la API Python para redundancia (ejemplo: `http://localhost:5000/api/data`)
- `POLL_INTERVAL`: Intervalo de recolección de métricas (ejemplo: `2s`)
- `AGENTE_PORT`: Puerto donde expone el endpoint HTTP local (por defecto: `8080`)

**Comandos clave**:
```go
monitorCPU        // lee /proc/cpu_201708880
monitorRAM        // lee /proc/ram_201708880
monitorProcesos   // lee /proc/procesos_201708880
procesarMetricas  // consolida y envía a las APIs
```

**Ejecución**:
```sh
cd Backend/Agente/
go build -o agente-de-monitor agente-de-monitor.go
./agente-de-monitor
```

**Endpoints HTTP locales**:
- `GET /metrics`: Devuelve la última métrica consolidada en formato JSON.
- `GET /health`: Devuelve el estado de salud del agente.

**Notas**:
- El agente puede ejecutarse en una VM, contenedor o directamente en la máquina host.
- Es fundamental que tenga acceso de lectura a los archivos `/proc/cpu_201708880`, `/proc/ram_201708880` y `/proc/procesos_201708880`.
- El agente está preparado para tolerar fallos temporales en las APIs destino y reintenta el
---

### API Node.js

**Ubicación**: `/Proyecto1_Fase2/Backend/API/`  
**Lenguaje**: Node.js  
**Descripción**:  
- Recibe y almacena métricas enviadas por el agente en la base de datos MySQL.
- Expone endpoints REST para consultar métricas actuales, estadísticas y estado de salud.
- Sirve como fuente principal de datos para el WebSocket API y el frontend.

**Endpoints principales:**
- `POST /api/data`:  
  Recibe métricas del agente (en formato JSON, puede ser un objeto o un arreglo de objetos) y las almacena en la tabla `metrics`.  
  Valida que los campos principales estén presentes y responde con éxito o error.

- `GET /api/metrics`:  
  Devuelve la última métrica registrada en la base de datos, estructurada para el frontend (CPU, RAM, procesos, timestamp, fuente).

- `GET /api/stats`:  
  Devuelve estadísticas generales, como el total de registros y cuántos fueron insertados por esta API.

- `GET /health`:  
  Devuelve el estado de salud de la API y la conexión a la base de datos.

- `GET /`:  
  Endpoint simple para verificar que el servicio está corriendo.

**Variables de entorno:**
- `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`

**Notas:**
- Al iniciar, la API verifica y crea la tabla `metrics` si no existe.
- Usa un pool de conexiones para eficiencia y tolerancia a carga.
- Maneja errores y desconexiones de la base de datos de forma robusta.
- Puede ser desplegada en local, VM, contenedor o Kubernetes.

---

### API Python

**Ubicación**: `/Proyecto1_Fase2/Backend/API-Python/`  
**Lenguaje**: Python (Flask)  
**Descripción**:  
- API redundante para balanceo de carga, alta disponibilidad y pruebas.
- Recibe y almacena métricas en la misma base de datos MySQL que la API Node.js.
- Expone endpoints REST equivalentes a la API Node.js para compatibilidad.

**Endpoints principales:**
- `POST /api/data`:  
  Recibe métricas del agente (en formato JSON, objeto o arreglo) y las almacena en la tabla `metrics`.  
  Añade el campo `api_source` como `python` para distinguir el origen.

- `GET /api/metrics`:  
  Devuelve la última métrica registrada.

- `GET /api/stats`:  
  Devuelve estadísticas generales y cuántos registros fueron insertados por esta API.

- `GET /health`:  
  Devuelve el estado de salud de la API y la conexión a la base de datos.

- `GET /`:  
  Endpoint simple para verificar que el servicio está corriendo.

**Variables de entorno:**
- `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`

**Notas:**
- Usa un pool de conexiones para eficiencia.
- Crea la tabla `metrics` si no existe.
- Compatible con despliegue en local, VM, contenedor o Kubernetes.
- Permite comparar desempeño y robustez entre Node.js y Python.

---

### WebSocket API

**Ubicación**: `/Proyecto1_Fase2/Backend/WebSocket-API/`  
**Lenguaje**: Node.js + Socket.IO  
**Descripción**:  
- Lee métricas recientes de la base de datos MySQL (tabla `metrics`).
- Transmite métricas en tiempo real al frontend React usando WebSocket (Socket.IO).
- Permite a los clientes solicitar métricas actuales, datos históricos y estadísticas.

**Eventos y endpoints principales:**
- **Socket.IO (WebSocket):**
  - **outgoing**:
    - `welcome`: Mensaje de bienvenida y metadatos al conectar.
    - `metrics_update`: Envía la métrica más reciente a todos los clientes conectados (broadcast cada 2 segundos).
    - `historical_data`: Envía datos históricos de los últimos X minutos.
    - `system_stats`: Envía estadísticas agregadas de las últimas 24h.
    - `error`: Envía mensajes de error.
  - **incoming**:
    - `request_metrics`: El cliente solicita la métrica actual.
    - `request_historical`: El cliente solicita datos históricos (parámetro: minutos).
    - `request_stats`: El cliente solicita estadísticas agregadas.

- **REST:**
  - `GET /health`: Estado de salud del servicio y la base de datos.
  - `GET /api/metrics`: Última métrica registrada.
  - `GET /`: Información general del servicio.

**Notas:**
- El WebSocket API solo lee datos de la tabla `metrics` y nunca escribe.
- El broadcast automático de métricas permite que el frontend se actualice en tiempo real.
- Puede ser desplegado en local, VM, contenedor o Kubernetes.
- Es fundamental para la visualización en vivo en el

### Frontend

**Ubicación**: `/Frontend/`  
**Lenguaje**: React  
**Descripción**:  
- Aplicación web moderna desarrollada en React que permite visualizar en tiempo real las métricas del sistema recolectadas por el agente y transmitidas por el WebSocket API.
- Muestra gráficas interactivas (Pie charts) para el uso de CPU y RAM, y una tabla detallada con el estado de los procesos (corriendo, durmiendo, zombie, parados, total).
- Indica el estado de la conexión WebSocket y la última actualización recibida.
- Permite observar la variabilidad de los datos generados por el sistema bajo carga y stress.

**Variables de entorno:**
- `REACT_APP_WEBSOCKET_URL`: URL del WebSocket API (por ejemplo, `ws://localhost:4000` o la URL pública en despliegue).
- `REACT_APP_API_URL`: (opcional) URL de la API REST para consultas adicionales.

**Estructura principal:**
- `public/index.html`: Archivo HTML base donde se monta la app.
- `src/App.js`: Componente principal, maneja la conexión WebSocket, recibe y muestra las métricas.
- `src/config.js`: Configuración de URLs y variables de entorno.
- `src/App.css`: Estilos personalizados para la interfaz.
- `src/index.js`: Punto de entrada de la aplicación React.

**Características clave:**
- **Conexión WebSocket**: Usa `socket.io-client` para recibir eventos `metrics_update` en tiempo real.
- **Gráficas**: Utiliza `react-chartjs-2` y `chart.js` para mostrar el uso de CPU y RAM.
- **Tabla de procesos**: Muestra la cantidad y descripción de procesos en cada estado.
- **Estado de conexión**: Indica si el frontend está conectado o desconectado del WebSocket API.
- **Responsive**: Interfaz adaptativa para escritorio y dispositivos móviles.
- **Fácil despliegue**: Puede ejecutarse localmente, en contenedor Docker o en servicios como Cloud Run.

**Build y ejecución local:**
```sh
cd Frontend/
npm install
npm run build
npm start
```

**Notas:**
- El frontend solo requiere acceso de red al WebSocket API para funcionar en tiempo real.
- Si el WebSocket API cambia de URL, solo es necesario actualizar la variable `REACT_APP_WEBSOCKET_URL` y reconstruir la app.
- El diseño y los estilos pueden personalizarse fácilmente
---

### Infraestructura Kubernetes

**Ubicación**: `/k8s/manifests/`  
**Descripción**:  
- Incluye todos los manifiestos necesarios para desplegar la solución completa en un clúster Kubernetes (local con Minikube o en la nube).
- Permite orquestar y escalar los servicios de APIs, WebSocket, frontend y base de datos, así como exponerlos mediante servicios e ingress.

**Estructura principal:**
```
k8s/
├── manifests/
│   ├── namespace.yaml
│   ├── api-nodejs/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── api-python/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── websocket-api/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── ingress/
│   │   ├── ingress-main.yaml
│   │   └── traffic-split.yaml
├── scripts/
│   ├── build-images.sh
│   └── setup-minikube.sh
```

**Archivos clave:**
- `namespace.yaml`: Define el namespace `so1-fase2` para aislar los recursos del proyecto.
- `api-nodejs/deployment.yaml` y `service.yaml`: Despliegue y servicio para la API Node.js.
- `api-python/deployment.yaml` y `service.yaml`: Despliegue y servicio para la API Python.
- `websocket-api/deployment.yaml` y `service.yaml`: Despliegue y servicio para el WebSocket API.
- `ingress/ingress-main.yaml` y `traffic-split.yaml`: Configuración de ingress para balanceo de tráfico y acceso externo a las APIs.
- `scripts/build-images.sh`: Script para construir las imágenes Docker necesarias y cargarlas en Minikube.
- `scripts/setup-minikube.sh`: Script para instalar y configurar Minikube y kubectl.

**Despliegue en Minikube:**

1. **Iniciar Minikube y configurar Docker:**
   ```sh
   cd k8s/scripts/
   ./setup-minikube.sh
   eval $(minikube docker-env)
   ```

2. **Construir imágenes Docker para las APIs y WebSocket:**
   ```sh
   ./build-images.sh
   ```

3. **Aplicar los manifiestos de Kubernetes:**
   ```sh
   cd ../manifests/
   kubectl apply -f namespace.yaml
   kubectl apply -f api-nodejs/
   kubectl apply -f api-python/
   kubectl apply -f websocket-api/
   kubectl apply -f ingress/
   ```

4. **Verificar el estado de los pods y servicios:**
   ```sh
   kubectl get pods -n so1-fase2
   kubectl get svc -n so1-fase2
   kubectl get ingress -n so1-fase2
   ```

5. **Acceder a los servicios:**
   - Puedes usar `minikube service` para exponer servicios localmente.
   - El ingress permite acceder a las APIs usando el host `api.monitor.local` (puedes mapearlo en `/etc/hosts`).

**Notas:**
- Los manifiestos están preparados para usar la base de datos MySQL externa o en VM (ajusta `DB_HOST` si es necesario).
- El tráfico entre APIs puede balancearse usando los ingress y las anotaciones de canary/traffic-split.
- Puedes escalar los despliegues modificando el campo `replicas` en los archivos `deployment.yaml`.
- El frontend puede desplegarse aparte o integrarse como un deployment y service adicional en Kubernetes.
- Para pruebas en local, asegúrate de tener suficiente memoria y CPU asignada a

---

### Pruebas de Carga (Locust)

**Ubicación**: `/Locust/`  
**Descripción**:  
- Contiene scripts y utilidades para realizar pruebas de carga tanto sobre los endpoints HTTP (APIs y agente) como sobre el flujo de envío de métricas al sistema.
- Permite simular múltiples usuarios concurrentes, automatizar la recolección de métricas y el envío masivo de datos para validar la robustez y escalabilidad de la infraestructura.

**Estructura principal:**
```
Locust/
├── locustfile.py           # Simula usuarios que consultan el agente y recolectan métricas
├── locustfile_send.py      # Simula usuarios que envían métricas recolectadas a la API vía Ingress
├── requirements.txt        # Dependencias de Python para Locust y pruebas
└── run_locust.sh           # Script automatizado para ejecutar ambas fases de la prueba
```

**Flujo de pruebas:**

1. **Fase 1: Recolección de métricas**
   - `locustfile.py` simula usuarios que consultan el endpoint `/metrics` del agente (Go) y guarda las respuestas en un archivo `metrics_collected.json`.
   - Permite generar un conjunto realista de métricas para pruebas posteriores.

2. **Fase 2: Envío masivo de métricas**
   - `locustfile_send.py` toma el archivo `metrics_collected.json` y simula usuarios que envían cada métrica como un POST a `/api/data` de la API (Node.js o Python) a través del Ingress.
   - Permite probar la capacidad de ingestión y procesamiento de la infraestructura bajo carga.

**Ejecución:**
```sh
cd Locust/
./run_locust.sh
```
- El script crea un entorno virtual de Python si es necesario, instala dependencias y ejecuta ambas fases de la prueba.
- Puedes usar el argumento `--skip-fase1` para saltar la recolección y solo enviar métricas previamente recolectadas.

**Dependencias:**
- Locust (`locust==2.17.0`)
- Requests (`requests==2.31.0`)
- Faker (`faker==20.1.0`)

**Notas:**
- Edita las variables `AGENTE_URL` y `INGRESS_URL` en los archivos Python para apuntar a tus endpoints reales.
- El archivo `metrics_collected.json` se genera automáticamente tras la Fase 1 y es usado en la Fase 2.
- El header `"Host": "api.monitor.local"` en `locustfile_send.py` permite probar el Ingress de Kubernetes con nombres virtuales.
- Puedes ajustar el número de usuarios, tasa de aparición y duración de la prueba modificando los parámetros en `run_locust.sh` o directamente en los archivos Python.
- Los resultados de la prueba pueden ser usados para analizar el rendimiento, detectar cuellos de botella y validar la tolerancia a carga del

---

### Scripts Útiles

- `kernel.sh`: Compila y carga módulos del kernel.
- `setup-mysql-local.sh`: Prepara la base de datos MySQL local.
- `setup-frontend-local.sh`: Prepara el entorno local para el frontend.
- `run-minikube.sh`: Despliega toda la infraestructura en Minikube.
- `run-vm-agente.sh`: Lanza el agente de monitoreo en una VM.
- `stress.sh`: Genera carga variable para pruebas de monitoreo (incluye generación de procesos zombie y parados).
- `delete.sh`: Elimina todos los recursos y contenedores del proyecto.
- `zombie.sh`: Script auxiliar para crear procesos zombie en pruebas.

---

## Flujo General del Sistema

1. **Módulos del kernel** exponen métricas en `/proc`.
2. **Agente en Go** recolecta métricas y las envía a las APIs.
3. **APIs** almacenan las métricas en MySQL.
4. **WebSocket API** lee métricas recientes y las transmite en tiempo real al frontend.
5. **Frontend React** muestra gráficas y tablas en vivo.
6. **Locust** permite pruebas de carga y `stress.sh` simula variabilidad en el sistema.

---

## Pruebas y Uso

### Generar carga variable

```sh
./stress.sh
```
Esto generará carga variable de CPU, RAM y procesos (incluyendo procesos zombie y parados) para que el sistema registre y visualice datos variados.

### Pruebas de carga con Locust

```sh
cd Locust/
./run_locust.sh
```

### Visualización

- Accede al frontend en el puerto configurado (por defecto, http://localhost:8080 o la URL de Cloud Run).
- Observa las gráficas y tablas actualizándose en tiempo real.

---

## Consultas Útiles para la Base de Datos

- **¿Alguna vez hubo un proceso zombie?**
  ```sql
  SELECT * FROM metrics WHERE procesos_zombie > 0 LIMIT 1;
  ```
- **¿Cuántas veces hubo procesos parados?**
  ```sql
  SELECT COUNT(*) FROM metrics WHERE procesos_parados > 0;
  ```
- **Última vez con procesos zombie:**
  ```sql
  SELECT * FROM metrics WHERE procesos_zombie > 0 ORDER BY timestamp DESC LIMIT 1;
  ```

---

## Notas y Recomendaciones

- Asegúrate de que las variables de entorno estén configuradas antes de construir las imágenes.
- El WebSocket API debe tener acceso a la base de datos para leer métricas recientes.
- El frontend debe apuntar al endpoint correcto de WebSocket según el entorno (local, GKE, Cloud Run).
- Para ver procesos zombie/parados, asegúrate de que el script `stress.sh` y `zombie.sh` los generen correctamente en el entorno de pruebas.
- Si usas Cloud Run para el frontend, configura correctamente el proxy para WebSocket si es necesario.

---

## Desinstalación

```sh
./delete.sh
```
Esto eliminará todos los recursos de Docker, Kubernetes y limpiará el entorno.

---

**Permisos**:  
Algunas operaciones requieren permisos de superusuario (`sudo`), especialmente para módulos del kernel y administración de Docker.

---