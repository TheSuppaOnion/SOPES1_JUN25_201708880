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
  host: process.env.DB_HOST || 'localhost',
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
    console.log('Conexión a MySQL establecida correctamente');
    connection.release();
    return true;
  } catch (error) {
    console.error('Error al conectar a MySQL:', error);
    return false;
  }
}

// Inicializar la tabla de caché si es necesario
async function initCacheTable() {
  try {
    // Verificar si existen registros para CPU y RAM en la tabla de caché
    const [cpuCache] = await pool.execute('SELECT * FROM metrics_cache WHERE id = ?', ['cpu']);
    if (cpuCache.length === 0) {
      await pool.execute(
        'INSERT INTO metrics_cache (id, timestamp, data) VALUES (?, ?, ?)',
        ['cpu', 0, JSON.stringify({ porcentaje_uso: 0 })]
      );
      console.log('Inicializado registro de caché para CPU');
    }

    const [ramCache] = await pool.execute('SELECT * FROM metrics_cache WHERE id = ?', ['ram']);
    if (ramCache.length === 0) {
      await pool.execute(
        'INSERT INTO metrics_cache (id, timestamp, data) VALUES (?, ?, ?)',
        ['ram', 0, JSON.stringify({ total: 0, libre: 0, uso: 0, porcentaje_uso: 0 })]
      );
      console.log('Inicializado registro de caché para RAM');
    }

    const [procesosCache] = await pool.execute('SELECT * FROM metrics_cache WHERE id = ?', ['procesos']);
    if (procesosCache.length === 0) {
      await pool.execute(
        'INSERT INTO metrics_cache (id, timestamp, data) VALUES (?, ?, ?)',
        ['procesos', 0, JSON.stringify({ 
          procesos_corriendo: 0, 
          total_processos: 0, 
          procesos_durmiendo: 0, 
          procesos_zombie: 0, 
          procesos_parados: 0 
        })]
      );
      console.log('Inicializado registro de caché para procesos');
    }

    console.log('Tabla de caché verificada correctamente');
  } catch (error) {
    console.error('Error al inicializar la tabla de caché:', error);
  }
}

const SAMPLE_RATE = 2000;
let lastSampleTime = 0;

// Endpoint para recibir métricas del agente Go
app.post('/api/data', async (req, res) => {
  try {
    const { timestamp, cpu, ram, procesos } = req.body;
    const now = Date.now();
    
    if (!timestamp || !cpu || !ram || !procesos) {
      return res.status(400).json({ error: 'Datos incompletos' });
    }

    // Actualizar la caché en la base de datos
    try {
      // Actualizar caché de CPU
      await pool.execute(
        'UPDATE metrics_cache SET timestamp = ?, data = ?, updated_at = NOW() WHERE id = ?',
        [timestamp, JSON.stringify({ porcentaje_uso: cpu.porcentajeUso }), 'cpu']
      );

      // Actualizar caché de RAM
      await pool.execute(
        'UPDATE metrics_cache SET timestamp = ?, data = ?, updated_at = NOW() WHERE id = ?',
        [timestamp, JSON.stringify({
          total: ram.total,
          libre: ram.libre,
          uso: ram.uso,
          porcentaje_uso: ram.porcentajeUso
        }), 'ram']
      );

      // Actualizar caché de procesos 
      await pool.execute(
        'UPDATE metrics_cache SET timestamp = ?, data = ?, updated_at = NOW() WHERE id = ?',
        [timestamp, JSON.stringify({
          procesos_corriendo: procesos.procesos_corriendo,
          total_processos: procesos.total_processos,
          procesos_durmiendo: procesos.procesos_durmiendo,
          procesos_zombie: procesos.procesos_zombie,
          procesos_parados: procesos.procesos_parados
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
        [timestamp, cpu.porcentajeUso]
      );
      
      // Guardar datos de RAM
      await pool.execute(
        'INSERT INTO ram_metrics (timestamp, total, libre, uso, porcentaje_uso) VALUES (?, ?, ?, ?, ?)',
        [timestamp, ram.total, ram.libre, ram.uso, ram.porcentajeUso]
      );
      
      // Guardar datos de procesos 
      await pool.execute(
        'INSERT INTO procesos_metrics (timestamp, procesos_corriendo, total_processos, procesos_durmiendo, procesos_zombie, procesos_parados) VALUES (?, ?, ?, ?, ?, ?)',
        [timestamp, procesos.procesos_corriendo, procesos.total_processos, procesos.procesos_durmiendo, procesos.procesos_zombie, procesos.procesos_parados]
      );
      
      console.log(`Métricas completas guardadas - Timestamp: ${new Date(timestamp * 1000).toISOString()}`);
    } else {
      console.log(`Solo caché actualizada - Timestamp: ${new Date(timestamp * 1000).toISOString()}`);
    }
    
    res.status(201).json({ message: 'Métricas recibidas correctamente' });
  } catch (error) {
    console.error('Error al guardar métricas:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// Endpoint para obtener métricas de CPU
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

// Endpoint para obtener métricas de RAM
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

// Endpoint para obtener métricas de procesos
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

// Endpoint para obtener las métricas más recientes - usando la tabla como caché
app.get('/api/metrics/latest', async (req, res) => {
  try {
    // Obtener datos de caché desde la base de datos
    const [cpuCache] = await pool.execute(
      'SELECT timestamp, data, updated_at FROM metrics_cache WHERE id = ?',
      ['cpu']
    );
    
    const [ramCache] = await pool.execute(
      'SELECT timestamp, data, updated_at FROM metrics_cache WHERE id = ?',
      ['ram']
    );

    const [procesosCache] = await pool.execute(
      'SELECT timestamp, data, updated_at FROM metrics_cache WHERE id = ?',
      ['procesos']
    );

    // Verificar si la caché es reciente (menos de 2 segundos)
    const now = Date.now();
    const isCacheRecent = cpuCache.length > 0 && 
                          now - new Date(cpuCache[0].updated_at).getTime() < 2000;

    let cpuData, ramData, procesosData;

    if (isCacheRecent) {
      // Usar datos de la caché
      console.log('Usando datos de caché');
      // Función segura para analizar JSON
      const safeParseJSON = (data) => {
        if (typeof data === 'object' && data !== null) {
          return data;  // Ya es un objeto
        }
        try {
          return JSON.parse(data);
        } catch (e) {
          console.error('Error al analizar JSON:', e);
          return {};  // Devolver objeto vacío en caso de error
        }
      };
      
      // Obtener datos de CPU de la caché
      cpuData = cpuCache.length > 0 ? {
        timestamp: cpuCache[0].timestamp,
        ...safeParseJSON(cpuCache[0].data)
      } : null;
      
      // Obtener datos de RAM de la caché
      ramData = ramCache.length > 0 ? {
        timestamp: ramCache[0].timestamp,
        ...safeParseJSON(ramCache[0].data)
      } : null;

      // Obtener datos de procesos de la caché
      procesosData = procesosCache.length > 0 ? {
        timestamp: procesosCache[0].timestamp,
        ...safeParseJSON(procesosCache[0].data)
      } : null;
    } else {
      // Si la caché no es reciente, obtener datos de las tablas principales
      console.log('Caché no reciente, consultando tablas principales');
      
      const [cpuRows] = await pool.execute(
        'SELECT * FROM cpu_metrics ORDER BY timestamp DESC LIMIT 1'
      );
      
      const [ramRows] = await pool.execute(
        'SELECT * FROM ram_metrics ORDER BY timestamp DESC LIMIT 1'
      );

      const [procesosRows] = await pool.execute(
        'SELECT * FROM procesos_metrics ORDER BY timestamp DESC LIMIT 1'
      );
      
      cpuData = cpuRows.length > 0 ? cpuRows[0] : null;
      ramData = ramRows.length > 0 ? ramRows[0] : null;
      procesosData = procesosRows.length > 0 ? procesosRows[0] : null;

      // Actualizar la caché con estos datos
      if (cpuData) {
        await pool.execute(
          'UPDATE metrics_cache SET timestamp = ?, data = ?, updated_at = NOW() WHERE id = ?',
          [cpuData.timestamp, JSON.stringify({ porcentaje_uso: cpuData.porcentaje_uso }), 'cpu']
        );
      }

      if (ramData) {
        await pool.execute(
          'UPDATE metrics_cache SET timestamp = ?, data = ?, updated_at = NOW() WHERE id = ?',
          [ramData.timestamp, JSON.stringify({
            total: ramData.total,
            libre: ramData.libre,
            uso: ramData.uso,
            porcentaje_uso: ramData.porcentaje_uso
          }), 'ram']
        );
      }

      if (procesosData) {
        await pool.execute(
          'UPDATE metrics_cache SET timestamp = ?, data = ?, updated_at = NOW() WHERE id = ?',
          [procesosData.timestamp, JSON.stringify({
            procesos_corriendo: procesosData.procesos_corriendo,
            total_processos: procesosData.total_processos,
            procesos_durmiendo: procesosData.procesos_durmiendo,
            procesos_zombie: procesosData.procesos_zombie,
            procesos_parados: procesosData.procesos_parados
          }), 'procesos']
        );
      }
    }
    
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

// Endpoint para obtener métricas completas de la Fase 2
app.get('/api/metrics/complete', async (req, res) => {
    try {
        // Intentar obtener de caché primero
        const [cpuCache] = await pool.execute('SELECT timestamp, data FROM metrics_cache WHERE id = ?', ['cpu']);
        const [ramCache] = await pool.execute('SELECT timestamp, data FROM metrics_cache WHERE id = ?', ['ram']);
        const [procesosCache] = await pool.execute('SELECT timestamp, data FROM metrics_cache WHERE id = ?', ['procesos']);

        let cpu, ram, processes;

        const safeParseJSON = (data) => {
            try {
                // Si ya es un objeto, devolverlo directamente
                if (typeof data === 'object' && data !== null) {
                    return data;
                }
                // Si es string, parsearlo
                if (typeof data === 'string') {
                    return JSON.parse(data);
                }
                // Si es otro tipo, devolver objeto vacío
                return {};
            } catch (e) {
                console.error('Error parsing JSON:', e, 'Data type:', typeof data, 'Data:', data);
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

        // Formato JSON
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
            "hora": new Date().toISOString().replace('T', ' ').slice(0, 19)
        };

        console.log('Response being sent:', JSON.stringify(response, null, 2));
        res.json(response);
    } catch (error) {
        console.error('Error getting complete metrics:', error);
        res.status(500).json({ error: 'Error retrieving metrics' });
    }
});

// Endpoint para el dashboard (página principal)
app.get('/', (req, res) => {
  res.json({
    status: 'API funcionando correctamente',
    version: '2.0',
    endpoints: [
      'GET /api/metrics/complete - Métricas completas',
      'GET /api/metrics/cpu - Historial CPU',
      'GET /api/metrics/ram - Historial RAM',
      'GET /api/metrics/procesos - Historial procesos',
      'GET /api/metrics/latest - Métricas más recientes',
      'POST /api/data - Recibir métricas del agente'
    ],
    timestamp: new Date().toISOString()
  });
});

// Endpoint para manejar rutas no encontradas
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Endpoint no encontrado',
    path: req.originalUrl,
    available_endpoints: [
      '/',
      '/api/metrics/complete',
      '/api/metrics/cpu',
      '/api/metrics/ram',
      '/api/metrics/procesos',
      '/api/metrics/latest'
    ]
  });
});

// Verificar conexión a la base de datos y inicializar caché antes de iniciar el servidor
checkDBConnection()
  .then(async (connected) => {
    if (connected) {
      // Inicializar la tabla de caché
      await initCacheTable();
      
      app.listen(PORT, () => {
        console.log(`API ejecutándose en http://localhost:${PORT}`);
      });
    } else {
      console.error('No se pudo iniciar el servidor debido a problemas con la base de datos');
    }
  })
  .catch(error => {
    console.error('Error al inicializar la API:', error);
  });