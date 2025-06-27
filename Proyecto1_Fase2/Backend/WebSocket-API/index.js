const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const mysql = require('mysql2/promise');
const cors = require('cors');
require('dotenv').config();

// Configuración
const PORT = process.env.PORT || 4000;
const app = express();
const server = http.createServer(app);

// Configurar Socket.IO con CORS
const io = socketIo(server, {
  cors: {
    origin: ["http://localhost:8080", "http://localhost:3001", "*"],
    methods: ["GET", "POST"],
    credentials: true
  }
});

// Middleware
app.use(cors());
app.use(express.json());

// Configuración de base de datos para MySQL local
const dbConfig = {
  host: process.env.DB_HOST || '192.168.49.1', // IP del host desde Minikube
  port: process.env.DB_PORT || 3306,
  user: process.env.DB_USER || 'monitor',
  password: process.env.DB_PASSWORD || 'monitor123',
  database: process.env.DB_NAME || 'monitoring',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
};

// Pool de conexiones
let pool;

async function initializeDatabase() {
  try {
    pool = mysql.createPool(dbConfig);
    console.log('Pool de conexiones MySQL creado');
    
    // Probar conexión
    const connection = await pool.getConnection();
    await connection.ping();
    connection.release();
    console.log('✓ Conexión a base de datos exitosa');
    
    return true;
  } catch (error) {
    console.error('X Error conectando a base de datos:', error);
    return false;
  }
}

// FUNCIÓN PRINCIPAL: Obtener últimas métricas de la BD
async function getLatestMetrics() {
  try {
    // Obtener el registro más reciente de la tabla metrics
    const [rows] = await pool.execute(
      'SELECT * FROM metrics ORDER BY timestamp DESC LIMIT 1'
    );

    if (rows.length === 0) {
      return {
        cpu: { porcentaje_uso: 0 },
        ram: { porcentaje_uso: 0, total_gb: 0, libre_gb: 0 },
        procesos: { total_procesos: 0, procesos_corriendo: 0 }
      };
    }

    const latest = rows[0];

    // Transformar datos para el frontend
    return {
      timestamp: Date.now(),
      cpu: {
        porcentaje_uso: parseFloat(latest.porcentaje_cpu_uso) || 0,
        porcentaje_libre: parseFloat(latest.porcentaje_cpu_libre) || 0
      },
      ram: {
        total: latest.total_ram || 0,
        libre: latest.ram_libre || 0,
        uso: latest.uso_ram || 0,
        porcentaje_uso: parseFloat(latest.porcentaje_ram) || 0,
        total_gb: Math.round((latest.total_ram || 0) / 1024 * 100) / 100,
        libre_gb: Math.round((latest.ram_libre || 0) / (1024 * 1024 * 1024) * 100) / 100
      },
      procesos: {
        total_procesos: latest.total_procesos || 0,
        procesos_corriendo: latest.procesos_corriendo || 0,
        procesos_durmiendo: latest.procesos_durmiendo || 0,
        procesos_zombie: latest.procesos_zombie || 0,
        procesos_parados: latest.procesos_parados || 0
      },
      api_source: latest.api_source,
      last_update: latest.hora,
      formatted_time: new Date().toLocaleString('es-GT', {
        timeZone: 'America/Guatemala'
      })
    };
  } catch (error) {
    console.error('X Error obteniendo métricas:', error);
    return null;
  }
}

// Obtener datos históricos de los últimos X minutos
async function getHistoricalData(minutes = 30) {
  try {
    const timeLimit = new Date(Date.now() - (minutes * 60 * 1000));
    
    const [rows] = await pool.execute(
      `SELECT 
         timestamp, porcentaje_cpu_uso, porcentaje_ram, 
         total_ram, uso_ram, total_procesos, api_source
       FROM metrics 
       WHERE timestamp >= ? 
       ORDER BY timestamp ASC`,
      [timeLimit]
    );

    return {
      cpu: rows.map(row => ({
        timestamp: new Date(row.timestamp).getTime(),
        value: parseFloat(row.porcentaje_cpu_uso) || 0,
        time: new Date(row.timestamp).toLocaleTimeString(),
        api_source: row.api_source
      })),
      ram: rows.map(row => ({
        timestamp: new Date(row.timestamp).getTime(),
        percentage: parseFloat(row.porcentaje_ram) || 0,
        usage_gb: Math.round((row.uso_ram || 0) / 1024 * 100) / 100,
        total_gb: Math.round((row.total_ram || 0) / 1024 * 100) / 100,
        time: new Date(row.timestamp).toLocaleTimeString(),
        api_source: row.api_source
      })),
      total_records: rows.length,
      time_range: `${minutes} minutos`
    };
  } catch (error) {
    console.error('X Error obteniendo datos históricos:', error);
    return { cpu: [], ram: [], total_records: 0 };
  }
}

// Obtener estadísticas del sistema
async function getSystemStats() {
  try {
    // Estadísticas de las últimas 24 horas
    const last24h = new Date(Date.now() - (24 * 60 * 60 * 1000));
    
    const [stats] = await pool.execute(
      `SELECT 
         AVG(porcentaje_cpu_uso) as avg_cpu,
         MAX(porcentaje_cpu_uso) as max_cpu,
         MIN(porcentaje_cpu_uso) as min_cpu,
         AVG(porcentaje_ram) as avg_ram,
         MAX(porcentaje_ram) as max_ram,
         MIN(porcentaje_ram) as min_ram,
         COUNT(*) as samples,
         COUNT(DISTINCT api_source) as api_sources
       FROM metrics 
       WHERE timestamp >= ?`,
      [last24h]
    );

    const [totalRecords] = await pool.execute(
      'SELECT COUNT(*) as total FROM metrics'
    );

    const [apiDistribution] = await pool.execute(
      `SELECT api_source, COUNT(*) as count 
       FROM metrics 
       WHERE timestamp >= ? 
       GROUP BY api_source`,
      [last24h]
    );

    return {
      cpu: {
        avg: Math.round((stats[0]?.avg_cpu || 0) * 100) / 100,
        max: Math.round((stats[0]?.max_cpu || 0) * 100) / 100,
        min: Math.round((stats[0]?.min_cpu || 0) * 100) / 100
      },
      ram: {
        avg: Math.round((stats[0]?.avg_ram || 0) * 100) / 100,
        max: Math.round((stats[0]?.max_ram || 0) * 100) / 100,
        min: Math.round((stats[0]?.min_ram || 0) * 100) / 100
      },
      samples_24h: stats[0]?.samples || 0,
      total_records: totalRecords[0]?.total || 0,
      api_distribution: apiDistribution,
      period: '24h'
    };
  } catch (error) {
    console.error('X Error obteniendo estadísticas:', error);
    return null;
  }
}

// Eventos de Socket.IO
io.on('connection', (socket) => {
  console.log(`✓ Cliente conectado: ${socket.id}`);

  // Enviar bienvenida y métricas iniciales
  socket.emit('welcome', {
    message: 'Conectado al sistema de monitoreo WebSocket',
    timestamp: Date.now(),
    client_id: socket.id
  });

  // Enviar métricas actuales inmediatamente
  getLatestMetrics().then(metrics => {
    if (metrics) {
      socket.emit('metrics_update', metrics);
    }
  });

  // Cliente solicita métricas en tiempo real
  socket.on('request_metrics', async () => {
    const metrics = await getLatestMetrics();
    if (metrics) {
      socket.emit('metrics_update', metrics);
    } else {
      socket.emit('error', { message: 'No hay datos disponibles' });
    }
  });

  // Cliente solicita datos históricos
  socket.on('request_historical', async (data) => {
    const minutes = data?.minutes || 30;
    const historical = await getHistoricalData(minutes);
    socket.emit('historical_data', historical);
  });

  // Cliente solicita estadísticas
  socket.on('request_stats', async () => {
    const stats = await getSystemStats();
    if (stats) {
      socket.emit('system_stats', stats);
    }
  });

  // Cliente se desconecta
  socket.on('disconnect', () => {
    console.log(`X Cliente desconectado: ${socket.id}`);
  });

  // Manejo de errores del socket
  socket.on('error', (error) => {
    console.error(`X Error en socket ${socket.id}:`, error);
  });
});

// BROADCAST AUTOMÁTICO: Enviar métricas actualizadas cada X segundos
let broadcastInterval;

function startMetricsBroadcast(intervalSeconds = 2) {
  broadcastInterval = setInterval(async () => {
    const connectedClients = io.engine.clientsCount;
    
    if (connectedClients > 0) {
      const metrics = await getLatestMetrics();
      if (metrics) {
        io.emit('metrics_update', metrics);
        console.log(`✓ Métricas enviadas a ${connectedClients} cliente(s) - CPU: ${metrics.cpu.porcentaje_uso}%, RAM: ${metrics.ram.porcentaje_uso}%`);
      }
    }
  }, intervalSeconds * 1000);
  
  console.log(`✓ Broadcast automático iniciado cada ${intervalSeconds}s`);
}

function stopMetricsBroadcast() {
  if (broadcastInterval) {
    clearInterval(broadcastInterval);
    console.log('X Broadcast automático detenido');
  }
}

// API REST endpoints para health check y debug
app.get('/health', async (req, res) => {
  try {
    const connection = await pool.getConnection();
    await connection.ping();
    connection.release();
    
    res.json({
      status: 'healthy',
      service: 'WebSocket API - Data Reader',
      timestamp: new Date().toISOString(),
      connected_clients: io.engine.clientsCount,
      database: 'connected',
      role: 'Leer datos de BD y transmitir via WebSocket'
    });
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      service: 'WebSocket API',
      error: error.message,
      database: 'disconnected'
    });
  }
});

app.get('/clients', (req, res) => {
  res.json({
    connected_clients: io.engine.clientsCount,
    timestamp: new Date().toISOString()
  });
});

// Endpoint para probar métricas vía REST
app.get('/api/metrics', async (req, res) => {
  try {
    const metrics = await getLatestMetrics();
    if (metrics) {
      res.json(metrics);
    } else {
      res.status(404).json({ error: 'No hay métricas disponibles' });
    }
  } catch (error) {
    res.status(500).json({ error: 'Error obteniendo métricas' });
  }
});

app.get('/', (req, res) => {
  res.json({
    service: 'Sistema de Monitoreo - WebSocket API',
    version: '2.0.0',
    author: 'Bismarck Romero - 201708880',
    description: 'API WebSocket para transmisión de métricas en tiempo real',
    role: 'Leer datos de BD (insertados por API Node.js/Python) y transmitir al Frontend',
    api_type: 'WebSocket/Socket.IO',
    endpoints: {
      websocket: `ws://localhost:${PORT}`,
      health: 'GET /health',
      clients: 'GET /clients',
      metrics: 'GET /api/metrics'
    },
    socket_events: {
      outgoing: ['welcome', 'metrics_update', 'historical_data', 'system_stats', 'error'],
      incoming: ['request_metrics', 'request_historical', 'request_stats']
    },
    data_flow: 'BD → WebSocket API → Frontend (tiempo real)'
  });
});

// Inicializar servidor
async function startServer() {
  console.log('Iniciando WebSocket API - Lector de BD...');
  
  // Inicializar base de datos
  const dbConnected = await initializeDatabase();
  if (!dbConnected) {
    console.error('X No se pudo conectar a la base de datos. Saliendo...');
    process.exit(1);
  }

  // Iniciar servidor
  server.listen(PORT, '0.0.0.0', () => {
    console.log(`✓ WebSocket API ejecutándose en puerto ${PORT}`);
    console.log(`✓ Socket.IO: ws://localhost:${PORT}`);
    console.log(`✓ Health check: http://localhost:${PORT}/health`);
    console.log('✓ Función: Leer datos de BD y transmitir al frontend');
    
    // Iniciar broadcast automático de métricas
    startMetricsBroadcast(2); // Cada 2 segundos
  });
}

// Manejo de señales para cierre limpio
process.on('SIGTERM', () => {
  console.log('Recibida señal SIGTERM, cerrando servidor...');
  stopMetricsBroadcast();
  server.close(() => {
    if (pool) pool.end();
    console.log('✓ Servidor cerrado correctamente');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('Recibida señal SIGINT, cerrando servidor...');
  stopMetricsBroadcast();
  server.close(() => {
    if (pool) pool.end();
    console.log('✓ Servidor cerrado correctamente');
    process.exit(0);
  });
});

// Manejo de errores no capturados
process.on('unhandledRejection', (reason, promise) => {
  console.error('X Unhandled Rejection at:', promise, 'reason:', reason);
});

process.on('uncaughtException', (error) => {
  console.error('X Uncaught Exception:', error);
  process.exit(1);
});

// Iniciar el servidor
startServer();