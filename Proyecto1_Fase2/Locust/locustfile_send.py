from locust import HttpUser, task, between
import json

INGRESS_URL = "http://IP"

class SendJsonUser(HttpUser):
    wait_time = between(1, 4)
    host = INGRESS_URL

    def on_start(self):
        # Cargar el archivo solo una vez por usuario
        with open("metrics_collected.json", "r") as f:
            self.metrics = json.load(f)
        self.index = 0

    @task
    def send_metric(self):
        if self.index < len(self.metrics):
            metric = self.metrics[self.index]
            headers = {
                "Content-Type": "application/json",
                "Host": "api.monitor.local"
            }
            # Enviar como arreglo de un solo objeto
            with self.client.post("/api/data", json=[metric], headers=headers, catch_response=True) as response:
                if response.status_code == 201:
                    response.success()
                else:
                    response.failure(f"HTTP {response.status_code}")
            self.index += 1
        else:
            self.environment.runner.quit()  # Detiene el usuario cuando termina