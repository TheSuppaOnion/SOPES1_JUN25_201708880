from locust import HttpUser, task, between
import json
import random
import time

class MonitoringUser(HttpUser):
    wait_time = between(1, 3)
    
    def on_start(self):
        """Se ejecuta cuando inicia cada usuario"""
        print(f"Usuario iniciado: {self.client.base_url}")
    
    @task(5)
    def visit_dashboard(self):
        """Simula usuario visitando el dashboard principal"""
        with self.client.get("/", catch_response=True, name="Dashboard") as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Dashboard falló: {response.status_code}")
    
    @task(3)
    def get_latest_metrics(self):
        """Simula consulta de métricas más recientes"""
        with self.client.get("/api/metrics/latest", catch_response=True, name="API Latest") as response:
            if response.status_code == 200:
                try:
                    data = response.json()
                    if 'cpu' in data and 'ram' in data:
                        response.success()
                    else:
                        response.failure("Respuesta incompleta")
                except:
                    response.failure("JSON inválido")
            else:
                response.failure(f"API falló: {response.status_code}")
    
    @task(2)
    def get_cpu_history(self):
        """Simula consulta del historial de CPU"""
        with self.client.get("/api/metrics/cpu", catch_response=True, name="API CPU") as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"CPU API falló: {response.status_code}")
    
    @task(2)
    def get_ram_history(self):
        """Simula consulta del historial de RAM"""
        with self.client.get("/api/metrics/ram", catch_response=True, name="API RAM") as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"RAM API falló: {response.status_code}")

    @task(1)
    def get_process_info(self):
        """Simula consulta de información de procesos (Fase 2)"""
        with self.client.get("/api/metrics/procesos", catch_response=True, name="API Procesos") as response:
            if response.status_code == 200:
                try:
                    data = response.json()
                    if 'total_processos' in data:
                        response.success()
                    else:
                        response.failure("Datos de procesos incompletos")
                except:
                    response.failure("JSON de procesos inválido")
            else:
                response.failure(f"Procesos API falló: {response.status_code}")

# Clase para simular carga más intensa
class HeavyUser(HttpUser):
    wait_time = between(0.5, 1)  # Más agresivo
    
    @task(10)
    def rapid_requests(self):
        """Solicitudes rápidas para probar límites"""
        endpoints = [
            "/api/metrics/latest",
            "/api/metrics/cpu", 
            "/api/metrics/ram",
            "/api/metrics/procesos"
        ]
        
        endpoint = random.choice(endpoints)
        with self.client.get(endpoint, catch_response=True, name="Rapid Request") as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Rapid request falló: {response.status_code}")