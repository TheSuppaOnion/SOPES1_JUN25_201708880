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

// Configuración de base de datos - CAMBIAR POR TU IP REAL
const dbConfig = {
  host: process.env.DB_HOST || 'TU_IP_AQUI', // ← CAMBIAR POR LA IP QUE MOSTRÓ EL SCRIPT
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
    console.log('✓ Pool de conexiones MySQL creado');
    
    // Probar conexión
    const connection = await pool.getConnection();
    await connection.ping();
    connection.release();
    console.log('✓ Conexión a base de datos exitosa');
    
    // Verificar que existe la tabla metrics
    const [tables] = await pool.execute("SHOW TABLES LIKE 'metrics'");
    if (tables.length === 0) {
      console.error('X Tabla "metrics" no encontrada');
      return false;
    }
    
    console.log('✓ Tabla "metrics" encontrada');
    return true;
  } catch (error) {
    console.error('X Error conectando a base de datos:', error.message);
    console.error('X Verifica que la IP de BD sea correcta:', dbConfig.host);
    return false;
  }
}

// FUNCIÓN PRINCIPAL: Obtener últimas métricas de la tabla METRICS unificada
async function getLatestMetrics() {
  try {
    // Obtener el registro más reciente de la tabla metrics
    const [rows] = await pool.execute(
      'SELECT * FROM metrics ORDER BY timestamp DESC LIMIT 1'
    );

    if (rows.length === 0) {
      console.log('⚠ No hay datos en la tabla metrics');
      return {
        timestamp: Date.now(),
        cpu: { porcentaje_uso: 0, porcentaje_libre: 100 },
        ram: { 
          total: 0, libre: 0, uso: 0, porcentaje_uso: 0, 
          total_gb: 0, libre_gb: 0 
        },
        procesos: { 
          total_procesos: 0, procesos_corriendo: 0, 
          procesos_durmiendo: 0, procesos_zombie: 0, procesos_parados: 0 
        },
        api_source: 'no_data',
        last_update: new Date().toISOString()
      };
    }

    const latest = rows[0];
    console.log('📊 Datos obtenidos de BD:', {
      id: latest.id,
      cpu: `${latest.porcentaje_cpu_uso}%`,
      ram: `${latest.porcentaje_ram}%`,
      procesos: latest.total_procesos,
      api_source: latest.api_source,
      hora: latest.hora
    });

    // Transformar datos EXACTAMENTE como los espera el frontend
    // Usando los campos de tu JSON tal como están
    return {
      timestamp: Date.now(),
      
      // CPU - directamente de tu JSON
      cpu: {
        porcentaje_uso: parseFloat(latest.porcentaje_cpu_uso) || 0,
        porcentaje_libre: parseFloat(latest.porcentaje_cpu_libre) || (100 - parseFloat(latest.porcentaje_cpu_uso))
      },
      
      // RAM - directamente de tu JSON
      ram: {
        total: latest.total_ram || 0,                    // total_ram del JSON
        libre: latest.ram_libre || 0,                   // ram_libre del JSON
        uso: latest.uso_ram || 0,                       // uso_ram del JSON
        porcentaje_uso: parseFloat(latest.porcentaje_ram) || 0, // porcentaje_ram del JSON
        
        // Conversiones para el frontend
        total_gb: Math.round((latest.total_ram || 0) / 1024 * 100) / 100,
        libre_gb: Math.round((latest.ram_libre || 0) / (1024 * 1024 * 1024) * 100) / 100,
        uso_gb: Math.round((latest.uso_ram || 0) / 1024 * 100) / 100
      },
      
      // Procesos - directamente de tu JSON
      procesos: {
        total_procesos: latest.total_procesos || 0,         // total_procesos del JSON
        procesos_corriendo: latest.procesos_corriendo || 0, // procesos_corriendo del JSON
        procesos_durmiendo: latest.procesos_durmiendo || 0, // procesos_durmiendo del JSON
        procesos_zombie: latest.procesos_zombie || 0,       // procesos_zombie del JSON
        procesos_parados: latest.procesos_parados || 0      // procesos_parados del JSON
      },
      
      // Metadatos
      api_source: latest.api_source || 'unknown',
      last_update: latest.hora || latest.timestamp,
      db_id: latest.id,
      formatted_time: new Date().toLocaleString('es-GT', {
        timeZone: 'America/Guatemala'
      })
    };
  } catch (error) {
    console.error('X Error obteniendo métricas de tabla metrics:', error.message);
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
         total_ram, uso_ram, total_procesos, api_source, hora
       FROM metrics 
       WHERE timestamp >= ? 
       ORDER BY timestamp ASC
       LIMIT 1000`,
      [timeLimit]
    );

    console.log(`📈 Datos históricos: ${rows.length} registros de los últimos ${minutes} minutos`);

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
    console.error('X Error obteniendo datos históricos:', error.message);
    return { cpu: [], ram: [], total_records: 0 };
  }
}

// Obtener estadísticas del sistema
async function getSystemStats() {
  try {
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
    console.error('X Error obteniendo estadísticas:', error.message);
    return null;
  }
}

// Eventos de Socket.IO
io.on('connection', (socket) => {
  console.log(`✓ Cliente conectado: ${socket.id}`);

  // Enviar bienvenida y métricas iniciales
  socket.emit('welcome', {
    message: 'Conectado al sistema de monitoreo WebSocket - Solo tabla METRICS',
    timestamp: Date.now(),
    client_id: socket.id,
    data_source: 'tabla_metrics_unificada'
  });

  // Enviar métricas actuales inmediatamente
  getLatestMetrics().then(metrics => {
    if (metrics) {
      socket.emit('metrics_update', metrics);
      console.log(`📤 Métricas iniciales enviadas a ${socket.id}`);
    }
  });

  // Cliente solicita métricas
  socket.on('request_metrics', async () => {
    const metrics = await getLatestMetrics();
    if (metrics) {
      socket.emit('metrics_update', metrics);
    } else {
      socket.emit('error', { message: 'No hay datos disponibles en tabla metrics' });
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

  socket.on('error', (error) => {
    console.error(`X Error en socket ${socket.id}:`, error);
  });
});

// BROADCAST AUTOMÁTICO cada 2 segundos
let broadcastInterval;

function startMetricsBroadcast(intervalSeconds = 2) {
  broadcastInterval = setInterval(async () => {
    const connectedClients = io.engine.clientsCount;
    
    if (connectedClients > 0) {
      const metrics = await getLatestMetrics();
      if (metrics) {
        io.emit('metrics_update', metrics);
        console.log(`✓ Broadcast → ${connectedClients} cliente(s) | CPU: ${metrics.cpu.porcentaje_uso}% | RAM: ${metrics.ram.porcentaje_uso}% | API: ${metrics.api_source}`);
      } else {
        console.log(`⚠ No hay métricas para enviar a ${connectedClients} cliente(s)`);
      }
    }
  }, intervalSeconds * 1000);
  
  console.log(`✓ Broadcast automático iniciado cada ${intervalSeconds}s (solo tabla metrics)`);
}

function stopMetricsBroadcast() {
  if (broadcastInterval) {
    clearInterval(broadcastInterval);
    console.log('X Broadcast automático detenido');
  }
}

// API REST endpoints
app.get('/health', async (req, res) => {
  try {
    const connection = await pool.getConnection();
    await connection.ping();
    connection.release();
    
    // Contar registros en tabla metrics
    const [count] = await pool.execute('SELECT COUNT(*) as total FROM metrics');
    
    res.json({
      status: 'healthy',
      service: 'WebSocket API - Reader tabla METRICS unificada',
      timestamp: new Date().toISOString(),
      connected_clients: io.engine.clientsCount,
      database: 'connected',
      table: 'metrics',
      total_records: count[0]?.total || 0,
      db_host: dbConfig.host,
      role: 'Leer SOLO tabla metrics y transmitir via WebSocket'
    });
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      service: 'WebSocket API',
      error: error.message,
      database: 'disconnected',
      db_host: dbConfig.host
    });
  }
});

app.get('/api/metrics', async (req, res) => {
  try {
    const metrics = await getLatestMetrics();
    if (metrics) {
      res.json({
        success: true,
        data: metrics,
        source: 'tabla_metrics_unificada'
      });
    } else {
      res.status(404).json({ 
        success: false, 
        error: 'No hay métricas disponibles en tabla metrics' 
      });
    }
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      error: 'Error obteniendo métricas', 
      details: error.message 
    });
  }
});

app.get('/', (req, res) => {
  res.json({
    service: 'Sistema de Monitoreo - WebSocket API',
    version: '2.0.0 - Tabla METRICS unificada',
    author: 'Bismarck Romero - 201708880',
    description: 'API WebSocket para transmisión de métricas en tiempo real',
    role: 'Leer SOLO tabla "metrics" y transmitir al Frontend',
    table_structure: 'metrics (total_ram, ram_libre, uso_ram, porcentaje_ram, porcentaje_cpu_uso, etc.)',
    api_type: 'WebSocket/Socket.IO',
    endpoints: {
      websocket: `ws://localhost:${PORT}`,
      health: 'GET /health',
      metrics: 'GET /api/metrics'
    },
    socket_events: {
      outgoing: ['welcome', 'metrics_update', 'historical_data', 'system_stats', 'error'],
      incoming: ['request_metrics', 'request_historical', 'request_stats']
    },
    data_flow: 'BD tabla metrics → WebSocket API → Frontend'
  });
});

// Inicializar servidor
async function startServer() {
  console.log('🚀 Iniciando WebSocket API - Lector de tabla METRICS...');
  console.log(`📊 Configuración BD: ${dbConfig.host}:${dbConfig.port}/${dbConfig.database}`);
  
  // Inicializar base de datos
  const dbConnected = await initializeDatabase();
  if (!dbConnected) {
    console.error('X No se pudo conectar a la base de datos. Verifica la IP y configuración.');
    console.error(`X Host configurado: ${dbConfig.host}`);
    console.error('X Ejecuta: ./setup-mysql-local.sh para obtener la IP correcta');
    process.exit(1);
  }

  // Iniciar servidor
  server.listen(PORT, '0.0.0.0', () => {
    console.log(`✓ WebSocket API ejecutándose en puerto ${PORT}`);
    console.log(`✓ Socket.IO: ws://localhost:${PORT}`);
    console.log(`✓ Health check: http://localhost:${PORT}/health`);
    console.log('✓ Función: Leer SOLO tabla "metrics" y transmitir al frontend');
    console.log('📋 Tabla monitoreada: metrics (formato JSON unificado)');
    
    // Iniciar broadcast automático
    startMetricsBroadcast(2);
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

// Manejo de errores
process.on('unhandledRejection', (reason, promise) => {
  console.error('X Unhandled Rejection at:', promise, 'reason:', reason);
});

process.on('uncaughtException', (error) => {
  console.error('X Uncaught Exception:', error);
  process.exit(1);
});

// Iniciar el servidor
startServer();