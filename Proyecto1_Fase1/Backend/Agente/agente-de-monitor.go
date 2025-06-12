package main

import (
    "bytes"
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "os"
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
    Timestamp int64     `json:"timestamp"`
    CPU       CPUMetric `json:"cpu"`
    RAM       RAMMetric `json:"ram"`
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
        return fmt.Errorf("API returned non-200 status: %d", resp.StatusCode)
    }

    return nil
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

    log.Printf("Starting monitoring agent. Sending metrics to %s every %v", apiURL, interval)

    // Bucle infinito para recolectar y enviar métricas
    for {
        // Recolectar métricas de CPU
        cpuData, err := readProcFile(cpuPath)
        if err != nil {
            log.Printf("Error reading CPU metrics: %v", err)
            time.Sleep(interval)
            continue
        }

        var cpuMetric CPUMetric
        if err := json.Unmarshal(cpuData, &cpuMetric); err != nil {
            log.Printf("Error parsing CPU metrics: %v", err)
            time.Sleep(interval)
            continue
        }

        // Recolectar métricas de RAM
        ramData, err := readProcFile(ramPath)
        if err != nil {
            log.Printf("Error reading RAM metrics: %v", err)
            time.Sleep(interval)
            continue
        }

        var ramMetric RAMMetric
        if err := json.Unmarshal(ramData, &ramMetric); err != nil {
            log.Printf("Error parsing RAM metrics: %v", err)
            time.Sleep(interval)
            continue
        }

        // Crear payload de métricas
        metrics := MetricsPayload{
            Timestamp: time.Now().Unix(),
            CPU:       cpuMetric,
            RAM:       ramMetric,
        }

        // Enviar métricas a la API
        if err := sendMetricsToAPI(apiURL, metrics); err != nil {
            log.Printf("Error sending metrics to API: %v", err)
        } else {
            log.Printf("Metrics sent successfully to API")
        }

        // Esperar hasta el próximo intervalo
        time.Sleep(interval)
    }
}