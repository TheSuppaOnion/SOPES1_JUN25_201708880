# Build stage
FROM node:18-alpine AS build
WORKDIR /app
COPY package*.json ./
COPY .env ./
RUN npm install --silent
COPY . .
RUN npm run build

# Production stage
FROM node:18-alpine
WORKDIR /app
RUN npm install -g serve
COPY --from=build /app/build /app/build
EXPOSE 8080
CMD ["serve", "-s", "build", "-l", "8080"]