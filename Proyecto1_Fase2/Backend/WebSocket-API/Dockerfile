FROM node:18-alpine

WORKDIR /app

# Copiar package.json primero
COPY package.json ./

# Generar package-lock.json si no existe y instalar dependencias
RUN npm install --package-lock-only && \
    npm ci --only=production

# Copiar resto del código
COPY . .

# Exponer puerto
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:4000/health || exit 1

# Usuario no root
RUN addgroup -g 1001 -S nodejs && \
    adduser -S websocket -u 1001
USER websocket

CMD ["node", "index.js"]