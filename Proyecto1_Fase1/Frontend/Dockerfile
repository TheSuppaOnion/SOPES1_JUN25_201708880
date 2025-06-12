FROM golang:1.24-alpine AS builder

WORKDIR /app

# Copiar el código fuente
COPY . .

# Inicializar módulo Go y agregar dependencias automáticamente
RUN go mod init monitor-frontend && \
    go get github.com/gofiber/fiber/v2 && \
    go get github.com/gofiber/template/html/v2 && \
    go mod tidy

# Compilar la aplicación
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/monitor-frontend

# Crear una imagen mínima
FROM alpine:3.15

WORKDIR /app

# Copiar ejecutable desde la etapa de compilación
COPY --from=builder /app/monitor-frontend .

# Copiar vistas y archivos estáticos
COPY --from=builder /app/views ./views
COPY --from=builder /app/static ./static

# Variable de entorno para la URL de la API
ENV API_URL=http://api:3000

# Exponer puerto
EXPOSE 8080

# Comando para ejecutar la aplicación
CMD ["/app/monitor-frontend"]