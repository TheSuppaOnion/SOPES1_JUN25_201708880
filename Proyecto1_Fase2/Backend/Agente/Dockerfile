FROM golang:1.24-alpine AS builder

WORKDIR /app

# Copiar el código fuente
COPY . .

# Inicializar el módulo Go si es necesario y compilar
RUN go mod init agente-monitor || true
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -o /agente-de-monitor agente-de-monitor.go

# Crear una imagen mínima
FROM alpine:3.15

WORKDIR /

# Instalar dependencias necesarias
RUN apk --no-cache add ca-certificates

# Copiar el ejecutable compilado
COPY --from=builder /agente-de-monitor /agente-de-monitor

# Exponer puerto del agente
EXPOSE 8080

# Variables de entorno por defecto
ENV AGENTE_PORT=8080
ENV POLL_INTERVAL=2s

# Comando para ejecutar el agente
CMD ["/agente-de-monitor"]