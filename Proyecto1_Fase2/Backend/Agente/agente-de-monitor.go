package main

import (
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

// MetricsResponse es la estructura que se enviará como respuesta HTTP
type MetricsResponse struct {
    TotalRAM           int64  `json:"total_ram"`
    RAMLibre           int64  `json:"ram_libre"`
    UsoRAM             int64  `json:"uso_ram"`
    PorcentajeRAM      int64  `json:"porcentaje_ram"`
    PorcentajeCPUUso   int64  `json:"porcentaje_cpu_uso"`
    PorcentajeCPULibre int64  `json:"porcentaje_cpu_libre"`
    ProcesosCorriendo  int    `json:"procesos_corriendo"`
    TotalProcesos      int    `json:"total_procesos"`
    ProcesosDurmiendo  int    `json:"procesos_durmiendo"`
    ProcesosZombie     int    `json:"procesos_zombie"`
    ProcesosParados    int    `json:"procesos_parados"`
    Hora               string `json:"hora"`
}

// readProcFile lee un archivo en /proc y devuelve su contenido
func readProcFile(filePath string) ([]byte, error) {
    data, err := os.ReadFile(filePath)
    if err != nil {
        return nil, fmt.Errorf("error reading %s: %v", filePath, err)
    }
    return data, nil
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
        
        select {
        case cpuChan <- &cpuMetric:
        default:
            // Canal lleno, descartar métrica antigua
        }
        
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
        
        select {
        case ramChan <- &ramMetric:
        default:
            // Canal lleno, descartar métrica antigua
        }
        
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
        
        select {
        case procesosChan <- &procesosMetric:
        default:
            // Canal lleno, descartar métrica antigua
        }
        
        // Esperar hasta el próximo intervalo
        time.Sleep(interval)
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
    cpuChan := make(chan *CPUMetric, 5)
    ramChan := make(chan *RAMMetric, 5)
    procesosChan := make(chan *Procesos, 5)
    
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
                log.Printf("Métrica CPU actualizada: %d%%", cpu.PorcentajeUso)
                
            case ram := <-ramChan:
                latestMetrics.Lock()
                latestMetrics.RAM = ram
                latestMetrics.Unlock()
                log.Printf("Métrica RAM actualizada: %d%%", ram.PorcentajeUso)
                
            case procesos := <-procesosChan:
                latestMetrics.Lock()
                latestMetrics.Procesos = procesos
                latestMetrics.Unlock()
                log.Printf("Métrica Procesos actualizada: Total: %d, Corriendo: %d", 
                    procesos.TotalProcesos, procesos.ProcesosCorriendo)
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
        
        // Crear respuesta con el formato esperado
        response := MetricsResponse{
            // Métricas de RAM (convertir bytes a MB)
            TotalRAM:      ram.Total / 1024,     // Convertir KB a MB
            RAMLibre:      ram.Libre * 1024,     // Convertir KB a bytes
            UsoRAM:        ram.Uso / 1024,       // Convertir KB a MB
            PorcentajeRAM: ram.PorcentajeUso,
            
            // Métricas de CPU
            PorcentajeCPUUso:   cpu.PorcentajeUso,
            PorcentajeCPULibre: 100 - cpu.PorcentajeUso,
            
            // Métricas de procesos
            ProcesosCorriendo: procesos.ProcesosCorriendo,
            TotalProcesos:     procesos.TotalProcesos,
            ProcesosDurmiendo: procesos.ProcesosDurmiendo,
            ProcesosZombie:    procesos.ProcesosZombie,
            ProcesosParados:   procesos.ProcesosParados,
            
            // Timestamp formateado
            Hora: time.Now().Format("2006-01-02 15:04:05"),
        }
        
        // Manejar casos donde las métricas pueden ser nil
        if cpu == nil {
            response.PorcentajeCPUUso = 0
            response.PorcentajeCPULibre = 100
        }
        
        if ram == nil {
            response.TotalRAM = 0
            response.RAMLibre = 0
            response.UsoRAM = 0
            response.PorcentajeRAM = 0
        }
        
        if procesos == nil {
            response.ProcesosCorriendo = 0
            response.TotalProcesos = 0
            response.ProcesosDurmiendo = 0
            response.ProcesosZombie = 0
            response.ProcesosParados = 0
        }
        
        // Enviar respuesta JSON
        if err := json.NewEncoder(w).Encode(response); err != nil {
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
            "status": "healthy",
            "agent":  "monitor-agent-fase2",
            "port":   port,
            "version": "2.0",
        })
        log.Printf("Health check solicitado por %s", r.RemoteAddr)
    })
    
    // Iniciar servidor HTTP
    go func() {
        log.Printf("Servidor HTTP iniciado en puerto %s", port)
        log.Printf("Endpoints disponibles:")
        log.Printf("  GET /metrics - Obtener métricas actuales")
        log.Printf("  GET /health  - Estado del agente")
        log.Printf("Agente listo para recibir peticiones en http://localhost:%s", port)
        
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