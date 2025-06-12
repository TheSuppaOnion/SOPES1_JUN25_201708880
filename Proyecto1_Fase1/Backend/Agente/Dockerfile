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

# Variables de entorno (se sobrescribirán por docker-compose)
ENV API_URL=http://api:3000/api/data
ENV POLL_INTERVAL=5s

# Ejecutar el agente
CMD ["/agente-de-monitor"]