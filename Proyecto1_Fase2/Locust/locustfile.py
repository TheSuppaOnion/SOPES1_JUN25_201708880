from locust import HttpUser, task, between
import json
import requests

AGENTE_URL = "http://[IP_PUBLICA_DE_LA_VM]:8080"  
INGRESS_URL = "http://INGRESS_URL/api/data"

class AgenteUser(HttpUser):
    wait_time = between(1, 2)
    host = AGENTE_URL 
    collected_jsons = []

    @task(1)
    def get_metrics(self):
        with self.client.get("/metrics", catch_response=True, name="agente_metrics") as response:
            try:
                if response.status_code == 200:
                    json_data = response.json()
                    self.collected_jsons.append(json_data)
                    response.success()
                else:
                    response.failure(f"HTTP {response.status_code}")
            except Exception as e:
                response.failure(f"Error: {str(e)}")

    def on_stop(self):
        with open("metrics_collected.json", "w") as f:
            json.dump(self.collected_jsons, f, indent=2)
        print(f"Guardado metrics_collected.json con {len(self.collected_jsons)} métricas.")

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