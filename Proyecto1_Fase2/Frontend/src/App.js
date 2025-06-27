import React, { useState, useEffect, useRef } from 'react';
import io from 'socket.io-client';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  ArcElement,
} from 'chart.js';
import { Pie } from 'react-chartjs-2';
import './App.css';

ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  ArcElement
);

// Solo necesitas WebSocket URL
const WEBSOCKET_URL = process.env.REACT_APP_WEBSOCKET_URL || '/websocket';

function App() {
  const [isConnected, setIsConnected] = useState(false);
  const [lastUpdate, setLastUpdate] = useState(null);
  const [processes, setProcesses] = useState([]);
  const [connectionAttempts, setConnectionAttempts] = useState(0);
  const [cpuDetails, setCpuDetails] = useState(null);
  const [ramDetails, setRamDetails] = useState(null);
  
  // Datos iniciales para gráficas pie
  const [cpuData, setCpuData] = useState({
    labels: ['En Uso', 'Libre'],
    datasets: [{
      data: [0, 100],
      backgroundColor: ['#3498db', '#ecf0f1'],
      borderColor: ['#2980b9', '#bdc3c7'],
      borderWidth: 1
    }]
  });
  
  const [ramData, setRamData] = useState({
    labels: ['En Uso', 'Libre'],
    datasets: [{
      data: [0, 100],
      backgroundColor: ['#e74c3c', '#ecf0f1'],
      borderColor: ['#c0392b', '#bdc3c7'],
      borderWidth: 1
    }]
  });

  const socketRef = useRef(null);

  // Opciones de gráfica
  const chartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      title: {
        display: false
      },
      tooltip: {
        callbacks: {
          label: function(context) {
            return `${context.label}: ${context.raw}%`;
          }
        }
      },
      legend: {
        position: 'bottom'
      }
    }
  };

  // Función para formatear KB
  const formatKB = (kilobytes, decimals = 2) => {
    if (kilobytes === 0) return '0 KB';

    const k = 1024;
    const dm = decimals < 0 ? 0 : decimals;
    const sizes = ['KB', 'MB', 'GB', 'TB', 'PB'];

    const i = Math.floor(Math.log(kilobytes) / Math.log(k));
    const sizeIndex = Math.min(i, sizes.length - 1);
    
    return parseFloat((kilobytes / Math.pow(k, sizeIndex)).toFixed(dm)) + ' ' + sizes[sizeIndex];
  };

  useEffect(() => {
    console.log('Conectando al WebSocket API en:', WEBSOCKET_URL);
    
    // Solo conexión WebSocket - sin APIs REST
    socketRef.current = io(WEBSOCKET_URL, {
      transports: ['websocket', 'polling'],
      timeout: 10000,
      reconnection: true,
      reconnectionDelay: 3000,
      reconnectionAttempts: 10,
      forceNew: true
    });

    const socket = socketRef.current;

    // EVENTOS DE CONEXIÓN
    socket.on('connect', () => {
      console.log('✓ Conectado al WebSocket API');
      setIsConnected(true);
      setConnectionAttempts(0);
    });

    socket.on('disconnect', (reason) => {
      console.log('✗ Desconectado del WebSocket. Razón:', reason);
      setIsConnected(false);
    });

    socket.on('connect_error', (error) => {
      console.error('✗ Error de conexión WebSocket:', error.message);
      setIsConnected(false);
      setConnectionAttempts(prev => prev + 1);
    });

    socket.on('reconnect', (attemptNumber) => {
      console.log(`✓ Reconectado después de ${attemptNumber} intentos`);
      setIsConnected(true);
    });

    // EVENTO PRINCIPAL: Recibir métricas del WebSocket API
    socket.on('metrics_update', (data) => {
      console.log('✓ Métricas recibidas del WebSocket:', {
        timestamp: data.timestamp,
        cpu: data.cpu?.porcentaje_uso,
        ram: data.ram?.porcentaje_uso,
        procesos: data.procesos?.total_procesos
      });
      
      updateCharts(data);
      updateProcessTable(data);
      setLastUpdate(new Date().toLocaleString('es-GT', {
        timeZone: 'America/Guatemala'
      }));
    });

    // Cleanup al desmontar
    return () => {
      if (socket) {
        socket.removeAllListeners();
        socket.disconnect();
      }
    };
  }, []);

  // Actualizar gráficas
  const updateCharts = (data) => {
    if (!data || !data.cpu || !data.ram) {
      console.warn('Datos incompletos recibidos:', data);
      return;
    }

    const cpuUsage = data.cpu.porcentaje_uso || 0;
    const ramUsage = data.ram.porcentaje_uso || 0;

    // Actualizar CPU
    setCpuData({
      labels: ['En Uso', 'Libre'],
      datasets: [{
        data: [cpuUsage, 100 - cpuUsage],
        backgroundColor: ['#3498db', '#ecf0f1'],
        borderColor: ['#2980b9', '#bdc3c7'],
        borderWidth: 1
      }]
    });

    // Actualizar RAM
    setRamData({
      labels: ['En Uso', 'Libre'],
      datasets: [{
        data: [ramUsage, 100 - ramUsage],
        backgroundColor: ['#e74c3c', '#ecf0f1'],
        borderColor: ['#c0392b', '#bdc3c7'],
        borderWidth: 1
      }]
    });

    // Guardar detalles
    setCpuDetails({
      uso: cpuUsage,
      libre: 100 - cpuUsage
    });

    setRamDetails({
      total: data.ram.total || 0,
      uso: data.ram.uso || 0,
      libre: data.ram.libre || 0,
      porcentaje_uso: ramUsage,
      porcentaje_libre: 100 - ramUsage
    });
  };

  // Actualizar tabla de procesos
  const updateProcessTable = (data) => {
    if (!data || !data.procesos) {
      console.warn('Datos de procesos incompletos:', data);
      return;
    }

    const processInfo = [
      {
        id: 1,
        estado: 'Corriendo',
        cantidad: data.procesos.procesos_corriendo || 0,
        descripcion: 'Procesos activamente ejecutándose en CPU'
      },
      {
        id: 2,
        estado: 'Durmiendo',
        cantidad: data.procesos.procesos_durmiendo || 0,
        descripcion: 'Procesos esperando recursos o eventos'
      },
      {
        id: 3,
        estado: 'Zombie',
        cantidad: data.procesos.procesos_zombie || 0,
        descripcion: 'Procesos terminados pendientes de limpieza'
      },
      {
        id: 4,
        estado: 'Parados',
        cantidad: data.procesos.procesos_parados || 0,
        descripcion: 'Procesos suspendidos o detenidos'
      },
      {
        id: 5,
        estado: 'Total',
        cantidad: data.procesos.total_procesos || 0,
        descripcion: 'Total de procesos en el sistema'
      }
    ];

    setProcesses(processInfo);
  };

  return (
    <div className="App">
      <header>
        <div className="container">
          <h1>Monitor de Sistema en Tiempo Real - Fase 2</h1>
          <p>Bismarck Romero - 201708880</p>
          
          <div className={`connection-status ${isConnected ? 'connected' : 'disconnected'}`}>
            {isConnected ? '✓ Conectado via WebSocket' : '✗ Desconectado del WebSocket'}
            {connectionAttempts > 0 && !isConnected && ` (Intentos: ${connectionAttempts})`}
          </div>
          
          {lastUpdate && (
            <div className="updated-time">
              Última actualización: {lastUpdate}
            </div>
          )}
        </div>
      </header>

      <div className="container">
        <div className="dashboard">
          {/* Gráfica de CPU */}
          <div className="card">
            <h2>Uso de CPU</h2>
            <div className="chart-container">
              <Pie data={cpuData} options={chartOptions} />
            </div>
            <div className="metrics-details">
              {cpuDetails ? (
                <>
                  <p>Uso actual: <strong>{cpuDetails.uso.toFixed(1)}%</strong></p>
                  <p>Disponible: <strong>{cpuDetails.libre.toFixed(1)}%</strong></p>
                </>
              ) : (
                <p>Esperando datos del WebSocket...</p>
              )}
            </div>
          </div>

          {/* Gráfica de RAM */}
          <div className="card">
            <h2>Memoria RAM</h2>
            <div className="chart-container">
              <Pie data={ramData} options={chartOptions} />
            </div>
            <div className="metrics-details">
              {ramDetails ? (
                <>
                  <p>Memoria total: <strong>{formatKB(ramDetails.total)}</strong></p>
                  <p>Memoria en uso: <strong>{formatKB(ramDetails.uso)} ({ramDetails.porcentaje_uso.toFixed(1)}%)</strong></p>
                  <p>Memoria libre: <strong>{formatKB(ramDetails.libre)} ({ramDetails.porcentaje_libre.toFixed(1)}%)</strong></p>
                </>
              ) : (
                <p>Esperando datos del WebSocket...</p>
              )}
            </div>
          </div>
        </div>

        {/* Tabla de procesos detallada */}
        <div className="card" style={{ marginTop: '30px' }}>
          <h2>Información Detallada de Procesos</h2>
          <div className="table-container">
            <table className="processes-table">
              <thead>
                <tr>
                  <th>Estado del Proceso</th>
                  <th>Cantidad</th>
                  <th>Descripción</th>
                </tr>
              </thead>
              <tbody>
                {processes.length > 0 ? (
                  processes.map(process => (
                    <tr key={process.id} className={process.estado.toLowerCase()}>
                      <td className="estado">{process.estado}</td>
                      <td className="cantidad">{process.cantidad.toLocaleString()}</td>
                      <td className="descripcion">{process.descripcion}</td>
                    </tr>
                  ))
                ) : (
                  <tr>
                    <td colSpan="3" style={{ textAlign: 'center', fontStyle: 'italic', color: '#777' }}>
                      Esperando datos de procesos del WebSocket API...
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <footer>
        <div className="container">
          <p>Monitor de Sistema &copy; 2025 - USAC Sistemas Operativos 1</p>
          <p>Frontend React - Solo conectando via WebSocket API</p>
        </div>
      </footer>
    </div>
  );
}

export default App;