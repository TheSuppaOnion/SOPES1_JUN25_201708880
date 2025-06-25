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
  ArcElement,  // ← AÑADIR para gráficas pie
} from 'chart.js';
import { Pie } from 'react-chartjs-2';  // ← CAMBIAR de Line a Pie
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
  ArcElement  // ← AÑADIR
);

// Usar la configuración dinámica
const WEBSOCKET_URL = config.WEBSOCKET_URL;

function App() {
  const [isConnected, setIsConnected] = useState(false);
  const [lastUpdate, setLastUpdate] = useState(null);
  const [processes, setProcesses] = useState([]);
  
  // Datos para gráficas pie (como Fase 1)
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
    console.log('Conectando a WebSocket:', WEBSOCKET_URL);
    
    socketRef.current = io(WEBSOCKET_URL, {
      transports: ['websocket', 'polling'],
      timeout: 20000,
      reconnection: true,
      reconnectionDelay: 2000,
      reconnectionAttempts: 5
    });

    const socket = socketRef.current;

    socket.on('connect', () => {
      console.log('Conectado al WebSocket');
      setIsConnected(true);
      socket.emit('request_metrics');
    });

    socket.on('disconnect', () => {
      console.log('Desconectado del WebSocket');
      setIsConnected(false);
    });

    socket.on('connect_error', (error) => {
      console.error('Error de conexión:', error);
      setIsConnected(false);
    });

    socket.on('metrics_update', (data) => {
      console.log('Métricas recibidas:', data);
      updateCharts(data);
      updateProcessTable(data);
      setLastUpdate(new Date().toLocaleString());
    });

    socket.on('welcome', (data) => {
      console.log('Bienvenida:', data);
    });

    socket.on('error', (error) => {
      console.error('Error del servidor:', error);
    });

    return () => {
      if (socket) {
        socket.disconnect();
      }
    };
  }, []);

  const updateCharts = (data) => {
    if (!data.cpu || !data.ram) return;

    const cpuUsage = data.cpu.porcentaje_uso || 0;
    const ramUsage = data.ram.porcentaje_uso || 0;

    // Actualizar gráfica pie de CPU
    setCpuData(prevData => ({
      ...prevData,
      datasets: [{
        ...prevData.datasets[0],
        data: [cpuUsage, 100 - cpuUsage]
      }]
    }));

    // Actualizar gráfica pie de RAM
    setRamData(prevData => ({
      ...prevData,
      datasets: [{
        ...prevData.datasets[0],
        data: [ramUsage, 100 - ramUsage]
      }]
    }));
  };

  const updateProcessTable = (data) => {
    if (!data.procesos) return;

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
        descripción: 'Procesos terminados pero no eliminados'
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
        cantidad: data.procesos.total_processos || 0,
        descripcion: 'Total de procesos en el sistema'
      }
    ];

    setProcesses(processInfo);
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>Monitor de Sistema en Tiempo Real</h1>
        <div className={`connection-status ${isConnected ? 'connected' : 'disconnected'}`}>
          {isConnected ? 'Conectado' : 'Desconectado'}
        </div>
        {lastUpdate && (
          <div className="last-update">
            Última actualización: {lastUpdate}
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
                  text: 'CPU Usage'
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
                  text: 'RAM Usage'
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
                {processes.map(process => (
                  <tr key={process.id} className={process.estado.toLowerCase()}>
                    <td className="estado">{process.estado}</td>
                    <td className="cantidad">{process.cantidad.toLocaleString()}</td>
                    <td className="descripcion">{process.descripcion}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      </main>

      <footer className="App-footer">
        <p>Sistema de Monitoreo - USAC Sistemas Operativos 1</p>
        <p>Bismarck Romero - 201708880</p>
      </footer>
    </div>
  );
}

export default App;