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
    const { timestamp, cpu, ram } = req.body;
    const now = Date.now();
    
    if (!timestamp || !cpu || !ram) {
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

    // Verificar si la caché es reciente (menos de 2 segundos)
    const now = Date.now();
    const isCacheRecent = cpuCache.length > 0 && 
                          now - new Date(cpuCache[0].updated_at).getTime() < 2000;

    let cpuData, ramData;

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
    } else {
      // Si la caché no es reciente, obtener datos de las tablas principales
      console.log('Caché no reciente, consultando tablas principales');
      
      const [cpuRows] = await pool.execute(
        'SELECT * FROM cpu_metrics ORDER BY timestamp DESC LIMIT 1'
      );
      
      const [ramRows] = await pool.execute(
        'SELECT * FROM ram_metrics ORDER BY timestamp DESC LIMIT 1'
      );
      
      cpuData = cpuRows.length > 0 ? cpuRows[0] : null;
      ramData = ramRows.length > 0 ? ramRows[0] : null;

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
    }
    
    res.json({
      cpu: cpuData,
      ram: ramData
    });
  } catch (error) {
    console.error('Error al obtener métricas recientes:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
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