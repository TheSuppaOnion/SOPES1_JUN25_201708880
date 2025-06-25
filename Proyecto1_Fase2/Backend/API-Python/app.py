from flask import Flask, request, jsonify
from flask_cors import CORS
import mysql.connector
import os
import json
from datetime import datetime
import logging
import time

# Configuración de logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# Configuración de base de datos
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': int(os.getenv('DB_PORT', 3306)),
    'user': os.getenv('DB_USER', 'monitor'),
    'password': os.getenv('DB_PASSWORD', 'monitor123'),
    'database': os.getenv('DB_NAME', 'monitoring'),
    'charset': 'utf8mb4',
    'autocommit': True
}

def get_db_connection():
    """Crear conexión a la base de datos con reintentos"""
    max_retries = 5
    retry_delay = 2
    
    for attempt in range(max_retries):
        try:
            connection = mysql.connector.connect(**DB_CONFIG)
            logger.info("Conexión a base de datos exitosa")
            return connection
        except mysql.connector.Error as err:
            logger.error(f"Intento {attempt + 1}/{max_retries} - Error conectando a BD: {err}")
            if attempt < max_retries - 1:
                time.sleep(retry_delay)
                retry_delay *= 2  # Backoff exponencial
            else:
                raise err
    return None

@app.route('/health', methods=['GET'])
def health_check():
    """Health check para Kubernetes"""
    try:
        conn = get_db_connection()
        if conn:
            cursor = conn.cursor()
            cursor.execute("SELECT 1")
            cursor.close()
            conn.close()
            
            return jsonify({
                "status": "healthy",
                "api": "Python",
                "timestamp": datetime.now().isoformat(),
                "database": "connected"
            }), 200
        else:
            return jsonify({
                "status": "unhealthy",
                "api": "Python", 
                "error": "Database connection failed"
            }), 503
            
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return jsonify({
            "status": "unhealthy",
            "api": "Python",
            "error": str(e)
        }), 503

@app.route('/api/data', methods=['POST'])
def receive_metrics():
    """
    Endpoint principal para recibir métricas del agente Go
    Ruta 1 del Traffic Split - API Python
    """
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No data provided", "api": "Python"}), 400
            
        logger.info(f"Datos recibidos en API Python: {data}")
        
        # Procesar datos según formato del agente Go
        timestamp = int(time.time())
        
        # Extraer métricas de CPU
        cpu_data = data.get('cpu', {})
        cpu_usage = cpu_data.get('porcentajeUso', 0)
        
        # Extraer métricas de RAM  
        ram_data = data.get('ram', {})
        ram_total = ram_data.get('total', 0)
        ram_libre = ram_data.get('libre', 0) 
        ram_uso = ram_data.get('uso', 0)
        ram_percentage = ram_data.get('porcentajeUso', 0)
        
        # Extraer métricas de procesos
        process_data = data.get('procesos', {})
        processes_running = process_data.get('procesos_corriendo', 0)
        processes_total = process_data.get('total_processos', 0)
        processes_sleeping = process_data.get('procesos_durmiendo', 0)
        processes_zombie = process_data.get('procesos_zombie', 0)
        processes_stopped = process_data.get('procesos_parados', 0)
        
        # Guardar en base de datos
        conn = get_db_connection()
        if not conn:
            return jsonify({"error": "Database connection failed", "api": "Python"}), 500
            
        cursor = conn.cursor()
        
        # Insertar métricas de CPU
        cpu_query = """
        INSERT INTO cpu_metrics (timestamp, porcentaje_uso) 
        VALUES (%s, %s)
        """
        cursor.execute(cpu_query, (timestamp, cpu_usage))
        
        # Insertar métricas de RAM
        ram_query = """
        INSERT INTO ram_metrics (timestamp, total, libre, uso, porcentaje_uso) 
        VALUES (%s, %s, %s, %s, %s)
        """
        cursor.execute(ram_query, (timestamp, ram_total, ram_libre, ram_uso, ram_percentage))
        
        # Insertar métricas de procesos
        process_query = """
        INSERT INTO procesos_metrics 
        (timestamp, procesos_corriendo, total_processos, procesos_durmiendo, procesos_zombie, procesos_parados) 
        VALUES (%s, %s, %s, %s, %s, %s)
        """
        cursor.execute(process_query, (timestamp, processes_running, processes_total, 
                                     processes_sleeping, processes_zombie, processes_stopped))
        
        # Insertar en caché para respuesta rápida
        cache_data = {
            "total_ram": int(ram_total / 1024) if ram_total > 0 else 0,
            "ram_libre": ram_libre,
            "uso_ram": int(ram_uso / 1024) if ram_uso > 0 else 0,
            "porcentaje_ram": ram_percentage,
            "porcentaje_cpu_uso": cpu_usage,
            "porcentaje_cpu_libre": 100 - cpu_usage,
            "procesos_corriendo": processes_running,
            "total_procesos": processes_total,
            "procesos_durmiendo": processes_sleeping,
            "procesos_zombie": processes_zombie,
            "procesos_parados": processes_stopped,
            "hora": datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            "api": "Python"  # Identificador de la API
        }
        
        # Actualizar caché
        cache_queries = [
            ("cpu", json.dumps({"porcentaje_uso": cpu_usage})),
            ("ram", json.dumps({
                "total": ram_total, "libre": ram_libre, 
                "uso": ram_uso, "porcentaje_uso": ram_percentage
            })),
            ("procesos", json.dumps({
                "procesos_corriendo": processes_running,
                "total_processos": processes_total,
                "procesos_durmiendo": processes_sleeping,
                "procesos_zombie": processes_zombie,
                "procesos_parados": processes_stopped
            }))
        ]
        
        for cache_id, cache_json in cache_queries:
            cache_query = """
            INSERT INTO metrics_cache (id, timestamp, data) 
            VALUES (%s, %s, %s)
            ON DUPLICATE KEY UPDATE timestamp = %s, data = %s
            """
            cursor.execute(cache_query, (cache_id, timestamp, cache_json, timestamp, cache_json))
        
        cursor.close()
        conn.close()
        
        logger.info(f"Métricas guardadas exitosamente por API Python")
        
        return jsonify({
            "message": "Metrics saved successfully",
            "api": "Python",
            "timestamp": timestamp,
            "data": cache_data
        }), 201
        
    except mysql.connector.Error as db_err:
        logger.error(f"Error de base de datos: {db_err}")
        return jsonify({
            "error": "Database error",
            "api": "Python",
            "details": str(db_err)
        }), 500
        
    except Exception as e:
        logger.error(f"Error procesando solicitud: {e}")
        return jsonify({
            "error": "Internal server error",
            "api": "Python",
            "details": str(e)
        }), 500

@app.route('/api/metrics/python', methods=['GET'])
def get_python_metrics():
    """Obtener métricas procesadas específicamente por la API Python"""
    try:
        conn = get_db_connection()
        if not conn:
            return jsonify({"error": "Database connection failed"}), 500
            
        cursor = conn.cursor(dictionary=True)
        
        # Obtener últimas métricas de cada tipo
        queries = {
            "cpu": "SELECT * FROM cpu_metrics ORDER BY timestamp DESC LIMIT 10",
            "ram": "SELECT * FROM ram_metrics ORDER BY timestamp DESC LIMIT 10", 
            "procesos": "SELECT * FROM procesos_metrics ORDER BY timestamp DESC LIMIT 10"
        }
        
        results = {}
        for metric_type, query in queries.items():
            cursor.execute(query)
            results[metric_type] = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        return jsonify({
            "api": "Python",
            "timestamp": datetime.now().isoformat(),
            "data": results,
            "total_records": sum(len(records) for records in results.values())
        }), 200
        
    except Exception as e:
        logger.error(f"Error obteniendo métricas: {e}")
        return jsonify({
            "error": "Error retrieving metrics",
            "api": "Python"
        }), 500

@app.route('/api/stats/python', methods=['GET'])
def get_python_stats():
    """Estadísticas específicas de la API Python"""
    try:
        conn = get_db_connection()
        if not conn:
            return jsonify({"error": "Database connection failed"}), 500
            
        cursor = conn.cursor(dictionary=True)
        
        # Contar registros por tabla
        stats = {}
        tables = ['cpu_metrics', 'ram_metrics', 'procesos_metrics']
        
        for table in tables:
            cursor.execute(f"SELECT COUNT(*) as count FROM {table}")
            result = cursor.fetchone()
            stats[table] = result['count'] if result else 0
        
        # Obtener rango de fechas
        cursor.execute("""
            SELECT 
                MIN(FROM_UNIXTIME(timestamp)) as oldest,
                MAX(FROM_UNIXTIME(timestamp)) as newest
            FROM cpu_metrics
        """)
        date_range = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        return jsonify({
            "api": "Python",
            "timestamp": datetime.now().isoformat(),
            "database_stats": stats,
            "date_range": date_range,
            "total_records": sum(stats.values())
        }), 200
        
    except Exception as e:
        logger.error(f"Error obteniendo estadísticas: {e}")
        return jsonify({
            "error": "Error retrieving stats",
            "api": "Python"
        }), 500

@app.route('/', methods=['GET'])
def root():
    """Endpoint raíz con información de la API"""
    return jsonify({
        "service": "Sistema de Monitoreo - API Python",
        "version": "2.0.0",
        "author": "Bismarck Romero - 201708880",
        "description": "Ruta 1 del Traffic Split - API desarrollada en Python/Flask",
        "endpoints": [
            "GET /health - Health check",
            "POST /api/data - Recibir métricas del agente", 
            "GET /api/metrics/python - Métricas procesadas por Python",
            "GET /api/stats/python - Estadísticas de la API Python"
        ],
        "timestamp": datetime.now().isoformat()
    }), 200

if __name__ == '__main__':
    logger.info("Iniciando API Python - Ruta 1 del Traffic Split")
    logger.info(f"Configuración de BD: {DB_CONFIG['host']}:{DB_CONFIG['port']}")
    
    # Verificar conexión inicial
    try:
        conn = get_db_connection()
        if conn:
            conn.close()
            logger.info("Conexión inicial a BD exitosa")
        else:
            logger.warning("No se pudo conectar a la BD al inicio")
    except Exception as e:
        logger.error(f"Error en conexión inicial: {e}")
    
    app.run(host='0.0.0.0', port=5000, debug=False)