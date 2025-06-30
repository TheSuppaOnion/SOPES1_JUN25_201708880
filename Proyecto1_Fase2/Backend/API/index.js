const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json({ limit: '20mb' }));
app.use(cors());

// Configuración de base de datos para MySQL local
const dbConfig = {
    host: process.env.DB_HOST || '172.28.84.245',
    port: process.env.DB_PORT || 3306,
    user: process.env.DB_USER || 'monitor',
    password: process.env.DB_PASSWORD || 'monitor123',
    database: process.env.DB_NAME || 'monitoring',
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
};

let pool;

// Inicializar pool de conexiones
async function initializeDatabase() {
    try {
        pool = mysql.createPool(dbConfig);
        
        // Probar conexión
        const connection = await pool.getConnection();
        console.log('✓ Conectado a MySQL desde API Node.js');
        connection.release();
        
        // Crear tabla si no existe
        await createTables();
        
    } catch (error) {
        console.error('X Error conectando a MySQL:', error.message);
        throw error;
    }
}

// Crear tablas necesarias
async function createTables() {
    const createMetricsTable = `
        CREATE TABLE IF NOT EXISTS metrics (
            id INT AUTO_INCREMENT PRIMARY KEY,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            total_ram INT,
            ram_libre BIGINT,
            uso_ram INT,
            porcentaje_ram DECIMAL(5,2),
            porcentaje_cpu_uso DECIMAL(5,2),
            porcentaje_cpu_libre DECIMAL(5,2),
            procesos_corriendo INT,
            total_procesos INT,
            procesos_durmiendo INT,
            procesos_zombie INT,
            procesos_parados INT,
            hora VARCHAR(50),
            api_source VARCHAR(20) DEFAULT 'nodejs'
        )
    `;
    
    try {
        await pool.execute(createMetricsTable);
        console.log('✓ Tabla metrics verificada/creada');
    } catch (error) {
        console.error('X Error creando tabla:', error.message);
    }
}

// ENDPOINT PRINCIPAL - Recibir datos de Locust via Ingress
app.post('/api/data', async (req, res) => {
    let data = req.body;

    // Si es un solo objeto, lo convertimos en arreglo
    if (!Array.isArray(data)) {
        data = [data];
    }

    try {
        for (const item of data) {
            // Validar datos requeridos
            if (item.total_ram === undefined || item.porcentaje_cpu_uso === undefined) {
                return res.status(400).json({
                    success: false,
                    error: 'Datos faltantes: total_ram y porcentaje_cpu_uso son requeridos'
                });
            }
            const insertQuery = `
                INSERT INTO metrics (
                    total_ram, ram_libre, uso_ram, porcentaje_ram,
                    porcentaje_cpu_uso, porcentaje_cpu_libre,
                    procesos_corriendo, total_procesos, procesos_durmiendo,
                    procesos_zombie, procesos_parados, hora, api_source
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            `;
            const values = [
                item.total_ram || 0,
                item.ram_libre || 0,
                item.uso_ram || 0,
                item.porcentaje_ram || 0,
                item.porcentaje_cpu_uso || 0,
                item.porcentaje_cpu_libre || 0,
                item.procesos_corriendo || 0,
                item.total_procesos || 0,
                item.procesos_durmiendo || 0,
                item.procesos_zombie || 0,
                item.procesos_parados || 0,
                item.hora || new Date().toISOString(),
                'nodejs'
            ];
            await pool.execute(insertQuery, values);
        }
        return res.status(201).json({ success: true, message: 'Datos guardados' });
    } catch (error) {
        console.error('X Error procesando datos:', error.message);
        return res.status(500).json({
            success: false,
            error: 'Error interno del servidor',
            api: 'nodejs'
        });
    }
});

// Endpoint para obtener métricas (para frontend)
app.get('/api/metrics', async (req, res) => {
    try {
        const query = `
            SELECT * FROM metrics 
            ORDER BY timestamp DESC 
            LIMIT 1
        `;
        
        const [rows] = await pool.execute(query);
        
        if (rows.length === 0) {
            return res.json({
                cpu: { porcentaje_uso: 0 },
                ram: { porcentaje_uso: 0, total_gb: 0, libre_gb: 0 },
                procesos: { total_procesos: 0, procesos_corriendo: 0 }
            });
        }
        
        const latest = rows[0];
        
        res.json({
            cpu: {
                porcentaje_uso: parseFloat(latest.porcentaje_cpu_uso) || 0
            },
            ram: {
                porcentaje_uso: parseFloat(latest.porcentaje_ram) || 0,
                total_gb: (latest.total_ram || 0) / 1024,
                libre_gb: (latest.ram_libre || 0) / (1024 * 1024 * 1024)
            },
            procesos: {
                total_procesos: latest.total_procesos || 0,
                procesos_corriendo: latest.procesos_corriendo || 0,
                procesos_durmiendo: latest.procesos_durmiendo || 0,
                procesos_zombie: latest.procesos_zombie || 0,
                procesos_parados: latest.procesos_parados || 0
            },
            timestamp: latest.timestamp,
            api_source: latest.api_source
        });
        
    } catch (error) {
        console.error('X Error obteniendo métricas:', error.message);
        res.status(500).json({ error: 'Error obteniendo métricas' });
    }
});

// Health check
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        service: 'api-nodejs',
        timestamp: new Date().toISOString(),
        database: pool ? 'connected' : 'disconnected'
    });
});

// Estadísticas
app.get('/api/stats', async (req, res) => {
    try {
        const [countResult] = await pool.execute('SELECT COUNT(*) as total FROM metrics');
        const [nodeJSCount] = await pool.execute('SELECT COUNT(*) as nodejs_total FROM metrics WHERE api_source = "nodejs"');
        
        res.json({
            total_records: countResult[0].total,
            nodejs_records: nodeJSCount[0].nodejs_total,
            api: 'nodejs'
        });
    } catch (error) {
        res.status(500).json({ error: 'Error obteniendo estadísticas' });
    }
});

app.get('/', (req, res) => {
          res.status(200).send('OK');
});

// Inicializar servidor
async function startServer() {
    try {
        await initializeDatabase();
        
        app.listen(PORT, '0.0.0.0', () => {
            console.log(`✓ API Node.js ejecutándose en puerto ${PORT}`);
            console.log(`✓ Base de datos: ${dbConfig.host}:${dbConfig.port}`);
            console.log('✓ Esperando datos de Locust via Ingress...');
        });
        
    } catch (error) {
        console.error('X Error iniciando servidor:', error.message);
        process.exit(1);
    }
}

// Manejo de señales
process.on('SIGINT', async () => {
    console.log('Cerrando API Node.js...');
    if (pool) {
        await pool.end();
    }
    process.exit(0);
});

startServer();