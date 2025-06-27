#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                            ║${NC}"
echo -e "${BLUE}║ ${YELLOW}FRONTEND REACT CON DOCKER - Bismarck Romero - 201708880${BLUE}  ║${NC}"
echo -e "${BLUE}║                                                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo

# Verificar Node.js y npm
check_nodejs() {
    echo -e "${YELLOW}Verificando Node.js y npm...${NC}"
    
    if ! command -v node &> /dev/null; then
        echo -e "${YELLOW}Node.js no está instalado, instalando automáticamente...${NC}"
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
        
        if ! command -v node &> /dev/null; then
            echo -e "${RED}Error: No se pudo instalar Node.js automáticamente${NC}"
            echo -e "${YELLOW}Instala Node.js manualmente: sudo apt install nodejs npm${NC}"
            exit 1
        fi
    fi
    
    if ! command -v npm &> /dev/null; then
        echo -e "${YELLOW}npm no está instalado, instalando...${NC}"
        sudo apt install npm -y
    fi
    
    NODE_VERSION=$(node --version)
    NPM_VERSION=$(npm --version)
    echo -e "${GREEN}✓ Node.js $NODE_VERSION disponible${NC}"
    echo -e "${GREEN}✓ npm $NPM_VERSION disponible${NC}"
}

# Verificar Docker
check_docker() {
    echo -e "${YELLOW}Verificando Docker...${NC}"
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker no está instalado${NC}"
        echo -e "${YELLOW}Instala Docker y vuelve a ejecutar este script${NC}"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        echo -e "${RED}Docker no está ejecutándose${NC}"
        echo -e "${YELLOW}Inicia Docker y vuelve a ejecutar este script${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Docker está disponible${NC}"
}

# Crear estructura del proyecto React AUTOMÁTICAMENTE
create_react_structure() {
    echo -e "${YELLOW}Creando estructura del proyecto React...${NC}"
    
    # Crear directorio Frontend si no existe
    if [ ! -d "Frontend" ]; then
        echo -e "${YELLOW}  → Creando directorio Frontend/...${NC}"
        mkdir -p Frontend
    fi
    
    cd Frontend
    
    # 1. Crear package.json
    echo -e "${YELLOW}  → Creando package.json...${NC}"
    cat > package.json << 'EOF'
{
  "name": "monitor-frontend-fase2",
  "version": "2.0.0",
  "private": true,
  "homepage": ".",
  "dependencies": {
    "@testing-library/jest-dom": "^5.16.4",
    "@testing-library/react": "^13.3.0",
    "@testing-library/user-event": "^13.5.0",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1",
    "socket.io-client": "^4.7.2",
    "chart.js": "^4.4.0",
    "react-chartjs-2": "^5.2.0",
    "axios": "^1.4.0",
    "react-router-dom": "^6.14.2"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "eslintConfig": {
    "extends": [
      "react-app",
      "react-app/jest"
    ]
  },
  "browserslist": {
    "production": [
      ">0.2%",
      "not dead",
      "not op_mini all"
    ],
    "development": [
      "last 1 chrome version",
      "last 1 firefox version",
      "last 1 safari version"
    ]
  }
}
EOF
    
    # 2. Crear directorio public y sus archivos
    echo -e "${YELLOW}  → Creando directorio public/...${NC}"
    mkdir -p public
    
    cat > public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="utf-8" />
    <link rel="icon" href="%PUBLIC_URL%/favicon.ico" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#000000" />
    <meta name="description" content="Sistema de Monitoreo en Tiempo Real - Fase 2" />
    <title>Monitor de Sistema - SO1 Fase 2</title>
    <style>
      body {
        margin: 0;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
          'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
          sans-serif;
        -webkit-font-smoothing: antialiased;
        -moz-osx-font-smoothing: grayscale;
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        min-height: 100vh;
      }
      
      #loading {
        display: flex;
        justify-content: center;
        align-items: center;
        height: 100vh;
        color: white;
        font-size: 1.2em;
      }
    </style>
  </head>
  <body>
    <noscript>Necesitas habilitar JavaScript para ejecutar esta aplicación.</noscript>
    <div id="root">
      <div id="loading">
        <div>
          <h2>🔄 Cargando Sistema de Monitoreo...</h2>
          <p>Inicializando componentes de React...</p>
        </div>
      </div>
    </div>
  </body>
</html>
EOF
    
    cat > public/manifest.json << 'EOF'
{
  "short_name": "Monitor SO1",
  "name": "Sistema de Monitoreo - Sistemas Operativos 1",
  "start_url": ".",
  "display": "standalone",
  "theme_color": "#000000",
  "background_color": "#ffffff"
}
EOF
    
    # 3. Crear directorio src y archivos principales
    echo -e "${YELLOW}  → Creando directorio src/...${NC}"
    mkdir -p src
    
    cat > src/index.js << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF
    
    cat > src/index.css << 'EOF'
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  min-height: 100vh;
  color: #333;
}

code {
  font-family: source-code-pro, Menlo, Monaco, Consolas, 'Courier New',
    monospace;
}

.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px;
}
EOF
    
    cat > src/App.js << 'EOF'
import React, { useState, useEffect } from 'react';
import './App.css';

function App() {
  const [metrics, setMetrics] = useState({
    cpu: { porcentaje_uso: 0 },
    ram: { porcentaje_uso: 0, total_gb: 0, libre_gb: 0 },
    procesos: { total_procesos: 0, procesos_corriendo: 0 }
  });
  const [connectionStatus, setConnectionStatus] = useState('disconnected');
  const [lastUpdate, setLastUpdate] = useState(null);

  // Configuración de APIs desde variables de entorno
  const API_BASE = process.env.REACT_APP_API_URL || '/api';
  const API_PYTHON = process.env.REACT_APP_API_PYTHON_URL || '/api-python';
  const WEBSOCKET_URL = process.env.REACT_APP_WEBSOCKET_URL || '/websocket';

  // Función para obtener métricas desde las APIs
  const fetchMetrics = async () => {
    try {
      setConnectionStatus('connecting');
      
      // Intentar desde API Node.js primero
      const responseNodeJS = await fetch(`${API_BASE}/metrics`, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
        },
      });

      if (responseNodeJS.ok) {
        const data = await responseNodeJS.json();
        setMetrics(data);
        setConnectionStatus('connected');
        setLastUpdate(new Date().toLocaleTimeString());
        return;
      }

      // Si falla, intentar API Python
      const responsePython = await fetch(`${API_PYTHON}/metrics`, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
        },
      });

      if (responsePython.ok) {
        const data = await responsePython.json();
        setMetrics(data);
        setConnectionStatus('connected');
        setLastUpdate(new Date().toLocaleTimeString());
        return;
      }

      throw new Error('No se pudo conectar a ninguna API');

    } catch (error) {
      console.error('Error fetching metrics:', error);
      setConnectionStatus('disconnected');
    }
  };

  // Efecto para obtener métricas cada 2 segundos
  useEffect(() => {
    fetchMetrics(); // Carga inicial
    
    const interval = setInterval(fetchMetrics, 2000);
    
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="App">
      <header className="header">
        <div className="container">
          <h1>🖥️ Sistema de Monitoreo - SO1 Fase 2</h1>
          <p>Bismarck Romero - 201708880</p>
          <div className="connection-status">
            <span className={`status-indicator ${connectionStatus}`}></span>
            Estado: {connectionStatus === 'connected' ? 'Conectado' : 
                     connectionStatus === 'connecting' ? 'Conectando...' : 'Desconectado'}
            {lastUpdate && (
              <span className="last-update"> | Última actualización: {lastUpdate}</span>
            )}
          </div>
        </div>
      </header>

      <main className="container">
        <div className="metrics-grid">
          {/* Métrica de CPU */}
          <div className="metric-card">
            <h3>🔥 Uso de CPU</h3>
            <div className="metric-value">
              {metrics.cpu.porcentaje_uso.toFixed(1)}%
            </div>
            <div className="progress-bar">
              <div 
                className="progress-fill cpu"
                style={{ width: `${metrics.cpu.porcentaje_uso}%` }}
              ></div>
            </div>
          </div>

          {/* Métrica de RAM */}
          <div className="metric-card">
            <h3>💾 Uso de RAM</h3>
            <div className="metric-value">
              {metrics.ram.porcentaje_uso.toFixed(1)}%
            </div>
            <div className="metric-details">
              Total: {metrics.ram.total_gb.toFixed(1)} GB<br/>
              Libre: {metrics.ram.libre_gb.toFixed(1)} GB
            </div>
            <div className="progress-bar">
              <div 
                className="progress-fill ram"
                style={{ width: `${metrics.ram.porcentaje_uso}%` }}
              ></div>
            </div>
          </div>

          {/* Métrica de Procesos */}
          <div className="metric-card">
            <h3>⚙️ Procesos del Sistema</h3>
            <div className="metric-value">
              {metrics.procesos.total_procesos}
            </div>
            <div className="metric-details">
              Ejecutándose: {metrics.procesos.procesos_corriendo}<br/>
              Total: {metrics.procesos.total_procesos}
            </div>
          </div>
        </div>

        {/* Información de configuración */}
        <div className="config-info">
          <h3>🔧 Configuración de APIs</h3>
          <div className="config-grid">
            <div>
              <strong>API Node.js:</strong> {API_BASE}
            </div>
            <div>
              <strong>API Python:</strong> {API_PYTHON}
            </div>
            <div>
              <strong>WebSocket:</strong> {WEBSOCKET_URL}
            </div>
          </div>
        </div>
      </main>

      <footer className="footer">
        <div className="container">
          <p>Sistemas Operativos 1 - Universidad de San Carlos de Guatemala</p>
          <p>Frontend React desplegado en Docker - Conectando con APIs en Kubernetes</p>
        </div>
      </footer>
    </div>
  );
}

export default App;
EOF
    
    cat > src/App.css << 'EOF'
.App {
  min-height: 100vh;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
}

.header {
  background: rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(10px);
  padding: 20px 0;
  border-bottom: 1px solid rgba(255, 255, 255, 0.2);
  margin-bottom: 30px;
}

.header h1 {
  font-size: 2.5em;
  margin-bottom: 10px;
  text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
}

.header p {
  font-size: 1.2em;
  opacity: 0.9;
  margin-bottom: 15px;
}

.connection-status {
  display: flex;
  align-items: center;
  font-size: 1.1em;
  font-weight: bold;
}

.status-indicator {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  margin-right: 10px;
  animation: pulse 2s infinite;
}

.status-indicator.connected {
  background-color: #4CAF50;
}

.status-indicator.connecting {
  background-color: #FF9800;
}

.status-indicator.disconnected {
  background-color: #f44336;
}

.last-update {
  margin-left: 20px;
  opacity: 0.8;
  font-weight: normal;
}

.metrics-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 25px;
  margin-bottom: 40px;
}

.metric-card {
  background: rgba(255, 255, 255, 0.15);
  backdrop-filter: blur(10px);
  border-radius: 15px;
  padding: 25px;
  box-shadow: 0 8px 32px rgba(0,0,0,0.1);
  border: 1px solid rgba(255, 255, 255, 0.2);
  transition: transform 0.3s ease, box-shadow 0.3s ease;
}

.metric-card:hover {
  transform: translateY(-5px);
  box-shadow: 0 15px 45px rgba(0,0,0,0.2);
}

.metric-card h3 {
  font-size: 1.3em;
  margin-bottom: 15px;
  text-align: center;
  border-bottom: 1px solid rgba(255, 255, 255, 0.3);
  padding-bottom: 10px;
}

.metric-value {
  font-size: 3em;
  font-weight: bold;
  text-align: center;
  margin: 20px 0;
  text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
}

.metric-details {
  text-align: center;
  opacity: 0.9;
  margin-bottom: 15px;
  line-height: 1.5;
}

.progress-bar {
  width: 100%;
  height: 10px;
  background: rgba(255, 255, 255, 0.2);
  border-radius: 5px;
  overflow: hidden;
  margin-top: 15px;
}

.progress-fill {
  height: 100%;
  border-radius: 5px;
  transition: width 0.5s ease;
}

.progress-fill.cpu {
  background: linear-gradient(90deg, #4CAF50, #FF9800, #f44336);
}

.progress-fill.ram {
  background: linear-gradient(90deg, #2196F3, #9C27B0);
}

.config-info {
  background: rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(10px);
  border-radius: 15px;
  padding: 25px;
  margin-bottom: 30px;
  border: 1px solid rgba(255, 255, 255, 0.2);
}

.config-info h3 {
  text-align: center;
  margin-bottom: 20px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.3);
  padding-bottom: 10px;
}

.config-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 15px;
  text-align: center;
}

.config-grid div {
  background: rgba(255, 255, 255, 0.1);
  padding: 10px;
  border-radius: 8px;
  border: 1px solid rgba(255, 255, 255, 0.2);
}

.footer {
  background: rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(10px);
  border-top: 1px solid rgba(255, 255, 255, 0.2);
  padding: 20px 0;
  text-align: center;
  margin-top: 50px;
}

.footer p {
  margin: 5px 0;
  opacity: 0.8;
}

@keyframes pulse {
  0% {
    box-shadow: 0 0 0 0 rgba(255, 255, 255, 0.7);
  }
  70% {
    box-shadow: 0 0 0 10px rgba(255, 255, 255, 0);
  }
  100% {
    box-shadow: 0 0 0 0 rgba(255, 255, 255, 0);
  }
}

/* Responsive design */
@media (max-width: 768px) {
  .header h1 {
    font-size: 2em;
  }
  
  .metric-value {
    font-size: 2.5em;
  }
  
  .metrics-grid {
    grid-template-columns: 1fr;
  }
  
  .config-grid {
    grid-template-columns: 1fr;
  }
}
EOF
    
    # 4. Crear Dockerfile
    echo -e "${YELLOW}  → Creando Dockerfile...${NC}"
    cat > Dockerfile << 'EOF'
# Etapa 1: Construir la aplicación React
FROM node:18-alpine AS build

WORKDIR /app

# Copiar archivos de dependencias primero (mejor cache de Docker)
COPY package*.json ./

# Instalar dependencias
RUN npm ci --only=production

# Copiar el resto del código fuente
COPY . .

# Construir la aplicación React para producción
RUN npm run build

# Etapa 2: Servidor Nginx para servir la aplicación
FROM nginx:alpine

# Remover la configuración por defecto de Nginx
RUN rm /etc/nginx/conf.d/default.conf

# Copiar la configuración personalizada de Nginx
COPY nginx.conf /etc/nginx/nginx.conf

# Copiar los archivos construidos de React desde la etapa anterior
COPY --from=build /app/build /usr/share/nginx/html

# Crear un endpoint de health check
RUN echo '{"status":"healthy","service":"frontend-fase2","timestamp":"'$(date -Iseconds)'"}' > /usr/share/nginx/html/health

# Exponer puerto 80
EXPOSE 80

# Iniciar Nginx
CMD ["nginx", "-g", "daemon off;"]
EOF
    
    # 5. Crear nginx.conf
    echo -e "${YELLOW}  → Creando nginx.conf...${NC}"
    cat > nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    # Configuración de logs
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;

    # Configuraciones de rendimiento
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    # Compresión
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    server {
        listen 80;
        server_name localhost;
        root /usr/share/nginx/html;
        index index.html index.htm;

        # Configuración para React Router (SPA)
        location / {
            try_files $uri $uri/ /index.html;
            
            # Headers para archivos estáticos
            location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
                expires 1y;
                add_header Cache-Control "public, immutable";
            }
        }

        # Health check endpoint
        location /health {
            access_log off;
            return 200 '{"status":"healthy","service":"frontend-fase2","timestamp":"$time_iso8601"}';
            add_header Content-Type application/json;
        }

        # Proxy para API Node.js (si las APIs están en Kubernetes)
        location /api {
            # Intentar conectar con diferentes puertos comunes de Minikube
            proxy_pass http://192.168.49.1:30001;  # Puerto típico de NodePort
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # Configuración de timeouts
            proxy_connect_timeout 5s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
            
            # Manejo de errores
            proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
        }

        # Proxy para API Python
        location /api-python {
            proxy_pass http://192.168.49.1:30002;  # Puerto típico de NodePort
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            proxy_connect_timeout 5s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
            
            proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
        }

        # Proxy para WebSocket API
        location /websocket {
            proxy_pass http://192.168.49.1:30003;  # Puerto típico de NodePort
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            proxy_connect_timeout 5s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }

        # Página de error personalizada
        error_page 404 /index.html;
        error_page 500 502 503 504 /50x.html;
        
        location = /50x.html {
            root /usr/share/nginx/html;
        }
    }
}
EOF
    
    # 6. Crear .env
    echo -e "${YELLOW}  → Creando .env...${NC}"
    cat > .env << 'EOF'
# Configuración para Frontend en Docker
REACT_APP_API_URL=/api
REACT_APP_API_PYTHON_URL=/api-python
REACT_APP_WEBSOCKET_URL=/websocket

# Puerto interno del contenedor
PORT=80

# Configuración de build
GENERATE_SOURCEMAP=false
WDS_SOCKET_PORT=0
FAST_REFRESH=false
EOF
    
    # 7. Crear .gitignore
    echo -e "${YELLOW}  → Creando .gitignore...${NC}"
    cat > .gitignore << 'EOF'
# Dependencies
node_modules/
/.pnp
.pnp.js

# Testing
/coverage

# Production
/build

# Misc
.DS_Store
.env.local
.env.development.local
.env.test.local
.env.production.local

# Logs
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# IDE
.vscode/
.idea/

# OS
Thumbs.db
EOF
    
    echo -e "${GREEN}✓ Estructura del proyecto React creada automáticamente${NC}"
    cd ..
}

# Configurar variables de entorno para Docker
configure_environment() {
    echo -e "${YELLOW}Configurando variables de entorno para Docker...${NC}"
    
    cd Frontend
    
    # Crear backup del .env original si existe
    if [ -f ".env" ] && [ ! -f ".env.backup" ]; then
        echo -e "${YELLOW}  → Creando backup de .env original...${NC}"
        cp .env .env.backup
    fi
    
    # Función para obtener puerto con fallback robusto
    get_service_port() {
        local service_name="$1"
        local default_port="$2"
        local namespace="${3:-so1-fase2}"
        
        echo -e "${BLUE}    Consultando puerto para $service_name...${NC}"
        
        # Intentar obtener puerto del servicio de Kubernetes
        local port=$(kubectl get service "$service_name" -n "$namespace" -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
        
        # Verificar que el puerto no esté vacío, sea null, o sea inválido
        if [ -z "$port" ] || [ "$port" = "null" ] || [ "$port" = "<no value>" ] || ! [[ "$port" =~ ^[0-9]+$ ]]; then
            echo -e "${YELLOW}      Puerto no disponible, usando puerto por defecto: $default_port${NC}"
            echo "$default_port"
        else
            echo -e "${GREEN}      Puerto detectado: $port${NC}"
            echo "$port"
        fi
    }
    
    # Obtener IP de Minikube
    MINIKUBE_IP=$(minikube ip 2>/dev/null)
    if [ -z "$MINIKUBE_IP" ] || [ "$MINIKUBE_IP" = "<no value>" ]; then
        MINIKUBE_IP="192.168.49.2"
        echo -e "${YELLOW}  → IP de Minikube no disponible, usando IP por defecto: $MINIKUBE_IP${NC}"
    else
        echo -e "${GREEN}  → IP de Minikube detectada: $MINIKUBE_IP${NC}"
    fi
    
    # Obtener puertos con manejo robusto de errores
    echo -e "${BLUE}  → Detectando puertos de servicios...${NC}"
    
    NODEJS_PORT=$(get_service_port "api-nodejs-service" "30001")
    PYTHON_PORT=$(get_service_port "api-python-service" "30002")
    WEBSOCKET_PORT=$(get_service_port "websocket-api-service" "30003")
    
    echo -e "${BLUE}  Configuración final:${NC}"
    echo -e "${BLUE}    Minikube IP: $MINIKUBE_IP${NC}"
    echo -e "${BLUE}    API Node.js Port: $NODEJS_PORT${NC}"
    echo -e "${BLUE}    API Python Port: $PYTHON_PORT${NC}"
    echo -e "${BLUE}    WebSocket Port: $WEBSOCKET_PORT${NC}"
    
    # Actualizar nginx.conf de forma más robusta
    if [ -f "nginx.conf" ]; then
        echo -e "${YELLOW}  → Actualizando nginx.conf con puertos reales...${NC}"
        
        # Crear archivo temporal para edición segura
        cp nginx.conf nginx.conf.backup
        
        # Usar sed con delimitadores diferentes para evitar problemas con /
        sed "s|proxy_pass http://192.168.49.1:30001;|proxy_pass http://$MINIKUBE_IP:$NODEJS_PORT;|g" nginx.conf.backup > nginx.conf.tmp
        sed "s|proxy_pass http://192.168.49.1:30002;|proxy_pass http://$MINIKUBE_IP:$PYTHON_PORT;|g" nginx.conf.tmp > nginx.conf.tmp2
        sed "s|proxy_pass http://192.168.49.1:30003;|proxy_pass http://$MINIKUBE_IP:$WEBSOCKET_PORT;|g" nginx.conf.tmp2 > nginx.conf
        
        # Limpiar archivos temporales
        rm -f nginx.conf.tmp nginx.conf.tmp2
        
        echo -e "${GREEN}    ✓ nginx.conf actualizado${NC}"
    else
        echo -e "${YELLOW}  ⚠ nginx.conf no encontrado, se usará configuración por defecto${NC}"
    fi
    
    # Actualizar .env con configuración final
    cat > .env << EOF
# Configuración para Frontend en Docker
REACT_APP_API_URL=/api
REACT_APP_API_PYTHON_URL=/api-python
REACT_APP_WEBSOCKET_URL=/websocket

# Configuración de conexión (para referencia)
MINIKUBE_IP=$MINIKUBE_IP
NODEJS_PORT=$NODEJS_PORT
PYTHON_PORT=$PYTHON_PORT
WEBSOCKET_PORT=$WEBSOCKET_PORT

# Puerto interno del contenedor
PORT=80

# Configuración de build
GENERATE_SOURCEMAP=false
WDS_SOCKET_PORT=0
FAST_REFRESH=false
EOF
    
    echo -e "${GREEN}✓ Variables de entorno configuradas correctamente${NC}"
    cd ..
}

# Instalar dependencias de React
install_react_dependencies() {
    echo -e "${YELLOW}Instalando dependencias de React...${NC}"
    
    cd Frontend
    
    # Limpiar package-lock.json conflictivo si existe
    if [ -f "package-lock.json" ]; then
        echo -e "${YELLOW}  → Eliminando package-lock.json para evitar conflictos...${NC}"
        rm -f package-lock.json
    fi
    
    # Limpiar node_modules si hay problemas
    if [ -d "node_modules" ]; then
        echo -e "${YELLOW}  → Limpiando node_modules existente...${NC}"
        rm -rf node_modules
    fi
    
    # Limpiar caché de npm
    npm cache clean --force 2>/dev/null || true
    
    echo -e "${YELLOW}  → Instalando dependencias con npm...${NC}"
    
    # Instalar dependencias con configuración más permisiva
    npm install --no-audit --no-fund --legacy-peer-deps
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al instalar dependencias de React${NC}"
        echo -e "${YELLOW}Intentando instalación alternativa...${NC}"
        
        # Intento más agresivo con force
        npm install --force --no-audit --no-fund
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}Error persistente al instalar dependencias${NC}"
            echo -e "${YELLOW}Verifica que Node.js y npm estén actualizados${NC}"
            exit 1
        fi
    fi
    
    echo -e "${GREEN}  ✓ Dependencias instaladas correctamente${NC}"
    cd ..
}

# Verificar y probar compilación de React
verify_react_build() {
    echo -e "${YELLOW}Verificando compilación de React...${NC}"
    
    cd Frontend
    
    # Verificar que las dependencias están instaladas
    if [ ! -d "node_modules" ]; then
        echo -e "${RED}Error: node_modules no encontrado. Ejecutando instalación...${NC}"
        install_react_dependencies
    fi
    
    # Probar compilación
    echo -e "${YELLOW}  → Probando compilación de React (npm run build)...${NC}"
    
    # Limpiar build anterior si existe
    if [ -d "build" ]; then
        echo -e "${YELLOW}  → Limpiando build anterior...${NC}"
        rm -rf build/
    fi
    
    # Ejecutar build
    npm run build
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error en la compilación de React${NC}"
        echo -e "${YELLOW}Revisa los errores anteriores y corrige el código React${NC}"
        exit 1
    fi
    
    # Verificar que el build se creó correctamente
    if [ ! -d "build" ]; then
        echo -e "${RED}Error: Directorio build/ no se creó${NC}"
        exit 1
    fi
    
    if [ ! -f "build/index.html" ]; then
        echo -e "${RED}Error: build/index.html no se generó${NC}"
        exit 1
    fi
    
    # Verificar tamaño del build
    BUILD_SIZE=$(du -sh build/ | cut -f1)
    echo -e "${GREEN}  ✓ Build de React generado correctamente (tamaño: $BUILD_SIZE)${NC}"
    
    # Verificar contenido del build
    echo -e "${YELLOW}  → Verificando contenido del build...${NC}"
    if ls build/static/js/*.js &> /dev/null; then
        JS_FILES=$(ls build/static/js/*.js | wc -l)
        echo -e "${GREEN}  ✓ Archivos JavaScript generados: $JS_FILES${NC}"
    fi
    
    if ls build/static/css/*.css &> /dev/null; then
        CSS_FILES=$(ls build/static/css/*.css | wc -l)
        echo -e "${GREEN}  ✓ Archivos CSS generados: $CSS_FILES${NC}"
    fi
    
    echo -e "${GREEN}✓ Compilación de React verificada exitosamente${NC}"
    cd ..
}

# Construir imagen Docker del Frontend
build_frontend_image() {
    echo -e "${YELLOW}Construyendo imagen Docker del Frontend...${NC}"
    
    cd Frontend
    
    # Verificar que el build existe
    if [ ! -d "build" ]; then
        echo -e "${YELLOW}⚠ Directorio build/ no encontrado, construyendo React app...${NC}"
        verify_react_build
    fi
    
    # Verificar archivos esenciales para Docker
    required_files=("Dockerfile" "package.json" "src/App.js" "public/index.html" "nginx.conf")
    missing_files=()
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        echo -e "${RED}Error: Archivos faltantes para construcción Docker:${NC}"
        printf '%s\n' "${missing_files[@]}"
        exit 1
    fi
    
    # Mostrar información del build antes de dockerizar
    echo -e "${YELLOW}  → Información del build a dockerizar:${NC}"
    echo -e "${BLUE}    Build size: $(du -sh build/ | cut -f1)${NC}"
    echo -e "${BLUE}    Files count: $(find build/ -type f | wc -l)${NC}"
    echo -e "${BLUE}    Dockerfile: $([ -f Dockerfile ] && echo "✓ Presente" || echo "✗ Faltante")${NC}"
    echo -e "${BLUE}    nginx.conf: $([ -f nginx.conf ] && echo "✓ Presente" || echo "✗ Faltante")${NC}"
    
    # Mostrar las primeras líneas del Dockerfile para verificación
    echo -e "${YELLOW}  → Verificando Dockerfile:${NC}"
    head -5 Dockerfile | sed 's/^/    /'
    
    # Limpiar imagen anterior si existe
    echo -e "${YELLOW}  → Limpiando imagen anterior...${NC}"
    docker rmi bismarckr/frontend-fase2:latest 2>/dev/null || true
    
    # Construir imagen Docker con tu Dockerfile
    echo -e "${YELLOW}  → Ejecutando: docker build -t bismarckr/frontend-fase2:latest .${NC}"
    
    # Construir con output más detallado
    docker build -t bismarckr/frontend-fase2:latest . 2>&1 | tee /tmp/docker_build_frontend.log
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo -e "${GREEN}✓ Imagen Docker del Frontend construida exitosamente${NC}"
        
        # Mostrar información de la imagen
        IMAGE_INFO=$(docker images bismarckr/frontend-fase2:latest --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}" | tail -1)
        echo -e "${BLUE}  Información de la imagen: $IMAGE_INFO${NC}"
        
        # Verificar que la imagen se puede ejecutar
        echo -e "${YELLOW}  → Verificando que la imagen es ejecutable...${NC}"
        docker run --rm bismarckr/frontend-fase2:latest nginx -t 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}    ✓ Imagen válida y ejecutable${NC}"
        else
            echo -e "${YELLOW}    ⚠ Imagen construida pero puede tener problemas de configuración${NC}"
        fi
        
    else
        echo -e "${RED}✗ Error al construir la imagen Docker del Frontend${NC}"
        echo -e "${YELLOW}  → Mostrando últimas líneas del log de error:${NC}"
        tail -20 /tmp/docker_build_frontend.log | sed 's/^/    /'
        
        echo -e "${YELLOW}  → Verificando espacio en disco:${NC}"
        df -h . | sed 's/^/    /'
        
        exit 1
    fi
    
    cd ..
}


# Ejecutar contenedor del Frontend
run_frontend_container() {
    echo -e "${YELLOW}Ejecutando contenedor del Frontend...${NC}"
    
    # Detener contenedor anterior si existe
    echo -e "${YELLOW}Limpiando contenedores anteriores...${NC}"
    docker stop frontend-local 2>/dev/null || true
    docker rm frontend-local 2>/dev/null || true
    
    # Obtener IP de Minikube para conectar con las APIs
    MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "192.168.49.2")
    echo -e "${BLUE}IP de Minikube detectada: $MINIKUBE_IP${NC}"
    
    # Ejecutar contenedor con conexión a Minikube
    echo -e "${YELLOW}Iniciando contenedor del Frontend...${NC}"
    docker run -d \
        --name frontend-local \
        --restart unless-stopped \
        -p 3001:80 \
        --add-host=api-nodejs-service:$MINIKUBE_IP \
        --add-host=api-python-service:$MINIKUBE_IP \
        --add-host=websocket-api-service:$MINIKUBE_IP \
        bismarckr/frontend-fase2:latest
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Contenedor del Frontend iniciado correctamente${NC}"
        
        # Esperar un momento para que el contenedor se inicie
        sleep 3
        
        # Verificar que está corriendo
        if docker ps | grep -q "frontend-local"; then
            echo -e "${GREEN}✓ Frontend ejecutándose correctamente${NC}"
        else
            echo -e "${RED}Error: El contenedor no está ejecutándose${NC}"
            echo -e "${YELLOW}Logs del contenedor:${NC}"
            docker logs frontend-local
            exit 1
        fi
    else
        echo -e "${RED}Error al iniciar el contenedor del Frontend${NC}"
        exit 1
    fi
}

# Verificar estado y mostrar información
show_status() {
    echo -e "${YELLOW}=== ESTADO DEL FRONTEND ===${NC}"
    
    # Estado del contenedor
    echo -e "${BLUE}Contenedor Docker:${NC}"
    if docker ps | grep -q "frontend-local"; then
        echo -e "${GREEN}✓ Contenedor ejecutándose${NC}"
        docker ps --filter name=frontend-local --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    else
        echo -e "${RED}✗ Contenedor no está ejecutándose${NC}"
    fi
    
    # Verificar conectividad
    echo -e "${BLUE}Verificando conectividad:${NC}"
    sleep 2
    if curl -s --connect-timeout 5 http://localhost:3001/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Frontend accesible en http://localhost:3001${NC}"
    elif curl -s --connect-timeout 5 http://localhost:3001/ > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Frontend accesible en http://localhost:3001${NC}"
        echo -e "${YELLOW}  (endpoint /health no disponible, pero la app responde)${NC}"
    else
        echo -e "${YELLOW}⚠ Frontend puede estar iniciando, intenta acceder en unos momentos${NC}"
    fi
    
    # Información del build
    if [ -d "Frontend/build" ]; then
        BUILD_SIZE=$(du -sh Frontend/build/ | cut -f1)
        echo -e "${BLUE}Build React: ${GREEN}✓ Disponible (tamaño: $BUILD_SIZE)${NC}"
    else
        echo -e "${BLUE}Build React: ${RED}✗ No disponible${NC}"
    fi
    
    # Logs recientes
    echo -e "${BLUE}Logs recientes:${NC}"
    docker logs frontend-local --tail 5 2>/dev/null || echo -e "${RED}No hay logs disponibles${NC}"
}

# Función para mostrar información de uso
show_usage() {
    echo
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    FRONTEND COMPLETADO                    ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${YELLOW}🌐 ACCESO AL FRONTEND:${NC}"
    echo -e "${GREEN}   http://localhost:3001${NC}                    # Aplicación principal"
    echo -e "${GREEN}   http://localhost:3001/health${NC}             # Health check"
    echo
    echo -e "${YELLOW}🔧 COMANDOS ÚTILES:${NC}"
    echo -e "${BLUE}  ./setup-frontend-local.sh status     ${NC}# Ver estado actual"
    echo -e "${BLUE}  ./setup-frontend-local.sh logs       ${NC}# Ver logs en tiempo real"
    echo -e "${BLUE}  ./setup-frontend-local.sh restart    ${NC}# Reiniciar contenedor"
    echo -e "${BLUE}  ./setup-frontend-local.sh rebuild    ${NC}# Reconstruir completamente"
    echo
    echo -e "${YELLOW}📱 DESARROLLO LOCAL:${NC}"
    echo -e "${BLUE}  cd Frontend && npm start             ${NC}# Servidor desarrollo (puerto 3000)"
    echo -e "${BLUE}  cd Frontend && npm run build         ${NC}# Solo compilar React"
    echo
    echo -e "${YELLOW}🐳 DOCKER:${NC}"
    echo -e "${BLUE}  docker logs frontend-local           ${NC}# Ver logs del contenedor"
    echo -e "${BLUE}  docker exec -it frontend-local sh    ${NC}# Acceder al contenedor"
    echo -e "${BLUE}  docker restart frontend-local        ${NC}# Reiniciar manualmente"
    echo
}

# Función principal
main() {
    case "${1:-install}" in
        "install"|"")
            echo -e "${YELLOW}=== CREACIÓN E INSTALACIÓN AUTOMÁTICA DEL FRONTEND ===${NC}"
            check_nodejs
            check_docker
            create_react_structure          # NUEVO: Crear estructura automáticamente
            configure_environment
            install_react_dependencies
            verify_react_build
            build_frontend_image
            run_frontend_container
            show_status
            show_usage
            ;;
        "create")
            echo -e "${YELLOW}Solo creando estructura del proyecto...${NC}"
            check_nodejs
            create_react_structure
            echo -e "${GREEN}✓ Estructura creada. Ejecuta './setup-frontend-local.sh install' para continuar${NC}"
            ;;
        "start")
            echo -e "${YELLOW}Iniciando contenedor del Frontend...${NC}"
            docker start frontend-local
            sleep 2
            show_status
            ;;
        "stop")
            echo -e "${YELLOW}Deteniendo contenedor del Frontend...${NC}"
            docker stop frontend-local
            echo -e "${GREEN}✓ Frontend detenido${NC}"
            ;;
        "restart")
            echo -e "${YELLOW}Reiniciando contenedor del Frontend...${NC}"
            docker restart frontend-local
            sleep 3
            show_status
            ;;
        "status")
            show_status
            ;;
        "logs")
            echo -e "${YELLOW}Mostrando logs en tiempo real (Ctrl+C para salir)...${NC}"
            docker logs -f frontend-local
            ;;
        "rebuild")
            echo -e "${YELLOW}Reconstruyendo imagen y reiniciando...${NC}"
            docker stop frontend-local 2>/dev/null || true
            docker rm frontend-local 2>/dev/null || true
            docker rmi bismarckr/frontend-fase2:latest 2>/dev/null || true
            configure_environment
            verify_react_build
            build_frontend_image
            run_frontend_container
            show_status
            ;;
        "build-only")
            echo -e "${YELLOW}Solo construyendo la aplicación React...${NC}"
            check_nodejs
            if [ ! -d "Frontend/src" ]; then
                create_react_structure
            fi
            configure_environment
            install_react_dependencies
            verify_react_build
            echo -e "${GREEN}✓ Build de React completado${NC}"
            ;;
        *)
            echo -e "${RED}Comando no reconocido: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
}

echo
# Ejecutar función principal
main "$@"

echo
echo -e "${GREEN}🎉 Frontend React con Docker configurado automáticamente!${NC}"