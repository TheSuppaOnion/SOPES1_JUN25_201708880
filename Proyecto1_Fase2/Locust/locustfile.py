from locust import HttpUser, task, between, events
import json
import random
import requests

INGRESS_URL = "http://TU_INGRESS_URL/api/data"

class TrafficSplitUser(HttpUser):
    wait_time = between(1, 2)
    collected_jsons = []

    def on_start(self):
        self.api_choice = random.choice(['nodejs', 'python'])
        if self.api_choice == 'nodejs':
            self.host = "http://localhost:3000"
        else:
            self.host = "http://localhost:5000"

    @task(10)
    def get_complete_metrics(self):
        with self.client.get("/api/metrics/complete", catch_response=True, name=f"api_metrics_complete_{self.api_choice}") as response:
            try:
                if response.status_code == 200:
                    json_data = response.json()
                    if "api" in json_data:
                        expected_api = "NodeJS" if self.api_choice == 'nodejs' else "Python"
                        if json_data["api"] == expected_api:
                            response.success()
                            self.collected_jsons.append(json_data)
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

    def on_stop(self):
        # Guardar todas las respuestas en un archivo JSON
        with open("metrics_collected.json", "w") as f:
            json.dump(self.collected_jsons, f, indent=2)
        print(f"Guardado metrics_collected.json con {len(self.collected_jsons)} métricas.")

        # Enviar el archivo completo al Ingress (como un arreglo de objetos)
        headers = {"Content-Type": "application/json"}
        try:
            with open("metrics_collected.json", "r") as f:
                data = f.read()
            resp = requests.post(INGRESS_URL, data=data, headers=headers)
            if resp.status_code == 200:
                print("✓ Archivo JSON enviado correctamente al Ingress")
            else:
                print(f"✗ Error al enviar archivo JSON: HTTP {resp.status_code}")
        except Exception as e:
            print(f"✗ Error al enviar archivo JSON al Ingress: {e}")