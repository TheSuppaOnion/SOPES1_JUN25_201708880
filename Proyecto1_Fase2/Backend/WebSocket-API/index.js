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

// Configuración de base de datos
const dbConfig = {
  host: process.env.DB_HOST || 'mysql-service',
  port: process.env.DB_PORT || 3306,
  user: process.env.DB_USER || 'monitor',
  password: process.env.DB_PASSWORD || 'monitor123',
  database: process.env.DB_NAME || 'monitoring',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  acquireTimeout: 60000,
  timeout: 60000
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
    console.log('Conexión a base de datos exitosa');
    
    return true;
  } catch (error) {
    console.error('Error conectando a base de datos:', error);
    return false;
  }
}

// Funciones para obtener métricas
async function getLatestMetrics() {
  try {
    const [cpuRows] = await pool.execute(
      'SELECT * FROM cpu_metrics ORDER BY timestamp DESC LIMIT 1'
    );
    
    const [ramRows] = await pool.execute(
      'SELECT * FROM ram_metrics ORDER BY timestamp DESC LIMIT 1'
    );
    
    const [processRows] = await pool.execute(
      'SELECT * FROM procesos_metrics ORDER BY timestamp DESC LIMIT 1'
    );

    if (cpuRows.length === 0 || ramRows.length === 0 || processRows.length === 0) {
      return null;
    }

    const cpu = cpuRows[0];
    const ram = ramRows[0];
    const processes = processRows[0];

    return {
      timestamp: Date.now(),
      cpu: {
        porcentaje_uso: cpu.porcentaje_uso,
        porcentaje_libre: 100 - cpu.porcentaje_uso
      },
      ram: {
        total: ram.total,
        libre: ram.libre,
        uso: ram.uso,
        porcentaje_uso: ram.porcentaje_uso,
        total_gb: Math.round(ram.total / (1024 * 1024 * 1024) * 100) / 100,
        uso_gb: Math.round(ram.uso / (1024 * 1024 * 1024) * 100) / 100
      },
      procesos: {
        total_processos: processes.total_processos,
        procesos_corriendo: processes.procesos_corriendo,
        procesos_durmiendo: processes.procesos_durmiendo,
        procesos_zombie: processes.procesos_zombie,
        procesos_parados: processes.procesos_parados
      },
      formatted_time: new Date().toLocaleString('es-GT', {
        timeZone: 'America/Guatemala'
      })
    };
  } catch (error) {
    console.error('Error obteniendo métricas:', error);
    return null;
  }
}

async function getHistoricalData(minutes = 30) {
  try {
    const timeLimit = Math.floor(Date.now() / 1000) - (minutes * 60);
    
    const [cpuData] = await pool.execute(
      `SELECT timestamp, porcentaje_uso 
       FROM cpu_metrics 
       WHERE timestamp > ? 
       ORDER BY timestamp ASC`,
      [timeLimit]
    );
    
    const [ramData] = await pool.execute(
      `SELECT timestamp, porcentaje_uso, total, uso 
       FROM ram_metrics 
       WHERE timestamp > ? 
       ORDER BY timestamp ASC`,
      [timeLimit]
    );

    return {
      cpu: cpuData.map(row => ({
        timestamp: row.timestamp * 1000, // Convertir a milliseconds
        value: row.porcentaje_uso,
        time: new Date(row.timestamp * 1000).toLocaleTimeString()
      })),
      ram: ramData.map(row => ({
        timestamp: row.timestamp * 1000,
        percentage: row.porcentaje_uso,
        usage_gb: Math.round(row.uso / (1024 * 1024 * 1024) * 100) / 100,
        total_gb: Math.round(row.total / (1024 * 1024 * 1024) * 100) / 100,
        time: new Date(row.timestamp * 1000).toLocaleTimeString()
      }))
    };
  } catch (error) {
    console.error('Error obteniendo datos históricos:', error);
    return { cpu: [], ram: [] };
  }
}

async function getSystemStats() {
  try {
    // Estadísticas de las últimas 24 horas
    const last24h = Math.floor(Date.now() / 1000) - (24 * 60 * 60);
    
    const [cpuStats] = await pool.execute(
      `SELECT 
         AVG(porcentaje_uso) as avg_cpu,
         MAX(porcentaje_uso) as max_cpu,
         MIN(porcentaje_uso) as min_cpu,
         COUNT(*) as samples
       FROM cpu_metrics 
       WHERE timestamp > ?`,
      [last24h]
    );
    
    const [ramStats] = await pool.execute(
      `SELECT 
         AVG(porcentaje_uso) as avg_ram,
         MAX(porcentaje_uso) as max_ram,
         MIN(porcentaje_uso) as min_ram,
         COUNT(*) as samples
       FROM ram_metrics 
       WHERE timestamp > ?`,
      [last24h]
    );

    const [totalRecords] = await pool.execute(
      'SELECT COUNT(*) as total FROM cpu_metrics'
    );

    return {
      cpu: cpuStats[0] || { avg_cpu: 0, max_cpu: 0, min_cpu: 0, samples: 0 },
      ram: ramStats[0] || { avg_ram: 0, max_ram: 0, min_ram: 0, samples: 0 },
      total_records: totalRecords[0]?.total || 0,
      period: '24h'
    };
  } catch (error) {
    console.error('Error obteniendo estadísticas:', error);
    return null;
  }
}

// Eventos de Socket.IO
io.on('connection', (socket) => {
  console.log(`Cliente conectado: ${socket.id}`);

  // Enviar métricas actuales al conectarse
  socket.emit('welcome', {
    message: 'Conectado al sistema de monitoreo',
    timestamp: Date.now(),
    client_id: socket.id
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
    console.log(`Cliente desconectado: ${socket.id}`);
  });

  // Manejo de errores
  socket.on('error', (error) => {
    console.error(`Error en socket ${socket.id}:`, error);
  });
});

// Broadcast de métricas cada X segundos
let broadcastInterval;

function startMetricsBroadcast(intervalSeconds = 3) {
  broadcastInterval = setInterval(async () => {
    const connectedClients = io.engine.clientsCount;
    
    if (connectedClients > 0) {
      const metrics = await getLatestMetrics();
      if (metrics) {
        io.emit('metrics_update', metrics);
        console.log(`📡 Métricas enviadas a ${connectedClients} cliente(s)`);
      }
    }
  }, intervalSeconds * 1000);
  
  console.log(`Broadcast de métricas iniciado cada ${intervalSeconds}s`);
}

function stopMetricsBroadcast() {
  if (broadcastInterval) {
    clearInterval(broadcastInterval);
    console.log('Broadcast de métricas detenido');
  }
}

// API REST endpoints para health check
app.get('/health', async (req, res) => {
  try {
    const connection = await pool.getConnection();
    await connection.ping();
    connection.release();
    
    res.json({
      status: 'healthy',
      service: 'WebSocket API',
      timestamp: new Date().toISOString(),
      connected_clients: io.engine.clientsCount,
      database: 'connected'
    });
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      service: 'WebSocket API',
      error: error.message
    });
  }
});

app.get('/clients', (req, res) => {
  res.json({
    connected_clients: io.engine.clientsCount,
    timestamp: new Date().toISOString()
  });
});

app.get('/', (req, res) => {
  res.json({
    service: 'Sistema de Monitoreo - WebSocket API',
    version: '1.0.0',
    author: 'Bismarck Romero - 201708880',
    description: '3ra API NodeJS para transmisión de métricas en tiempo real via WebSocket',
    api_type: 'WebSocket/Socket.IO',
    endpoints: {
      websocket: 'ws://localhost:4000',
      health: 'GET /health',
      clients: 'GET /clients'
    },
    socket_events: {
      outgoing: ['welcome', 'metrics_update', 'historical_data', 'system_stats', 'error'],
      incoming: ['request_metrics', 'request_historical', 'request_stats']
    }
  });
});

// Inicializar servidor
async function startServer() {
  console.log('Iniciando WebSocket API...');
  
  // Inicializar base de datos
  const dbConnected = await initializeDatabase();
  if (!dbConnected) {
    console.error('No se pudo conectar a la base de datos. Saliendo...');
    process.exit(1);
  }

  // Iniciar servidor
  server.listen(PORT, () => {
    console.log(`WebSocket API ejecutándose en puerto ${PORT}`);
    console.log(`Socket.IO: ws://localhost:${PORT}`);
    console.log(`Health check: http://localhost:${PORT}/health`);
    
    // Iniciar broadcast de métricas
    startMetricsBroadcast(3); // Cada 3 segundos
  });
}

// Manejo de señales para cierre limpio
process.on('SIGTERM', () => {
  console.log('Recibida señal SIGTERM, cerrando servidor...');
  stopMetricsBroadcast();
  server.close(() => {
    if (pool) pool.end();
    console.log('Servidor cerrado correctamente');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('Recibida señal SIGINT, cerrando servidor...');
  stopMetricsBroadcast();
  server.close(() => {
    if (pool) pool.end();
    console.log('Servidor cerrado correctamente');
    process.exit(0);
  });
});

// Manejo de errores no capturados
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
  process.exit(1);
});

// Iniciar el servidor
startServer();