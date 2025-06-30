import React, { useState, useEffect, useRef } from 'react';
import io from 'socket.io-client';
import { Pie } from 'react-chartjs-2';
import {
  Chart as ChartJS,
  ArcElement,
  Tooltip,
  Legend,
} from 'chart.js';
import './App.css';

ChartJS.register(ArcElement, Tooltip, Legend);

const WEBSOCKET_URL = process.env.REACT_APP_WEBSOCKET_URL || '/websocket';

function App() {
  const [isConnected, setIsConnected] = useState(false);
  const [lastUpdate, setLastUpdate] = useState(null);
  const [metrics, setMetrics] = useState(null);
  const [connectionAttempts, setConnectionAttempts] = useState(0);

  const socketRef = useRef(null);

  // Formatear bytes a GB/MB/KB
  const formatBytes = (bytes) => {
    if (bytes < 1024) return `${bytes} B`;
    let kb = bytes / 1024;
    if (kb < 1024) return `${kb.toFixed(2)} KB`;
    let mb = kb / 1024;
    if (mb < 1024) return `${mb.toFixed(2)} MB`;
    let gb = mb / 1024;
    return `${gb.toFixed(2)} GB`;
  };

  useEffect(() => {
    socketRef.current = io(WEBSOCKET_URL, {
      transports: ['websocket', 'polling'],
      timeout: 10000,
      reconnection: true,
      reconnectionDelay: 3000,
      reconnectionAttempts: 10,
      forceNew: true
    });

    const socket = socketRef.current;

    socket.on('connect', () => {
      setIsConnected(true);
      setConnectionAttempts(0);
    });

    socket.on('disconnect', () => {
      setIsConnected(false);
    });

    socket.on('connect_error', () => {
      setIsConnected(false);
      setConnectionAttempts(prev => prev + 1);
    });

    socket.on('metrics_update', (data) => {
      setMetrics(data);
      setLastUpdate(data.hora || new Date().toLocaleString());
    });

    return () => {
      if (socket) {
        socket.removeAllListeners();
        socket.disconnect();
      }
    };
  }, []);

  // Datos para gráfica de CPU
  const cpuData = {
    labels: ['En Uso', 'Libre'],
    datasets: [
      {
        data: [
          metrics ? metrics.cpu.porcentaje_uso : 0,
          metrics ? metrics.cpu.porcentaje_libre : 100
        ],
        backgroundColor: ['#3498db', '#ecf0f1'],
        borderColor: ['#2980b9', '#bdc3c7'],
        borderWidth: 1
      }
    ]
  };

  // Datos para gráfica de RAM
  const ramData = {
    labels: ['En Uso', 'Libre'],
    datasets: [
      {
        data: [
          metrics ? metrics.ram.porcentaje_uso : 0,
          metrics ? 100 - (metrics ? metrics.ram.porcentaje_uso : 0) : 100
        ],
        backgroundColor: ['#e74c3c', '#ecf0f1'],
        borderColor: ['#c0392b', '#bdc3c7'],
        borderWidth: 1
      }
    ]
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>Monitor de Sistema en Tiempo Real</h1>
        <p>Bismarck Romero - 201708880</p>
        <div className={`connection-status ${isConnected ? 'connected' : 'disconnected'}`}>
          {isConnected ? '✓ Conectado via WebSocket' : '✗ Desconectado del WebSocket'}
          {connectionAttempts > 0 && !isConnected && ` (Intentos: ${connectionAttempts})`}
        </div>
        {lastUpdate && (
          <div className="last-update">
            Última actualización: {lastUpdate}
          </div>
        )}
      </header>

      <div className="dashboard">
        {/* CPU */}
        <div className="card">
          <h2>Uso de CPU</h2>
          <div className="chart-container">
            <Pie data={cpuData} options={{
              responsive: true,
              maintainAspectRatio: false,
              plugins: { legend: { position: 'bottom' } }
            }} />
          </div>
          <div className="metrics-details">
            {metrics ? (
              <>
                <p>Uso actual: <strong>{metrics ? metrics.cpu.porcentaje_uso : 0}%</strong></p>
                <p>Disponible: <strong>{metrics ? metrics.cpu.porcentaje_libre : 0}%</strong></p>
              </>
            ) : (
              <p>Esperando datos del WebSocket...</p>
            )}
          </div>
        </div>

        {/* RAM */}
        <div className="card">
          <h2>Memoria RAM</h2>
          <div className="chart-container">
            <Pie data={ramData} options={{
              responsive: true,
              maintainAspectRatio: false,
              plugins: { legend: { position: 'bottom' } }
            }} />
          </div>
          <div className="metrics-details">
            {metrics ? (
              <>
                <p>Memoria total: <strong>{metrics ? metrics.ram.total : 0} MB</strong></p>
                <p>Memoria en uso: <strong>{metrics ? metrics.ram.uso : 0} MB ({metrics ? metrics.ram.porcentaje_uso : 0}%)</strong></p>
                <p>Memoria libre: <strong>{metrics ? formatBytes(metrics.ram.libre) : 0}</strong></p>
              </>
            ) : (
              <p>Esperando datos del WebSocket...</p>
            )}
          </div>
        </div>
      </div>

      {/* Tabla de procesos */}
      <div className="processes-section">
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
              {metrics ? (
                <>
                  <tr className="corriendo">
                    <td className="estado">Corriendo</td>
                    <td className="cantidad">{metrics ? metrics.procesos.procesos_corriendo : 0}</td>
                    <td className="descripcion">Procesos activamente ejecutándose en CPU</td>
                  </tr>
                  <tr className="durmiendo">
                    <td className="estado">Durmiendo</td>
                    <td className="cantidad">{metrics ? metrics.procesos.procesos_durmiendo : 0}</td>
                    <td className="descripcion">Procesos esperando recursos o eventos</td>
                  </tr>
                  <tr className="zombie">
                    <td className="estado">Zombie</td>
                    <td className="cantidad">{metrics ? metrics.procesos.procesos_zombie : 0}</td>
                    <td className="descripcion">Procesos terminados pendientes de limpieza</td>
                  </tr>
                  <tr className="parados">
                    <td className="estado">Parados</td>
                    <td className="cantidad">{metrics ? metrics.procesos.procesos_parados : 0}</td>
                    <td className="descripcion">Procesos suspendidos o detenidos</td>
                  </tr>
                  <tr className="total">
                    <td className="estado">Total</td>
                    <td className="cantidad">{metrics ? metrics.procesos.total_procesos : 0}</td>
                    <td className="descripcion">Total de procesos en el sistema</td>
                  </tr>
                </>
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

      <footer className="App-footer">
        <p>Monitor de Sistema &copy; 2025 - USAC Sistemas Operativos 1</p>
      </footer>
    </div>
  );
}

export default App;