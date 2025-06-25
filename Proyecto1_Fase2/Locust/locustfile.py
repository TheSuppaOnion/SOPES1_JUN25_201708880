from locust import HttpUser, task, between
import json
import random

class TrafficSplitUser(HttpUser):
    wait_time = between(1, 2)
    
    def on_start(self):
        """Se ejecuta cuando inicia cada usuario"""
        # Elegir API aleatoriamente para simular traffic split
        self.api_choice = random.choice(['nodejs', 'python'])
        if self.api_choice == 'nodejs':
            self.host = "http://localhost:3000"
        else:
            self.host = "http://localhost:5000"
    
    @task(10)  # Tarea principal - probar endpoint completo
    def get_complete_metrics(self):
        """Simula petición al endpoint completo que devuelve el JSON específico"""
        with self.client.get("/api/metrics/complete", 
                           catch_response=True,
                           name=f"api_metrics_complete_{self.api_choice}") as response:
            try:
                if response.status_code == 200:
                    json_data = response.json()
                    # Verificar que tenga el campo "api" requerido
                    if "api" in json_data:
                        expected_api = "NodeJS" if self.api_choice == 'nodejs' else "Python"
                        if json_data["api"] == expected_api:
                            response.success()
                        else:
                            response.failure(f"API field mismatch: expected {expected_api}, got {json_data.get('api')}")
                    else:
                        response.failure("Missing 'api' field in response")
                else:
                    response.failure(f"HTTP {response.status_code}")
            except json.JSONDecodeError:
                response.failure("Invalid JSON response")
            except Exception as e:
                response.failure(f"Error: {str(e)}")
    
    @task(2)  # Tarea secundaria - health check
    def health_check(self):
        """Health check de la API"""
        with self.client.get("/health",
                           catch_response=True,
                           name=f"health_check_{self.api_choice}") as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Health check failed: HTTP {response.status_code}")