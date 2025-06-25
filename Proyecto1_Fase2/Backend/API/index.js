const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');
const app = express();
const PORT = process.env.PORT || 3000;

// Configuración de middleware
app.use(cors());
app.use(express.json());

// Configuración de la base de datos
const dbConfig = {
  host: process.env.DB_HOST || 'mysql-service',
  port: process.env.DB_PORT || 3306,
  user: process.env.DB_USER || 'monitor',
  password: process.env.DB_PASSWORD || 'monitor123',
  database: process.env.DB_NAME || 'monitoring',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
};

// Crear pool de conexiones
const pool = mysql.createPool(dbConfig);

// Verificar conexión a la base de datos
async function checkDBConnection() {
  try {
    const connection = await pool.getConnection();
    console.log('Conexión a MySQL establecida correctamente - API NodeJS');
    connection.release();
    return true;
  } catch (error) {
    console.error('Error al conectar a MySQL:', error);
    return false;
  }
}

// Health check para Kubernetes
app.get('/health', async (req, res) => {
  try {
    const connection = await pool.getConnection();
    connection.release();
    
    res.json({
      "status": "healthy",
      "api": "NodeJS",
      "timestamp": new Date().toISOString(),
      "database": "connected"
    });
  } catch (error) {
    console.error('Health check failed:', error);
    res.status(503).json({
      "status": "unhealthy",
      "api": "NodeJS",
      "error": error.message
    });
  }
});

// Inicializar la tabla de caché si es necesario
async function initCacheTable() {
  try {
    // Verificar si existen registros para CPU, RAM y procesos en la tabla de caché
    const cacheIds = ['cpu', 'ram', 'procesos'];
    const cacheDefaults = {
      'cpu': { porcentaje_uso: 0 },
      'ram': { total: 0, libre: 0, uso: 0, porcentaje_uso: 0 },
      'procesos': { 
        procesos_corriendo: 0, 
        total_processos: 0, 
        procesos_durmiendo: 0, 
        procesos_zombie: 0, 
        procesos_parados: 0 
      }
    };

    for (const cacheId of cacheIds) {
      const [cache] = await pool.execute('SELECT * FROM metrics_cache WHERE id = ?', [cacheId]);
      if (cache.length === 0) {
        await pool.execute(
          'INSERT INTO metrics_cache (id, timestamp, data) VALUES (?, ?, ?)',
          [cacheId, 0, JSON.stringify(cacheDefaults[cacheId])]
        );
        console.log(`Inicializado registro de caché para ${cacheId}`);
      }
    }

    console.log('Tabla de caché verificada correctamente');
  } catch (error) {
    console.error('Error al inicializar la tabla de caché:', error);
  }
}

const SAMPLE_RATE = 2000;
let lastSampleTime = 0;

// Endpoint principal para recibir métricas del agente Go
// Ruta 2 del Traffic Split - API NodeJS
app.post('/api/data', async (req, res) => {
  try {
    const data = req.body;
    const now = Date.now();
    
    if (!data) {
      return res.status(400).json({ 
        error: 'No data provided', 
        api: 'NodeJS' 
      });
    }

    console.log('Datos recibidos en API NodeJS:', data);

    // Procesar datos según formato del agente Go
    const timestamp = Math.floor(Date.now() / 1000);
    
    // Extraer métricas de CPU
    const cpu_data = data.cpu || {};
    const cpu_usage = cpu_data.porcentajeUso || 0;
    
    // Extraer métricas de RAM  
    const ram_data = data.ram || {};
    const ram_total = ram_data.total || 0;
    const ram_libre = ram_data.libre || 0;
    const ram_uso = ram_data.uso || 0;
    const ram_percentage = ram_data.porcentajeUso || 0;
    
    // Extraer métricas de procesos
    const process_data = data.procesos || {};
    const processes_running = process_data.procesos_corriendo || 0;
    const processes_total = process_data.total_processos || 0;
    const processes_sleeping = process_data.procesos_durmiendo || 0;
    const processes_zombie = process_data.procesos_zombie || 0;
    const processes_stopped = process_data.procesos_parados || 0;

    // Actualizar la caché en la base de datos
    try {
      // Actualizar caché de CPU
      await pool.execute(
        'UPDATE metrics_cache SET timestamp = ?, data = ?, updated_at = NOW() WHERE id = ?',
        [timestamp, JSON.stringify({ porcentaje_uso: cpu_usage }), 'cpu']
      );

      // Actualizar caché de RAM
      await pool.execute(
        'UPDATE metrics_cache SET timestamp = ?, data = ?, updated_at = NOW() WHERE id = ?',
        [timestamp, JSON.stringify({
          total: ram_total,
          libre: ram_libre,
          uso: ram_uso,
          porcentaje_uso: ram_percentage
        }), 'ram']
      );

      // Actualizar caché de procesos 
      await pool.execute(
        'UPDATE metrics_cache SET timestamp = ?, data = ?, updated_at = NOW() WHERE id = ?',
        [timestamp, JSON.stringify({
          procesos_corriendo: processes_running,
          total_processos: processes_total,
          procesos_durmiendo: processes_sleeping,
          procesos_zombie: processes_zombie,
          procesos_parados: processes_stopped
        }), 'procesos']
      );
    } catch (cacheError) {
      console.error('Error al actualizar la caché:', cacheError);
      // Continuar con el proceso incluso si la caché falla
    }
    
    // Guardar en las tablas principales según la tasa de muestreo
    if (now - lastSampleTime >= SAMPLE_RATE) {
      lastSampleTime = now;
      
      // Guardar datos de CPU
      await pool.execute(
        'INSERT INTO cpu_metrics (timestamp, porcentaje_uso) VALUES (?, ?)',
        [timestamp, cpu_usage]
      );
      
      // Guardar datos de RAM
      await pool.execute(
        'INSERT INTO ram_metrics (timestamp, total, libre, uso, porcentaje_uso) VALUES (?, ?, ?, ?, ?)',
        [timestamp, ram_total, ram_libre, ram_uso, ram_percentage]
      );
      
      // Guardar datos de procesos 
      await pool.execute(
        'INSERT INTO procesos_metrics (timestamp, procesos_corriendo, total_processos, procesos_durmiendo, procesos_zombie, procesos_parados) VALUES (?, ?, ?, ?, ?, ?)',
        [timestamp, processes_running, processes_total, processes_sleeping, processes_zombie, processes_stopped]
      );
      
      console.log(`Métricas completas guardadas por API NodeJS - Timestamp: ${new Date(timestamp * 1000).toISOString()}`);
    } else {
      console.log(`Solo caché actualizada por API NodeJS - Timestamp: ${new Date(timestamp * 1000).toISOString()}`);
    }

    // Preparar datos de respuesta (mismo formato que Python)
    const cache_data = {
      "total_ram": Math.floor(ram_total / 1024) || 0,
      "ram_libre": ram_libre,
      "uso_ram": Math.floor(ram_uso / 1024) || 0,
      "porcentaje_ram": ram_percentage,
      "porcentaje_cpu_uso": cpu_usage,
      "porcentaje_cpu_libre": 100 - cpu_usage,
      "procesos_corriendo": processes_running,
      "total_procesos": processes_total,
      "procesos_durmiendo": processes_sleeping,
      "procesos_zombie": processes_zombie,
      "procesos_parados": processes_stopped,
      "hora": new Date().toISOString().replace('T', ' ').slice(0, 19),
      "api": "NodeJS"  // Identificador de la API
    };
    
    console.log('Métricas guardadas exitosamente por API NodeJS');
    
    res.status(201).json({
      "message": "Metrics saved successfully",
      "api": "NodeJS",
      "timestamp": timestamp,
      "data": cache_data
    });
    
  } catch (error) {
    console.error('Error al guardar métricas en API NodeJS:', error);
    res.status(500).json({ 
      error: 'Internal server error',
      api: 'NodeJS',
      details: error.message
    });
  }
});

// Endpoint para obtener métricas completas de la Fase 2 (FORMATO EXACTO COMO PYTHON)
app.get('/api/metrics/complete', async (req, res) => {
    try {
        // Obtener datos de caché desde la base de datos
        const [cpuCache] = await pool.execute('SELECT timestamp, data FROM metrics_cache WHERE id = ?', ['cpu']);
        const [ramCache] = await pool.execute('SELECT timestamp, data FROM metrics_cache WHERE id = ?', ['ram']);
        const [procesosCache] = await pool.execute('SELECT timestamp, data FROM metrics_cache WHERE id = ?', ['procesos']);

        let cpu, ram, processes;

        const safeParseJSON = (data) => {
            try {
                if (typeof data === 'object' && data !== null) {
                    return data;
                }
                if (typeof data === 'string') {
                    return JSON.parse(data);
                }
                return {};
            } catch (e) {
                console.error('Error parsing JSON:', e);
                return {};
            }
        };

        // Si hay caché, usarla
        if (cpuCache.length > 0 && ramCache.length > 0 && procesosCache.length > 0) {
            console.log('Usando datos de caché');
            
            cpu = safeParseJSON(cpuCache[0].data);
            ram = safeParseJSON(ramCache[0].data);
            processes = safeParseJSON(procesosCache[0].data);

        } else {
            // Fallback a tablas principales
            console.log('Sin caché, consultando tablas principales');
            
            const [cpuResults] = await pool.execute('SELECT * FROM cpu_metrics ORDER BY timestamp DESC LIMIT 1');
            const [ramResults] = await pool.execute('SELECT * FROM ram_metrics ORDER BY timestamp DESC LIMIT 1');
            const [processResults] = await pool.execute('SELECT * FROM procesos_metrics ORDER BY timestamp DESC LIMIT 1');

            cpu = cpuResults[0] || { porcentaje_uso: 0 };
            ram = ramResults[0] || { total: 0, libre: 0, uso: 0, porcentaje_uso: 0 };
            processes = processResults[0] || { 
                procesos_corriendo: 0, 
                total_processos: 0, 
                procesos_durmiendo: 0, 
                procesos_zombie: 0, 
                procesos_parados: 0 
            };
        }

        // Validar y asegurar valores por defecto
        const safeCpu = {
            porcentaje_uso: cpu?.porcentaje_uso || 0
        };

        const safeRam = {
            total: ram?.total || 0,
            libre: ram?.libre || 0,
            uso: ram?.uso || 0,
            porcentaje_uso: ram?.porcentaje_uso || 0
        };

        const safeProcesses = {
            procesos_corriendo: processes?.procesos_corriendo || 0,
            total_processos: processes?.total_processos || 0,
            procesos_durmiendo: processes?.procesos_durmiendo || 0,
            procesos_zombie: processes?.procesos_zombie || 0,
            procesos_parados: processes?.procesos_parados || 0
        };

        // Formato JSON EXACTO como Python (requerimientos)
        const response = {
            "total_ram": safeRam.total > 0 ? Math.floor(safeRam.total / 1024) : 0,
            "ram_libre": safeRam.libre || 0,
            "uso_ram": safeRam.uso > 0 ? Math.floor(safeRam.uso / 1024) : 0,
            "porcentaje_ram": safeRam.porcentaje_uso || 0,
            "porcentaje_cpu_uso": safeCpu.porcentaje_uso || 0,
            "porcentaje_cpu_libre": 100 - (safeCpu.porcentaje_uso || 0),
            "procesos_corriendo": safeProcesses.procesos_corriendo,
            "total_procesos": safeProcesses.total_processos,
            "procesos_durmiendo": safeProcesses.procesos_durmiendo,
            "procesos_zombie": safeProcesses.procesos_zombie,
            "procesos_parados": safeProcesses.procesos_parados,
            "hora": new Date().toISOString().replace('T', ' ').slice(0, 19),
            "api": "NodeJS"  // ← CAMPO REQUERIDO
        };

        res.json(response);
    } catch (error) {
        console.error('Error getting complete metrics:', error);
        res.status(500).json({ 
            error: 'Error retrieving metrics',
            api: 'NodeJS'
        });
    }
});

// Endpoint para métricas procesadas específicamente por la API NodeJS
app.get('/api/metrics/nodejs', async (req, res) => {
  try {
    const connection = await pool.getConnection();
    
    // Obtener últimas métricas de cada tipo
    const [cpuResults] = await connection.execute('SELECT * FROM cpu_metrics ORDER BY timestamp DESC LIMIT 10');
    const [ramResults] = await connection.execute('SELECT * FROM ram_metrics ORDER BY timestamp DESC LIMIT 10');
    const [processResults] = await connection.execute('SELECT * FROM procesos_metrics ORDER BY timestamp DESC LIMIT 10');
    
    connection.release();
    
    res.json({
      "api": "NodeJS",
      "timestamp": new Date().toISOString(),
      "data": {
        "cpu": cpuResults,
        "ram": ramResults,
        "procesos": processResults
      },
      "total_records": cpuResults.length + ramResults.length + processResults.length
    });
    
  } catch (error) {
    console.error('Error obteniendo métricas NodeJS:', error);
    res.status(500).json({
      error: 'Error retrieving metrics',
      api: 'NodeJS'
    });
  }
});

// Endpoint para estadísticas específicas de la API NodeJS
app.get('/api/stats/nodejs', async (req, res) => {
  try {
    const connection = await pool.getConnection();
    
    // Contar registros por tabla
    const [cpuCount] = await connection.execute('SELECT COUNT(*) as count FROM cpu_metrics');
    const [ramCount] = await connection.execute('SELECT COUNT(*) as count FROM ram_metrics');
    const [processCount] = await connection.execute('SELECT COUNT(*) as count FROM procesos_metrics');
    
    // Obtener rango de fechas
    const [dateRange] = await connection.execute(`
      SELECT 
        MIN(FROM_UNIXTIME(timestamp)) as oldest,
        MAX(FROM_UNIXTIME(timestamp)) as newest
      FROM cpu_metrics
    `);
    
    connection.release();
    
    const stats = {
      'cpu_metrics': cpuCount[0].count,
      'ram_metrics': ramCount[0].count,
      'procesos_metrics': processCount[0].count
    };
    
    res.json({
      "api": "NodeJS",
      "timestamp": new Date().toISOString(),
      "database_stats": stats,
      "date_range": dateRange[0],
      "total_records": Object.values(stats).reduce((a, b) => a + b, 0)
    });
    
  } catch (error) {
    console.error('Error obteniendo estadísticas NodeJS:', error);
    res.status(500).json({
      error: 'Error retrieving stats',
      api: 'NodeJS'
    });
  }
});

// Mantener endpoints existentes para compatibilidad
app.get('/api/metrics/cpu', async (req, res) => {
  try {
    const [rows] = await pool.execute(
      'SELECT * FROM cpu_metrics ORDER BY timestamp DESC LIMIT 100'
    );
    res.json(rows);
  } catch (error) {
    console.error('Error al obtener métricas de CPU:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

app.get('/api/metrics/ram', async (req, res) => {
  try {
    const [rows] = await pool.execute(
      'SELECT * FROM ram_metrics ORDER BY timestamp DESC LIMIT 100'
    );
    res.json(rows);
  } catch (error) {
    console.error('Error al obtener métricas de RAM:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

app.get('/api/metrics/procesos', async (req, res) => {
  try {
    const [rows] = await pool.execute(
      'SELECT * FROM procesos_metrics ORDER BY timestamp DESC LIMIT 100'
    );
    res.json(rows);
  } catch (error) {
    console.error('Error al obtener métricas de procesos:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

app.get('/api/metrics/latest', async (req, res) => {
  try {
    const [cpuCache] = await pool.execute('SELECT timestamp, data, updated_at FROM metrics_cache WHERE id = ?', ['cpu']);
    const [ramCache] = await pool.execute('SELECT timestamp, data, updated_at FROM metrics_cache WHERE id = ?', ['ram']);
    const [procesosCache] = await pool.execute('SELECT timestamp, data, updated_at FROM metrics_cache WHERE id = ?', ['procesos']);

    const safeParseJSON = (data) => {
      if (typeof data === 'object' && data !== null) {
        return data;
      }
      try {
        return JSON.parse(data);
      } catch (e) {
        console.error('Error al analizar JSON:', e);
        return {};
      }
    };
    
    const cpuData = cpuCache.length > 0 ? {
      timestamp: cpuCache[0].timestamp,
      ...safeParseJSON(cpuCache[0].data)
    } : null;
    
    const ramData = ramCache.length > 0 ? {
      timestamp: ramCache[0].timestamp,
      ...safeParseJSON(ramCache[0].data)
    } : null;

    const procesosData = procesosCache.length > 0 ? {
      timestamp: procesosCache[0].timestamp,
      ...safeParseJSON(procesosCache[0].data)
    } : null;
    
    res.json({
      cpu: cpuData,
      ram: ramData,
      procesos: procesosData
    });
  } catch (error) {
    console.error('Error al obtener métricas recientes:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// Endpoint raíz con información de la API
app.get('/', (req, res) => {
  res.json({
    service: 'Sistema de Monitoreo - API NodeJS',
    version: '2.0.0',
    author: 'Bismarck Romero - 201708880',
    description: 'Ruta 2 del Traffic Split - API desarrollada en NodeJS/Express',
    endpoints: [
      'GET /health - Health check',
      'POST /api/data - Recibir métricas del agente',
      'GET /api/metrics/complete - Formato completo requerido (con campo api)',
      'GET /api/metrics/nodejs - Métricas procesadas por NodeJS',
      'GET /api/stats/nodejs - Estadísticas de la API NodeJS',
      'GET /api/metrics/latest - Métricas más recientes',
      'GET /api/metrics/cpu - Historial CPU',
      'GET /api/metrics/ram - Historial RAM',
      'GET /api/metrics/procesos - Historial procesos'
    ],
    timestamp: new Date().toISOString()
  });
});

// Endpoint para manejar rutas no encontradas
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Endpoint no encontrado',
    api: 'NodeJS',
    path: req.originalUrl,
    available_endpoints: [
      '/',
      '/health',
      '/api/data',
      '/api/metrics/complete',
      '/api/metrics/nodejs',
      '/api/stats/nodejs'
    ]
  });
});

// Inicializar servidor
async function initServer() {
  try {
    const connected = await checkDBConnection();
    if (connected) {
      await initCacheTable();
      
      app.listen(PORT, () => {
        console.log(`API NodeJS (Ruta 2) ejecutándose en puerto ${PORT}`);
        console.log(`Configuración de BD: ${dbConfig.host}:${dbConfig.port}`);
      });
    } else {
      console.error('No se pudo iniciar el servidor debido a problemas con la base de datos');
      process.exit(1);
    }
  } catch (error) {
    console.error('Error al inicializar la API NodeJS:', error);
    process.exit(1);
  }
}

initServer();