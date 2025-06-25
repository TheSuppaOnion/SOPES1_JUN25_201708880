FROM node:18-alpine AS build

WORKDIR /app

# Copiar package.json primero
COPY package*.json ./

# Generar package-lock.json si no existe y instalar dependencias
RUN npm install --package-lock-only && \
    npm ci --only=production

# Copiar resto del código
COPY . .

# Construir aplicación React
RUN npm run build

# Etapa de producción con Nginx
FROM nginx:alpine

# Copiar build de React
COPY --from=build /app/build /usr/share/nginx/html

# Copiar configuración de Nginx (si existe)
COPY nginx.conf /etc/nginx/nginx.conf 2>/dev/null || echo "nginx.conf no encontrado, usando configuración por defecto"

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]