FROM golang:1.24-alpine AS builder

WORKDIR /app

# Copiar el módulo go y descargar dependencias
COPY go.mod ./
RUN go mod download

# Copiar el código fuente
COPY *.go ./

# Compilar la aplicación
RUN CGO_ENABLED=0 GOOS=linux go build -o /agente-de-monitor

# Crear una imagen mínima
FROM alpine:3.15

WORKDIR /

# Instalar dependencias necesarias para acceder a /proc
RUN apk --no-cache add ca-certificates

# Copiar el ejecutable compilado
COPY --from=builder /agente-de-monitor /agente-de-monitor

# Variables de entorno
ENV API_URL=http://nodejs-api:3000/api/data
ENV POLL_INTERVAL=5s

# Ejecutar el agente
CMD ["/agente-de-monitor"]