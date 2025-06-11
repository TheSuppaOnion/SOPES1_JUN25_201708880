const express = require('express');
const cors = require('cors');
const app = express();
const PORT = process.env.PORT || 3000;

// Almacenamiento en memoria para las métricas
// En un entorno de producción, usarías una base de datos
let metricsHistory = {
  cpu: [],
  ram: []
};

// Configuración de middleware
app.use(cors());
app.use(express.json());

// Limitamos el historial para no consumir demasiada memoria
const MAX_HISTORY_LENGTH = 100;

// Endpoint para recibir métricas del agente Go
app.post('/api/data', (req, res) => {
  const { timestamp, cpu, ram } = req.body;
  
  if (!timestamp || !cpu || !ram) {
    return res.status(400).json({ error: 'Datos incompletos' });
  }
  
  // Guardar datos de CPU
  metricsHistory.cpu.push({
    timestamp,
    porcentajeUso: cpu.porcentajeUso
  });
  
  // Guardar datos de RAM
  metricsHistory.ram.push({
    timestamp,
    total: ram.total,
    libre: ram.libre,
    uso: ram.uso,
    porcentajeUso: ram.porcentajeUso
  });
  
  // Mantener solo los últimos N registros
  if (metricsHistory.cpu.length > MAX_HISTORY_LENGTH) {
    metricsHistory.cpu.shift();
  }
  if (metricsHistory.ram.length > MAX_HISTORY_LENGTH) {
    metricsHistory.ram.shift();
  }
  
  console.log(`Métricas recibidas - Timestamp: ${new Date(timestamp * 1000).toISOString()}`);
  
  res.status(201).json({ message: 'Métricas recibidas correctamente' });
});

// Endpoint para obtener métricas de CPU
app.get('/api/metrics/cpu', (req, res) => {
  res.json(metricsHistory.cpu);
});

// Endpoint para obtener métricas de RAM
app.get('/api/metrics/ram', (req, res) => {
  res.json(metricsHistory.ram);
});

// Endpoint para obtener las métricas más recientes
app.get('/api/metrics/latest', (req, res) => {
  const latestCPU = metricsHistory.cpu.length > 0 ? metricsHistory.cpu[metricsHistory.cpu.length - 1] : null;
  const latestRAM = metricsHistory.ram.length > 0 ? metricsHistory.ram[metricsHistory.ram.length - 1] : null;
  
  res.json({
    cpu: latestCPU,
    ram: latestRAM
  });
});

// Iniciar el servidor
app.listen(PORT, () => {
  console.log(`API ejecutándose en http://localhost:${PORT}`);
});