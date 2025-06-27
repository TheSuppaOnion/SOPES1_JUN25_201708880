from flask import Flask, request, jsonify
import mysql.connector
from mysql.connector import pooling
import os
from datetime import datetime

app = Flask(__name__)

# Configuración de base de datos para MySQL local
DB_CONFIG = {
    'host': os.getenv('DB_HOST', '192.168.49.1'),
    'port': int(os.getenv('DB_PORT', 3306)),
    'user': os.getenv('DB_USER', 'monitor'),
    'password': os.getenv('DB_PASSWORD', 'monitor123'),
    'database': os.getenv('DB_NAME', 'monitoring'),
    'charset': 'utf8mb4',
    'autocommit': True
}

# Pool de conexiones
connection_pool = None

def initialize_database():
    global connection_pool
    try:
        connection_pool = pooling.MySQLConnectionPool(
            pool_name="api_python_pool",
            pool_size=5,
            pool_reset_session=True,
            **DB_CONFIG
        )
        
        # Probar conexión
        test_conn = connection_pool.get_connection()
        print("✓ Conectado a MySQL desde API Python")
        test_conn.close()
        
        # Crear tabla si no existe
        create_tables()
        
    except Exception as error:
        print(f"X Error conectando a MySQL: {error}")
        raise error

def create_tables():
    try:
        conn = connection_pool.get_connection()
        cursor = conn.cursor()
        
        create_table_query = """
        CREATE TABLE IF NOT EXISTS metrics (
            id INT AUTO_INCREMENT PRIMARY KEY,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            total_ram INT,
            ram_libre BIGINT,
            uso_ram INT,
            porcentaje_ram DECIMAL(5,2),
            porcentaje_cpu_uso DECIMAL(5,2),
            porcentaje_cpu_libre DECIMAL(5,2),
            procesos_corriendo INT,
            total_procesos INT,
            procesos_durmiendo INT,
            procesos_zombie INT,
            procesos_parados INT,
            hora VARCHAR(50),
            api_source VARCHAR(20) DEFAULT 'python'
        )
        """
        
        cursor.execute(create_table_query)
        print("✓ Tabla metrics verificada/creada")
        
    except Exception as error:
        print(f"X Error creando tabla: {error}")
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()

# ENDPOINT PRINCIPAL - Recibir datos de Locust via Ingress
@app.route('/api/data', methods=['POST'])
def receive_data():
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': 'No se recibieron datos JSON'
            }), 400
        
        # Validar datos requeridos
        if 'total_ram' not in data or 'porcentaje_cpu_uso' not in data:
            return jsonify({
                'success': False,
                'error': 'Datos faltantes: total_ram y porcentaje_cpu_uso son requeridos'
            }), 400
        
        # Insertar en base de datos
        conn = connection_pool.get_connection()
        cursor = conn.cursor()
        
        insert_query = """
        INSERT INTO metrics (
            total_ram, ram_libre, uso_ram, porcentaje_ram,
            porcentaje_cpu_uso, porcentaje_cpu_libre,
            procesos_corriendo, total_procesos, procesos_durmiendo,
            procesos_zombie, procesos_parados, hora, api_source
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """
        
        values = (
            data.get('total_ram', 0),
            data.get('ram_libre', 0),
            data.get('uso_ram', 0),
            data.get('porcentaje_ram', 0),
            data.get('porcentaje_cpu_uso', 0),
            data.get('porcentaje_cpu_libre', 0),
            data.get('procesos_corriendo', 0),
            data.get('total_procesos', 0),
            data.get('procesos_durmiendo', 0),
            data.get('procesos_zombie', 0),
            data.get('procesos_parados', 0),
            data.get('hora', datetime.now().isoformat()),
            'python'
        )
        
        cursor.execute(insert_query, values)
        row_id = cursor.lastrowid
        
        print(f"✓ Datos recibidos y guardados: ID={row_id}, CPU={data.get('porcentaje_cpu_uso')}, RAM={data.get('porcentaje_ram')}, Procesos={data.get('total_procesos')}")
        
        return jsonify({
            'success': True,
            'message': 'Datos guardados correctamente en API Python',
            'id': row_id,
            'timestamp': datetime.now().isoformat(),
            'api': 'python'
        }), 201
        
    except Exception as error:
        print(f"X Error procesando datos: {error}")
        return jsonify({
            'success': False,
            'error': 'Error interno del servidor',
            'api': 'python'
        }), 500
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()

# Endpoint para obtener métricas (para frontend)
@app.route('/api/metrics', methods=['GET'])
def get_metrics():
    try:
        conn = connection_pool.get_connection()
        cursor = conn.cursor(dictionary=True)
        
        query = """
        SELECT * FROM metrics 
        ORDER BY timestamp DESC 
        LIMIT 1
        """
        
        cursor.execute(query)
        result = cursor.fetchone()
        
        if not result:
            return jsonify({
                'cpu': {'porcentaje_uso': 0},
                'ram': {'porcentaje_uso': 0, 'total_gb': 0, 'libre_gb': 0},
                'procesos': {'total_procesos': 0, 'procesos_corriendo': 0}
            })
        
        response = {
            'cpu': {
                'porcentaje_uso': float(result.get('porcentaje_cpu_uso', 0))
            },
            'ram': {
                'porcentaje_uso': float(result.get('porcentaje_ram', 0)),
                'total_gb': (result.get('total_ram', 0) or 0) / 1024,
                'libre_gb': (result.get('ram_libre', 0) or 0) / (1024 * 1024 * 1024)
            },
            'procesos': {
                'total_procesos': result.get('total_procesos', 0),
                'procesos_corriendo': result.get('procesos_corriendo', 0),
                'procesos_durmiendo': result.get('procesos_durmiendo', 0),
                'procesos_zombie': result.get('procesos_zombie', 0),
                'procesos_parados': result.get('procesos_parados', 0)
            },
            'timestamp': result.get('timestamp'),
            'api_source': result.get('api_source')
        }
        
        return jsonify(response)
        
    except Exception as error:
        print(f"X Error obteniendo métricas: {error}")
        return jsonify({'error': 'Error obteniendo métricas'}), 500
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()

# Health check
@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        'status': 'healthy',
        'service': 'api-python',
        'timestamp': datetime.now().isoformat(),
        'database': 'connected' if connection_pool else 'disconnected'
    })

# Estadísticas
@app.route('/api/stats', methods=['GET'])
def get_stats():
    try:
        conn = connection_pool.get_connection()
        cursor = conn.cursor()
        
        cursor.execute('SELECT COUNT(*) as total FROM metrics')
        total_count = cursor.fetchone()[0]
        
        cursor.execute('SELECT COUNT(*) as python_total FROM metrics WHERE api_source = "python"')
        python_count = cursor.fetchone()[0]
        
        return jsonify({
            'total_records': total_count,
            'python_records': python_count,
            'api': 'python'
        })
        
    except Exception as error:
        return jsonify({'error': 'Error obteniendo estadísticas'}), 500
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()

if __name__ == '__main__':
    print("Iniciando API Python...")
    initialize_database()
    print(f"✓ Base de datos: {DB_CONFIG['host']}:{DB_CONFIG['port']}")
    print("✓ Esperando datos de Locust via Ingress...")
    app.run(host='0.0.0.0', port=5000, debug=False)