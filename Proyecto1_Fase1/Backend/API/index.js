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

// Endpoint para recibir métricas del agente Go
app.post('/api/data', async (req, res) => {
  try {
    const { timestamp, cpu, ram } = req.body;
    
    if (!timestamp || !cpu || !ram) {
      return res.status(400).json({ error: 'Datos incompletos' });
    }
    
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
    
    console.log(`Métricas recibidas - Timestamp: ${new Date(timestamp * 1000).toISOString()}`);
    
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

// Endpoint para obtener las métricas más recientes
app.get('/api/metrics/latest', async (req, res) => {
  try {
    const [cpuRows] = await pool.execute(
      'SELECT * FROM cpu_metrics ORDER BY timestamp DESC LIMIT 1'
    );
    
    const [ramRows] = await pool.execute(
      'SELECT * FROM ram_metrics ORDER BY timestamp DESC LIMIT 1'
    );
    
    res.json({
      cpu: cpuRows.length > 0 ? cpuRows[0] : null,
      ram: ramRows.length > 0 ? ramRows[0] : null
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