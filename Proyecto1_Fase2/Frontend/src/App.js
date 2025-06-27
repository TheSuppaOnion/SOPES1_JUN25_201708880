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
import config from './config';

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

const WEBSOCKET_URL = config.WEBSOCKET_URL;

function App() {
  const [isConnected, setIsConnected] = useState(false);
  const [lastUpdate, setLastUpdate] = useState(null);
  const [processes, setProcesses] = useState([]);
  const [connectionAttempts, setConnectionAttempts] = useState(0);
  const [lastDataReceived, setLastDataReceived] = useState(null);
  
  // Datos iniciales para gráficas pie
  const [cpuData, setCpuData] = useState({
    labels: ['En Uso', 'Libre'],
    datasets: [{
      label: 'CPU Usage (%)',
      data: [0, 100],
      backgroundColor: ['#FF6384', '#36A2EB'],
      borderColor: ['#FF6384', '#36A2EB'],
      borderWidth: 1
    }]
  });
  
  const [ramData, setRamData] = useState({
    labels: ['En Uso', 'Libre'],
    datasets: [{
      label: 'RAM Usage (%)',
      data: [0, 100],
      backgroundColor: ['#FFCE56', '#4BC0C0'],
      borderColor: ['#FFCE56', '#4BC0C0'],
      borderWidth: 1
    }]
  });

  const socketRef = useRef(null);

  const chartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        position: 'bottom',
      },
      title: {
        display: true,
        text: 'Monitoreo en Tiempo Real'
      },
      tooltip: {
        callbacks: {
          label: function(context) {
            return `${context.label}: ${context.parsed}%`;
          }
        }
      }
    }
  };

  useEffect(() => {
    console.log('Iniciando conexión WebSocket a:', WEBSOCKET_URL);
    
    // Configurar socket solo para ESCUCHAR
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
      
      // NO enviar request_metrics - Solo esperar datos automáticos
      console.log('Frontend listo para recibir datos automáticos...');
    });

    socket.on('disconnect', (reason) => {
      console.log('X Desconectado del WebSocket. Razón:', reason);
      setIsConnected(false);
    });

    socket.on('connect_error', (error) => {
      console.error('X Error de conexión WebSocket:', error.message);
      setIsConnected(false);
      setConnectionAttempts(prev => prev + 1);
    });

    socket.on('reconnect', (attemptNumber) => {
      console.log(`✓ Reconectado después de ${attemptNumber} intentos`);
      setIsConnected(true);
    });

    socket.on('reconnect_error', (error) => {
      console.error('X Error en reconexión:', error.message);
    });

    // EVENTOS DE DATOS - SOLO ESCUCHAR
    socket.on('welcome', (data) => {
      console.log('✓ Mensaje de bienvenida:', data);
    });

    // EVENTO PRINCIPAL: Recibir métricas automáticamente
    socket.on('metrics_update', (data) => {
      console.log('✓ Métricas recibidas automáticamente:', {
        timestamp: data.timestamp,
        cpu: data.cpu?.porcentaje_uso,
        ram: data.ram?.porcentaje_uso,
        procesos: data.procesos?.total_procesos,
        api_source: data.api_source
      });
      
      updateCharts(data);
      updateProcessTable(data);
      setLastUpdate(new Date().toLocaleString('es-GT', {
        timeZone: 'America/Guatemala'
      }));
      setLastDataReceived(data);
    });

    // Otros eventos de datos automáticos
    socket.on('historical_data', (data) => {
      console.log('✓ Datos históricos recibidos:', data);
    });

    socket.on('system_stats', (data) => {
      console.log('✓ Estadísticas del sistema recibidas:', data);
    });

    socket.on('error', (error) => {
      console.error('X Error del WebSocket API:', error);
    });

    // Cleanup al desmontar
    return () => {
      console.log('Desconectando WebSocket...');
      if (socket) {
        socket.removeAllListeners();
        socket.disconnect();
      }
    };
  }, []); // Solo ejecutar una vez

  // Función para actualizar gráficas con datos recibidos
  const updateCharts = (data) => {
    if (!data || !data.cpu || !data.ram) {
      console.warn('Datos incompletos recibidos:', data);
      return;
    }

    const cpuUsage = Math.round((data.cpu.porcentaje_uso || 0) * 100) / 100;
    const ramUsage = Math.round((data.ram.porcentaje_uso || 0) * 100) / 100;

    // Actualizar gráfica pie de CPU
    setCpuData(prevData => ({
      ...prevData,
      datasets: [{
        ...prevData.datasets[0],
        data: [cpuUsage, 100 - cpuUsage],
        label: `CPU: ${cpuUsage}%`
      }]
    }));

    // Actualizar gráfica pie de RAM
    setRamData(prevData => ({
      ...prevData,
      datasets: [{
        ...prevData.datasets[0],
        data: [ramUsage, 100 - ramUsage],
        label: `RAM: ${ramUsage}% (${data.ram.total_gb?.toFixed(1) || 'N/A'} GB)`
      }]
    }));
  };

  // Función para actualizar tabla de procesos con datos recibidos
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
        descripcion: 'Procesos actualmente en ejecución'
      },
      {
        id: 2,
        estado: 'Durmiendo',
        cantidad: data.procesos.procesos_durmiendo || 0,
        descripcion: 'Procesos en estado de espera'
      },
      {
        id: 3,
        estado: 'Zombie',
        cantidad: data.procesos.procesos_zombie || 0,
        descripcion: 'Procesos terminados pero no eliminados'
      },
      {
        id: 4,
        estado: 'Parados',
        cantidad: data.procesos.procesos_parados || 0,
        descripcion: 'Procesos detenidos'
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
      <header className="App-header">
        <h1>Monitor de Sistema en Tiempo Real - Fase 2</h1>
        <p>Bismarck Romero - 201708880</p>
        
        <div className={`connection-status ${isConnected ? 'connected' : 'disconnected'}`}>
          {isConnected ? '✓ Conectado - Esperando datos...' : 'X Desconectado'}
          {connectionAttempts > 0 && !isConnected && (
            <span> (Intentos: {connectionAttempts})</span>
          )}
        </div>
        
        {lastUpdate && (
          <div className="last-update">
            Última actualización: {lastUpdate}
            {lastDataReceived?.api_source && (
              <span> | Fuente: API {lastDataReceived.api_source}</span>
            )}
          </div>
        )}
        
        {!isConnected && (
          <div style={{ color: '#ffcccb', fontSize: '0.9em', marginTop: '10px' }}>
            Esperando conexión con WebSocket API en {WEBSOCKET_URL}
          </div>
        )}
      </header>

      <main className="dashboard">
        <section className="chart-section">
          <h2>Porcentaje de Utilización del CPU</h2>
          <div className="chart-container">
            <Pie data={cpuData} options={{
              ...chartOptions,
              plugins: {
                ...chartOptions.plugins,
                title: {
                  display: true,
                  text: `CPU: ${cpuData.datasets[0].data[0]}% en uso`
                }
              }
            }} />
          </div>
        </section>

        <section className="chart-section">
          <h2>Porcentaje de Utilización de la RAM</h2>
          <div className="chart-container">
            <Pie data={ramData} options={{
              ...chartOptions,
              plugins: {
                ...chartOptions.plugins,
                title: {
                  display: true,
                  text: `RAM: ${ramData.datasets[0].data[0]}% en uso`
                }
              }
            }} />
          </div>
        </section>

        <section className="processes-section">
          <h2>Información de Procesos</h2>
          <div className="table-container">
            <table className="processes-table">
              <thead>
                <tr>
                  <th>Estado</th>
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
                    <td colSpan="3" style={{ textAlign: 'center', fontStyle: 'italic', color: '#666' }}>
                      Esperando datos de procesos...
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </section>
      </main>

      <footer className="App-footer">
        <p>Sistema de Monitoreo - USAC Sistemas Operativos 1</p>
        <p>Frontend React - Solo recibe datos via WebSocket</p>
        <p>Flujo: Locust → APIs → BD → WebSocket API → Frontend</p>
      </footer>
    </div>
  );
}

export default App;