from flask import Flask, request, jsonify
import mysql.connector
from mysql.connector import pooling
import os
from datetime import datetime

app = Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = 20 * 1024 * 1024 # 20 MB

# Configuración de base de datos para MySQL local
DB_CONFIG = {
    'host': os.getenv('DB_HOST', '172.28.84.245'),
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
            pool_size=20,
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

def get_connection():
    global connection_pool
    if connection_pool is None:
        print("Inicializando pool de conexiones en el worker Flask (get_connection)...")
        initialize_database()
    return connection_pool.get_connection()

# ENDPOINT PRINCIPAL - Recibir datos de Locust via Ingress
@app.route('/api/data', methods=['POST'])
def receive_data():
    data = request.get_json()
    print("DATA RECIBIDA:", data)

    # Si es un solo objeto, lo convertimos en lista
    if isinstance(data, dict):
        data = [data]

    if not isinstance(data, list):
        return jsonify({
            'success': False,
            'error': 'El cuerpo debe ser un arreglo de objetos o un objeto'
        }), 400

    try:
        conn = get_connection()
        cursor = conn.cursor()

        insert_query = """
        INSERT INTO metrics (
            total_ram, ram_libre, uso_ram, porcentaje_ram,
            porcentaje_cpu_uso, porcentaje_cpu_libre,
            procesos_corriendo, total_procesos, procesos_durmiendo,
            procesos_zombie, procesos_parados, hora, api_source
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """

        for item in data:
            values = (
                item.get('total_ram', 0),
                item.get('ram_libre', 0),
                item.get('uso_ram', 0),
                item.get('porcentaje_ram', 0),
                item.get('porcentaje_cpu_uso', 0),
                item.get('porcentaje_cpu_libre', 0),
                item.get('procesos_corriendo', 0),
                item.get('total_procesos', 0),
                item.get('procesos_durmiendo', 0),
                item.get('procesos_zombie', 0),
                item.get('procesos_parados', 0),
                item.get('hora', datetime.now().isoformat()),
                'python'
            )
            cursor.execute(insert_query, values)

        conn.commit()
        return jsonify({'success': True, 'message': 'Datos guardados'}), 201

    except Exception as error:
        import traceback
        print("X Error procesando datos:", error)
        traceback.print_exc()  # <--- Esto imprime el stacktrace completo
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
        conn = get_connection()
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

@app.route('/', methods=['GET'])
def health():
    return "OK", 200

print("Iniciando API Python...")
initialize_database()
print("connection_pool:", connection_pool)
print(f"✓ Base de datos: {DB_CONFIG['host']}:{DB_CONFIG['port']}")
print("✓ Esperando datos de Locust via Ingress...")

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)