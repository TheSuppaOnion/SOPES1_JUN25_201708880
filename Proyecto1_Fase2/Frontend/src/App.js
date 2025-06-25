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
} from 'chart.js';
import { Line } from 'react-chartjs-2';
import './App.css';
import config from './config';

ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend
);

// Usar la configuración dinámica
const WEBSOCKET_URL = config.WEBSOCKET_URL;

function App() {
  // ...resto del código sin cambios...
  const [isConnected, setIsConnected] = useState(false);
  const [lastUpdate, setLastUpdate] = useState(null);
  const [processes, setProcesses] = useState([]);
  
  // Datos para gráficas en tiempo real
  const [cpuData, setCpuData] = useState({
    labels: [],
    datasets: [{
      label: 'CPU Usage (%)',
      data: [],
      borderColor: 'rgb(255, 99, 132)',
      backgroundColor: 'rgba(255, 99, 132, 0.2)',
      tension: 0.1
    }]
  });
  
  const [ramData, setRamData] = useState({
    labels: [],
    datasets: [{
      label: 'RAM Usage (%)',
      data: [],
      borderColor: 'rgb(54, 162, 235)',
      backgroundColor: 'rgba(54, 162, 235, 0.2)',
      tension: 0.1
    }]
  });

  const socketRef = useRef(null);
  const maxDataPoints = 20;

  const chartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        position: 'top',
      },
      title: {
        display: true,
        text: 'Monitoreo en Tiempo Real'
      }
    },
    scales: {
      y: {
        beginAtZero: true,
        max: 100,
        ticks: {
          callback: function(value) {
            return value + '%';
          }
        }
      },
      x: {
        display: true,
        title: {
          display: true,
          text: 'Tiempo'
        }
      }
    },
    animation: {
      duration: 0
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

    const currentTime = new Date().toLocaleTimeString();
    const cpuUsage = data.cpu.porcentaje_uso || 0;
    const ramUsage = data.ram.porcentaje_uso || 0;

    setCpuData(prevData => {
      const newLabels = [...prevData.labels, currentTime];
      const newData = [...prevData.datasets[0].data, cpuUsage];

      if (newLabels.length > maxDataPoints) {
        newLabels.shift();
        newData.shift();
      }

      return {
        labels: newLabels,
        datasets: [{
          ...prevData.datasets[0],
          data: newData
        }]
      };
    });

    setRamData(prevData => {
      const newLabels = [...prevData.labels, currentTime];
      const newData = [...prevData.datasets[0].data, ramUsage];

      if (newLabels.length > maxDataPoints) {
        newLabels.shift();
        newData.shift();
      }

      return {
        labels: newLabels,
        datasets: [{
          ...prevData.datasets[0],
          data: newData
        }]
      };
    });
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
            <Line data={cpuData} options={{
              ...chartOptions,
              plugins: {
                ...chartOptions.plugins,
                title: {
                  display: true,
                  text: 'CPU Usage - Tiempo Real'
                }
              }
            }} />
          </div>
        </section>

        <section className="chart-section">
          <h2>Porcentaje de Utilización de la RAM</h2>
          <div className="chart-container">
            <Line data={ramData} options={{
              ...chartOptions,
              plugins: {
                ...chartOptions.plugins,
                title: {
                  display: true,
                  text: 'RAM Usage - Tiempo Real'
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