FROM node:18-alpine AS build

WORKDIR /app

# Copiar archivos de dependencias
COPY package*.json ./

# Instalar dependencias
RUN npm install

# Copiar resto del código
COPY . .

# Construir aplicación React
RUN npm run build

# Etapa de producción con Nginx
FROM nginx:alpine

# Copiar build de React
COPY --from=build /app/build /usr/share/nginx/html

# Copiar configuración de Nginx si existe
COPY nginx.conf /etc/nginx/nginx.conf 2>/dev/null || echo "Usando configuración Nginx por defecto"

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]