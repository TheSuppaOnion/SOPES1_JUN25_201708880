package main

import (
    "bytes"
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "os"
    "os/signal"
    "sync"
    "syscall"
    "time"
)

// CPUMetric representa la métrica de CPU
type CPUMetric struct {
    PorcentajeUso int64 `json:"porcentajeUso"`
}

// RAMMetric representa la métrica de RAM
type RAMMetric struct {
    Total        int64 `json:"total"`
    Libre        int64 `json:"libre"`
    Uso          int64 `json:"uso"`
    PorcentajeUso int64 `json:"porcentajeUso"`
}

type Procesos struct {
    ProcesosCorriendo  int `json:"procesos_corriendo"`
    TotalProcesos     int `json:"total_processos"`
    ProcesosDurmiendo int `json:"procesos_durmiendo"`
    ProcesosZombie    int `json:"procesos_zombie"`
    ProcesosParados   int `json:"procesos_parados"`
}

// MetricsPayload es la estructura que se enviará a la API
type MetricsPayload struct {
    Timestamp int64      `json:"timestamp"`
    CPU       *CPUMetric `json:"cpu"`
    RAM       *RAMMetric `json:"ram"`
    Procesos  *Procesos `json:"procesos"`
}

// readProcFile lee un archivo en /proc y devuelve su contenido
func readProcFile(filePath string) ([]byte, error) {
    data, err := os.ReadFile(filePath)
    if err != nil {
        return nil, fmt.Errorf("error reading %s: %v", filePath, err)
    }
    return data, nil
}

// sendMetricsToAPI envía las métricas recolectadas a la API de Node.js
func sendMetricsToAPI(apiURL string, metrics MetricsPayload) error {
    jsonData, err := json.Marshal(metrics)
    if err != nil {
        return fmt.Errorf("error marshalling metrics: %v", err)
    }

    resp, err := http.Post(apiURL, "application/json", bytes.NewBuffer(jsonData))
    if err != nil {
        return fmt.Errorf("error sending metrics to API: %v", err)
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
        return fmt.Errorf("API returned non-200/201 status: %d", resp.StatusCode)
    }

    return nil
}

// monitorCPU monitorea la CPU y envía métricas al canal
func monitorCPU(cpuPath string, interval time.Duration, cpuChan chan<- *CPUMetric, wg *sync.WaitGroup) {
    defer wg.Done()
    log.Printf("Iniciando monitoreo de CPU desde %s cada %v", cpuPath, interval)
    
    for {
        // Recolectar métricas de CPU
        cpuData, err := readProcFile(cpuPath)
        if err != nil {
            log.Printf("Error al leer métricas de CPU: %v", err)
            time.Sleep(interval)
            continue
        }

        var cpuMetric CPUMetric
        if err := json.Unmarshal(cpuData, &cpuMetric); err != nil {
            log.Printf("Error al parsear métricas de CPU: %v", err)
            time.Sleep(interval)
            continue
        }

        // Enviar métricas al canal
        log.Printf("Métrica de CPU recolectada: %d%%", cpuMetric.PorcentajeUso)
        cpuChan <- &cpuMetric
        
        // Esperar hasta el próximo intervalo
        time.Sleep(interval)
    }
}

// monitorRAM monitorea la RAM y envía métricas al canal
func monitorRAM(ramPath string, interval time.Duration, ramChan chan<- *RAMMetric, wg *sync.WaitGroup) {
    defer wg.Done()
    log.Printf("Iniciando monitoreo de RAM desde %s cada %v", ramPath, interval)
    
    for {
        // Recolectar métricas de RAM
        ramData, err := readProcFile(ramPath)
        if err != nil {
            log.Printf("Error al leer métricas de RAM: %v", err)
            time.Sleep(interval)
            continue
        }

        var ramMetric RAMMetric
        if err := json.Unmarshal(ramData, &ramMetric); err != nil {
            log.Printf("Error al parsear métricas de RAM: %v", err)
            time.Sleep(interval)
            continue
        }

        // Enviar métricas al canal
        log.Printf("Métrica de RAM recolectada: %d%% (Total: %d, Libre: %d, Uso: %d)", 
                  ramMetric.PorcentajeUso, ramMetric.Total, ramMetric.Libre, ramMetric.Uso)
        ramChan <- &ramMetric
        
        // Esperar hasta el próximo intervalo
        time.Sleep(interval)
    }
}

// monitorProcesos monitorea los procesos y envía métricas al canal
func monitorProcesos(procesosPath string, interval time.Duration, procesosChan chan<- *Procesos, wg *sync.WaitGroup) {
    defer wg.Done()
    log.Printf("Iniciando monitoreo de procesos desde %s cada %v", procesosPath, interval)
    
    for {
        // Recolectar métricas de procesos
        procesosData, err := readProcFile(procesosPath)
        if err != nil {
            log.Printf("Error al leer métricas de procesos: %v", err)
            time.Sleep(interval)
            continue
        }

        var procesosMetric Procesos
        if err := json.Unmarshal(procesosData, &procesosMetric); err != nil {
            log.Printf("Error al parsear métricas de procesos: %v", err)
            time.Sleep(interval)
            continue
        }

        // Enviar métricas al canal
        log.Printf("Métrica de procesos recolectada: Corriendo: %d, Total: %d, Durmiendo: %d, Zombie: %d, Parados: %d", 
                  procesosMetric.ProcesosCorriendo, procesosMetric.TotalProcesos, 
                  procesosMetric.ProcesosDurmiendo, procesosMetric.ProcesosZombie, procesosMetric.ProcesosParados)
        procesosChan <- &procesosMetric
        
        // Esperar hasta el próximo intervalo
        time.Sleep(interval)
    }
}

// procesarMetricas recibe métricas de CPU, RAM, Procesos y las envía a la API
func procesarMetricas(apiURL string, interval time.Duration, cpuChan <-chan *CPUMetric, ramChan <-chan *RAMMetric, procesosChan <-chan *Procesos, wg *sync.WaitGroup) {
    defer wg.Done()
    log.Printf("Iniciando procesamiento de métricas para enviar a %s cada %v", apiURL, interval)
    
    // Variables para almacenar las métricas más recientes
    var lastCPU *CPUMetric
    var lastRAM *RAMMetric
    var lastProcesos *Procesos
    
    // Ticker para enviar métricas a intervalos regulares
    ticker := time.NewTicker(interval)
    
    for {
        select {
        case cpu := <-cpuChan:
            lastCPU = cpu
            log.Printf("Recibida nueva métrica de CPU: %d%%", cpu.PorcentajeUso)
            
        case ram := <-ramChan:
            lastRAM = ram
            log.Printf("Recibida nueva métrica de RAM: %d%%", ram.PorcentajeUso)

        case procesos := <-procesosChan:
            lastProcesos = procesos
            log.Printf("Recibida nueva métrica de procesos: Total: %d, Corriendo: %d", procesos.TotalProcesos, procesos.ProcesosCorriendo)
            
        case <-ticker.C:
            // CAMBIAR: Validar que tenemos métricas de los TRES tipos
            if lastCPU != nil && lastRAM != nil && lastProcesos != nil {
                metrics := MetricsPayload{
                    Timestamp: time.Now().Unix(),
                    CPU:       lastCPU,
                    RAM:       lastRAM,
                    Procesos:  lastProcesos, // CAMBIAR: Usar puntero directamente, no desreferenciar
                }
                
                // Enviar métricas a la API
                if err := sendMetricsToAPI(apiURL, metrics); err != nil {
                    log.Printf("Error al enviar métricas a la API: %v", err)
                } else {
                    log.Printf("Métricas completas enviadas exitosamente a la API")
                }
            } else {
                // CAMBIAR: Mostrar estado de cada métrica
                log.Printf("Esperando métricas completas antes de enviar... CPU: %v, RAM: %v, Procesos: %v", 
                          lastCPU != nil, lastRAM != nil, lastProcesos != nil)
            }
        }
    }
}

func main() {
    // Obtener puerto del servidor desde variables de entorno o usar valor predeterminado
    port := os.Getenv("AGENTE_PORT")
    if port == "" {
        port = "8080"
    }
    
    // Obtener intervalo de polling desde variables de entorno o usar valor predeterminado
    pollInterval := os.Getenv("POLL_INTERVAL")
    if pollInterval == "" {
        pollInterval = "2s"
    }
    
    interval, err := time.ParseDuration(pollInterval)
    if err != nil {
        log.Fatalf("Error al parsear POLL_INTERVAL: %v", err)
    }
    
    // Rutas a los archivos de métricas
    cpuPath := "/proc/cpu_201708880"
    ramPath := "/proc/ram_201708880"
    procesosPath := "/proc/procesos_201708880"
    
    log.Printf("Iniciando agente de monitoreo como SERVIDOR en puerto %s", port)
    log.Printf("Recolectando métricas cada %v", interval)
    
    // Estructura para almacenar las últimas métricas
    var latestMetrics struct {
        sync.RWMutex
        CPU      *CPUMetric
        RAM      *RAMMetric
        Procesos *Procesos
    }
    
    // Crear canales para comunicación entre goroutines
    cpuChan := make(chan *CPUMetric, 10)
    ramChan := make(chan *RAMMetric, 10)
    procesosChan := make(chan *Procesos, 10)
    
    // WaitGroup para esperar a que todas las goroutines terminen
    var wg sync.WaitGroup
    wg.Add(4) // 3 monitores + 1 actualizador de métricas
    
    // Iniciar goroutine para monitorear CPU
    go monitorCPU(cpuPath, interval, cpuChan, &wg)
    
    // Iniciar goroutine para monitorear RAM
    go monitorRAM(ramPath, interval, ramChan, &wg)

    // Iniciar goroutine para monitorear procesos
    go monitorProcesos(procesosPath, interval, procesosChan, &wg)
    
    // Iniciar goroutine para actualizar métricas localmente
    go func() {
        defer wg.Done()
        for {
            select {
            case cpu := <-cpuChan:
                latestMetrics.Lock()
                latestMetrics.CPU = cpu
                latestMetrics.Unlock()
                log.Printf("Métrica CPU actualizada: %d%%", cpu.Percentage)
                
            case ram := <-ramChan:
                latestMetrics.Lock()
                latestMetrics.RAM = ram
                latestMetrics.Unlock()
                log.Printf("Métrica RAM actualizada: %d%%", ram.Percentage)
                
            case procesos := <-procesosChan:
                latestMetrics.Lock()
                latestMetrics.Procesos = procesos
                latestMetrics.Unlock()
                log.Printf("Métrica Procesos actualizada: Total: %d, Corriendo: %d", 
                    procesos.Total, procesos.Corriendo)
            }
        }
    }()
    
    // Configurar servidor HTTP
    http.HandleFunc("/metrics", func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        w.Header().Set("Access-Control-Allow-Origin", "*")
        w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
        w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
        
        if r.Method == "OPTIONS" {
            w.WriteHeader(http.StatusOK)
            return
        }
        
        if r.Method != "GET" {
            http.Error(w, "Método no permitido", http.StatusMethodNotAllowed)
            return
        }
        
        // Obtener las últimas métricas
        latestMetrics.RLock()
        cpu := latestMetrics.CPU
        ram := latestMetrics.RAM
        procesos := latestMetrics.Procesos
        latestMetrics.RUnlock()
        
        // Crear payload con las métricas más recientes
        payload := MetricsPayload{
            CPU:      cpu,
            RAM:      ram,
            Procesos: procesos,
        }
        
        // Enviar respuesta JSON
        if err := json.NewEncoder(w).Encode(payload); err != nil {
            log.Printf("Error al codificar métricas: %v", err)
            http.Error(w, "Error interno del servidor", http.StatusInternalServerError)
            return
        }
        
        log.Printf("Métricas enviadas a cliente %s", r.RemoteAddr)
    })
    
    // Endpoint de salud
    http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        w.WriteHeader(http.StatusOK)
        json.NewEncoder(w).Encode(map[string]string{
            "status": "ok",
            "agent":  "monitor-agent",
            "port":   port,
        })
    })
    
    // Iniciar servidor HTTP
    go func() {
        log.Printf("Servidor HTTP iniciado en puerto %s", port)
        log.Printf("Endpoints disponibles:")
        log.Printf("  GET /metrics - Obtener métricas actuales")
        log.Printf("  GET /health  - Estado del agente")
        
        if err := http.ListenAndServe(":"+port, nil); err != nil {
            log.Fatalf("Error al iniciar servidor HTTP: %v", err)
        }
    }()
    
    // Esperar señales para finalizar el programa
    log.Printf("Agente de monitoreo ejecutándose como SERVIDOR. Presiona Ctrl+C para detener.")
    
    // Capturar señales de interrupción
    sigChan := make(chan os.Signal, 1)
    signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
    
    // Esperar señal de interrupción
    <-sigChan
    log.Printf("Señal de interrupción recibida. Cerrando agente...")
}