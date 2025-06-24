from locust import HttpUser, task, between
import json
import time

class VMMonitoringUser(HttpUser):
    # Peticiones cada 1-2 segundos como especifica el enunciado
    wait_time = between(1, 2)
    
    def on_start(self):
        """Se ejecuta cuando inicia cada usuario"""
        print(f"Usuario iniciado: {self.client.base_url}")
    
    @task(10)  # Tarea principal - el endpoint completo
    def get_complete_metrics(self):
        """Simula petición al endpoint completo que devuelve el JSON específico"""
        with self.client.get("/api/metrics/complete", catch_response=True, name="Complete Metrics") as response:
            if response.status_code == 200:
                try:
                    data = response.json()
                    # Verificar que tenga todos los campos requeridos
                    required_fields = [
                        'total_ram', 'ram_libre', 'uso_ram', 'porcentaje_ram',
                        'porcentaje_cpu_uso', 'porcentaje_cpu_libre',
                        'procesos_corriendo', 'total_procesos', 'procesos_durmiendo',
                        'procesos_zombie', 'procesos_parados', 'hora'
                    ]
                    
                    if all(field in data for field in required_fields):
                        response.success()
                        # Opcional: imprimir algunas métricas para debug
                        if hasattr(self, '_request_count'):
                            self._request_count += 1
                        else:
                            self._request_count = 1
                            
                        if self._request_count % 100 == 0:  # Cada 100 requests
                            print(f"Request {self._request_count}: CPU {data['porcentaje_cpu_uso']}%, RAM {data['porcentaje_ram']}%")
                    else:
                        response.failure("JSON incompleto - faltan campos requeridos")
                except json.JSONDecodeError:
                    response.failure("Respuesta no es JSON válido")
            else:
                response.failure(f"HTTP {response.status_code}")
    
    @task(2)  # Tarea secundaria ocasional
    def visit_dashboard(self):
        """Visita ocasional al dashboard"""
        with self.client.get("/", catch_response=True, name="Dashboard") as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Dashboard HTTP {response.status_code}")