package main

import (
    "bytes"
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "os"
    "sync"
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

// MetricsPayload es la estructura que se enviará a la API
type MetricsPayload struct {
    Timestamp int64      `json:"timestamp"`
    CPU       *CPUMetric `json:"cpu"`
    RAM       *RAMMetric `json:"ram"`
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

// procesarMetricas recibe métricas de CPU y RAM y las envía a la API
func procesarMetricas(apiURL string, interval time.Duration, cpuChan <-chan *CPUMetric, ramChan <-chan *RAMMetric, wg *sync.WaitGroup) {
    defer wg.Done()
    log.Printf("Iniciando procesamiento de métricas para enviar a %s cada %v", apiURL, interval)
    
    // Variables para almacenar las métricas más recientes
    var lastCPU *CPUMetric
    var lastRAM *RAMMetric
    
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
            
        case <-ticker.C:
            // Solo enviar si tenemos métricas de ambos tipos
            if lastCPU != nil && lastRAM != nil {
                metrics := MetricsPayload{
                    Timestamp: time.Now().Unix(),
                    CPU:       lastCPU,
                    RAM:       lastRAM,
                }
                
                // Enviar métricas a la API
                if err := sendMetricsToAPI(apiURL, metrics); err != nil {
                    log.Printf("Error al enviar métricas a la API: %v", err)
                } else {
                    log.Printf("Métricas enviadas exitosamente a la API")
                }
            } else {
                log.Printf("Esperando métricas completas antes de enviar...")
            }
        }
    }
}

func main() {
    // Obtener URL de la API desde variables de entorno o usar valor predeterminado
    apiURL := os.Getenv("API_URL")
    if apiURL == "" {
        apiURL = "http://localhost:3000/api/data"
    }

    // Obtener intervalo de polling desde variables de entorno o usar valor predeterminado
    intervalStr := os.Getenv("POLL_INTERVAL")
    interval := 2 * time.Second
    if intervalStr != "" {
        if parsedInterval, err := time.ParseDuration(intervalStr); err == nil {
            interval = parsedInterval
        }
    }

    // Rutas a los archivos de métricas
    cpuPath := "/proc/cpu_201708880"
    ramPath := "/proc/ram_201708880"

    log.Printf("Iniciando agente de monitoreo con concurrencia. Enviando métricas a %s cada %v", apiURL, interval)

    // Crear canales para comunicación entre goroutines
    cpuChan := make(chan *CPUMetric, 10) // Buffer para evitar bloqueos
    ramChan := make(chan *RAMMetric, 10) // Buffer para evitar bloqueos
    
    // WaitGroup para esperar a que todas las goroutines terminen
    var wg sync.WaitGroup
    wg.Add(3) // 3 goroutines: CPU, RAM y procesamiento
    
    // Iniciar goroutine para monitorear CPU
    go monitorCPU(cpuPath, interval/2, cpuChan, &wg)
    
    // Iniciar goroutine para monitorear RAM
    go monitorRAM(ramPath, interval/2, ramChan, &wg)
    
    // Iniciar goroutine para procesar y enviar métricas
    go procesarMetricas(apiURL, interval, cpuChan, ramChan, &wg)
    
    // Esperar señales para finalizar el programa
    log.Printf("Agente de monitoreo ejecutándose. Presiona Ctrl+C para detener.")
    
    // Esperar a que todas las goroutines terminen (en la práctica, nunca terminan)
    wg.Wait()
}