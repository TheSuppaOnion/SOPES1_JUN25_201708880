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

    // Actualizar siempre la caché en la base de datos
    // Actualizar caché de CPU
    await pool.execute(
      'UPDATE metrics_cache SET timestamp = ?, data = ? WHERE id = ?',
      [timestamp, JSON.stringify({ porcentaje_uso: cpu.porcentajeUso }), 'cpu']
    );

    // Actualizar caché de RAM
    await pool.execute(
      'UPDATE metrics_cache SET timestamp = ?, data = ? WHERE id = ?',
      [timestamp, JSON.stringify({
        total: ram.total,
        libre: ram.libre,
        uso: ram.uso,
        porcentaje_uso: ram.porcentajeUso
      }), 'ram']
    );
    
    // Pero solo guardar en las tablas de métricas según la tasa de muestreo
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

// Endpoint para obtener las métricas más recientes - Usando la tabla como caché
app.get('/api/metrics/latest', async (req, res) => {
  try {
    // Obtener la caché desde la base de datos
    const [cpuCache] = await pool.execute('SELECT * FROM metrics_cache WHERE id = ?', ['cpu']);
    const [ramCache] = await pool.execute('SELECT * FROM metrics_cache WHERE id = ?', ['ram']);
    
    // Preparar respuesta
    const cpuData = cpuCache.length > 0 ? {
      timestamp: cpuCache[0].timestamp,
      ...JSON.parse(cpuCache[0].data)
    } : null;
    
    const ramData = ramCache.length > 0 ? {
      timestamp: ramCache[0].timestamp,
      ...JSON.parse(ramCache[0].data)
    } : null;
    
    res.json({
      cpu: cpuData,
      ram: ramData
    });
  } catch (error) {
    console.error('Error al obtener métricas recientes:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// Verificar conexión a la base de datos antes de iniciar el servidor
checkDBConnection()
  .then(connected => {
    if (connected) {
      app.listen(PORT, () => {
        console.log(`API ejecutándose en http://localhost:${PORT}`);
      });
    } else {
      console.error('No se pudo iniciar el servidor debido a problemas con la base de datos');
    }
  });