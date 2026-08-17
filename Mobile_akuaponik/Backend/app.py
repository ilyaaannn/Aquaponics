from flask import Flask
from flask_cors import CORS
from flask_socketio import SocketIO, emit
import socketio as sio_client_lib  
import os
import redis
import psycopg2
from psycopg2 import pool as psycopg2_pool
import json
import joblib
import threading
import time
import pytz
from datetime import datetime
import firebase_admin
from route_api import create_api_blueprint
from firebase_admin import credentials, messaging
from water_quality_reference import (
    danger_notification_body as wq_danger_notification_body,
    DANGER_NOTIFICATION_TITLE as WQ_DANGER_TITLE,
    evaluate_all,
)

# DEFINISIKAN ZONA WAKTU 
JAKARTA_TZ = pytz.timezone('Asia/Jakarta')

def get_jakarta_time():
    """Mendapatkan waktu sekarang dalam zona Asia/Jakarta"""
    return datetime.now(JAKARTA_TZ)

def format_jakarta_iso(dt):
    """Format datetime ke ISO string dengan zona Jakarta"""
    if dt.tzinfo is None:
        dt = JAKARTA_TZ.localize(dt)
    return dt.isoformat()

# Firebase Admin SDK — untuk fitur notifikasi push FCM
_FIREBASE_CRED_PATH = 'firebase-adminsdk.json'
try:
    _cred = credentials.Certificate(_FIREBASE_CRED_PATH)
    firebase_admin.initialize_app(_cred)
    FIREBASE_ENABLED = True
    print("[FCM] Firebase Admin SDK berhasil diinisialisasi.")
except Exception as _e:
    FIREBASE_ENABLED = False
    print(f"[FCM] ⚠ Firebase Admin SDK tidak aktif: {_e}")

# Flask + CORS + SocketIO (mode async threading)
app = Flask(__name__)
CORS(app, resources={r"/api/*": {"origins": "*"}})
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')

# Koneksi database utama: Redis — cache data real-time dan postgresql - basis data utama
DB_CONFIG = {
    'host': 'localhost',
    'database': 'aquaphonik',
    'user': 'postgres',
    'password': '123456',
    'port': 5432
}
db_pool = psycopg2_pool.ThreadedConnectionPool(
    1, 10,
    host=DB_CONFIG['host'],
    database=DB_CONFIG['database'],
    user=DB_CONFIG['user'],
    password=DB_CONFIG['password'],
    port=DB_CONFIG['port']
)
redis_client = redis.Redis(
    host='localhost', port=6379, db=0,
    decode_responses=True,
    socket_connect_timeout=5,
    socket_keepalive=True,
)

# Variabel retensi & waktu
DATA_BUFFER = []
BUFFER_MAX_SIZE = 200
TTL = 3600        # 1 jam — data riwayat sensor di Redis
TTL_NOTIF = 7*24*3600   # 7 hari — riwayat notifikasi
TTL_FCM_TOKEN = 30*24*3600  # 30 hari — retensi token FCM
DB_SAVE_INTERVAL = 300         # 5 menit — simpan hasil agregasi ke PostgreSQL
DESKTOP_SOCKET_URL = os.environ.get('DESKTOP_SOCKET_URL', 'http://localhost:8000')
WARNING_STATUSES = {'bahaya'}
CONSECUTIVE_THRESHOLD = 3
NOTIFICATION_COOLDOWN_MAX = 10*60
REDIS_FCM_TOKENS_KEY = "fcm_device_tokens"

notification_lock = threading.Lock()
notification_state = {
    'bahaya': {'count': 0, 'last_sent': None},
}

# Model Machine Learning (KNN)
model = joblib.load('knn_water_quality_model.pkl')
scaler = joblib.load('scaler.pkl')
feature_columns = joblib.load('feature_columns.pkl')


def ensure_table_exists():
    """
    Memastikan tabel water_history ada di database aquaphonik.
    Jika belum ada, buat tabel secara otomatis.
    """
    conn = None
    cursor = None
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cursor = conn.cursor()
        
        # Cek apakah tabel water_history sudah ada
        cursor.execute("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_name = 'water_history'
            );
        """)
        table_exists = cursor.fetchone()[0]
        
        if not table_exists:
            print("[DB] Tabel 'water_history' belum ada. Membuat tabel...")
            cursor.execute("""
                CREATE TABLE water_history (
                    id SERIAL PRIMARY KEY,
                    created_at TIMESTAMP NOT NULL,
                    water_Temp DECIMAL(10, 3),
                    water_pH DECIMAL(10, 3),
                    disolved_oxg DECIMAL(10, 3),
                    TDS INTEGER,
                    status VARCHAR(50)
                );
            """)
            cursor.execute("""
                CREATE INDEX idx_water_history_created_at 
                ON water_history(created_at DESC);
            """)
            conn.commit()
            print("[DB ✓] Tabel 'water_history' berhasil dibuat.")
        else:
            print("[DB ✓] Tabel 'water_history' sudah ada.")
            
    except Exception as e:
        print(f"[DB ERROR] Gagal memastikan tabel: {e}")
        if conn:
            conn.rollback()
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()


def get_db_connection():
    """Mendapatkan koneksi database dari pool."""
    return db_pool.getconn()


def return_db_connection(conn):
    """Mengembalikan koneksi database ke pool."""
    if conn:
        db_pool.putconn(conn)


def _get_all_fcm_tokens() -> list:
    try:
        tokens = redis_client.hkeys(REDIS_FCM_TOKENS_KEY)
        return [t for t in tokens if t]
    except Exception as e:
        print(f"[FCM] Gagal mengambil daftar token: {e}")
        return []


def send_push_notification(
    title: str,
    body: str,
    data: dict = None,
    topic: str = None,
) -> dict:
    """ Kirim push notification via FCM. """
    if not FIREBASE_ENABLED:
        print("[FCM] Firebase tidak aktif — push tidak dikirim.")
        return {'success': False, 'reason': 'firebase_disabled'}

    str_data: dict = {}
    if data:
        str_data = {k: str(v) for k, v in data.items()}

    str_data['title'] = title
    str_data['body'] = body

    android_config = messaging.AndroidConfig(
        priority='high',
    )
    apns_config = messaging.APNSConfig(
        payload=messaging.APNSPayload(
            aps=messaging.Aps(
                sound='default',
                badge=1,
                content_available=True,
                custom_data={'interruption-level': 'time-sensitive'},
            )
        ),
        headers={'apns-push-type': 'background', 'apns-priority': '5'},
    )

    result = {'success': 0, 'failure': 0, 'details': []}

    if topic:
        msg = messaging.Message(
            data=str_data,
            topic=topic,
            android=android_config,
            apns=apns_config,
        )
        try:
            response = messaging.send(msg)
            result.update({'success': 1, 'topic': topic, 'message_id': response})
            print(f"[FCM ✓] Topik '{topic}' — ID: {response}")
        except Exception as e:
            result.update({'failure': 1, 'error': str(e)})
            print(f"[FCM ✗] Gagal kirim ke topik '{topic}': {e}")
    else:
        tokens = _get_all_fcm_tokens()
        if not tokens:
            print("[FCM] Tidak ada token terdaftar.")
            return {'success': False, 'reason': 'no_tokens'}

        BATCH = 500
        for i in range(0, len(tokens), BATCH):
            batch_tokens = tokens[i:i + BATCH]
            multi_msg = messaging.MulticastMessage(
                data=str_data,
                tokens=batch_tokens,
                android=android_config,
                apns=apns_config,
            )
            try:
                batch_res = messaging.send_each_for_multicast(multi_msg)
                result['success'] += batch_res.success_count
                result['failure'] += batch_res.failure_count

                for idx, resp in enumerate(batch_res.responses):
                    if not resp.success:
                        err_code = resp.exception.code if resp.exception else 'unknown'
                        if err_code in (
                            'messaging/registration-token-not-registered',
                            'messaging/invalid-registration-token',
                        ):
                            bad_token = batch_tokens[idx]
                            redis_client.hdel(REDIS_FCM_TOKENS_KEY, bad_token)
                            print(f"[FCM] Token tidak valid dihapus: {bad_token[:20]}…")

                print(f"[FCM] Batch {i // BATCH + 1}: "
                      f"✓ {batch_res.success_count}  ✗ {batch_res.failure_count}")
            except Exception as e:
                result['failure'] += len(batch_tokens)
                print(f"[FCM ✗] Error batch multicast: {e}")

    return result


def check_and_send_notification(status: str, data: dict):
    status = str(status).strip().lower()
    with notification_lock:
        if status not in WARNING_STATUSES:
            for key in notification_state:
                notification_state[key]['count'] = 0
            return

        state = notification_state[status]
        state['count'] += 1
        now = time.time()
        consecutive = state['count']
        last_sent = state['last_sent']

        if consecutive < CONSECUTIVE_THRESHOLD:
            print(f"[NOTIF] '{status}' terdeteksi "
                  f"({consecutive}/{CONSECUTIVE_THRESHOLD}) — belum kirim.")
            return

        if last_sent is not None:
            elapsed = now - last_sent
            if elapsed < NOTIFICATION_COOLDOWN_MAX:
                remaining = int(NOTIFICATION_COOLDOWN_MAX - elapsed)
                print(f"[NOTIF] Cooldown '{status}' — sisa "
                      f"{remaining // 60}m {remaining % 60}s.")
                return

        params = data.get('parameters', {})
        do_ = params.get('DO(mg/l)')
        ph = params.get('pH(ph_units)')
        tds = params.get('TDS(ppm)')
        temp = params.get('Temp(cel)')

        issues = evaluate_all(ph=ph, temp=temp, tds=tds, do_val=do_)
        critical_issues = [issue for issue in issues if issue.is_critical]
        notif_title = WQ_DANGER_TITLE
        notif_body = wq_danger_notification_body(critical_issues, consecutive)

        notification_payload = {
            'type': 'alert',
            'status': status,
            'message': (f"PERINGATAN: Kualitas air '{status.upper()}' selama {consecutive} pembacaan berturut-turut!"),
            'timestamp': data['timestamp'],
            'parameters': data['parameters'],
            'confidence': data['confidence'],
            'read': False,
        }

        notif_key = "water_notifications"
        redis_client.lpush(notif_key, json.dumps(notification_payload))
        redis_client.ltrim(notif_key, 0, 499)
        redis_client.expire(notif_key, TTL_NOTIF)

        socketio.emit('water_alert', notification_payload)
        push_data = {
            'status': status,
            'timestamp': data['timestamp'],
            'do': str(do_ if do_ is not None else ''),
            'pH': str(ph if ph is not None else ''),
            'tds': str(tds if tds is not None else ''),
            'temp': str(temp if temp is not None else ''),
            'screen': 'history',
        }

        try:
            fcm_result = send_push_notification(
                title=notif_title,
                body=notif_body,
                data=push_data,
                topic='bahaya_alerts',
            )
            print(f"[FCM] Hasil pengiriman: {fcm_result}")
        except Exception as fcm_err:
            print(f"[FCM ERROR] Gagal mengirim push notification: {fcm_err}")

        state['count'] = 0
        state['last_sent'] = now


def aggregate_buffer(buffer: list) -> dict:
    temps = [d['parameters']['Temp(cel)'] for d in buffer]
    phs = [d['parameters']['pH(ph_units)'] for d in buffer]
    dos = [d['parameters']['DO(mg/l)'] for d in buffer]
    tdss = [d['parameters']['TDS(ppm)'] for d in buffer]
    return {
        'temp_avg': sum(temps) / len(temps),
        'ph_avg': sum(phs) / len(phs),
        'do_avg': sum(dos) / len(dos),
        'tds_avg': sum(tdss) / len(tdss),
        'sample_count': len(buffer),
    }


def classify_average(agg: dict) -> tuple:
    avg_params = {
        'DO(mg/l)': agg['do_avg'],
        'pH(ph_units)': agg['ph_avg'],
        'TDS(ppm)': agg['tds_avg'],
        'Temp(cel)': agg['temp_avg'],
    }
    ordered = [avg_params[col] for col in feature_columns]
    features_scaled = scaler.transform([ordered])
    status = model.predict(features_scaled)[0]
    proba = model.predict_proba(features_scaled)[0]
    confidence = float(max(proba) * 100)
    return status, confidence


desktop_socket = sio_client_lib.Client(
    reconnection=True,
    reconnection_attempts=0,   
    reconnection_delay=2,
    reconnection_delay_max=15,
)

last_db_save_time = time.time()


@desktop_socket.event
def connect():
    print(f"[SOCKET-CLIENT] ✓ Terhubung ke server Desktop di {DESKTOP_SOCKET_URL}")


@desktop_socket.event
def connect_error(data):
    print(f"[SOCKET-CLIENT] ✗ Gagal konek ke {DESKTOP_SOCKET_URL}: {data}")


@desktop_socket.event
def disconnect():
    print("[SOCKET-CLIENT] Terputus dari server Desktop — auto-reconnect aktif...")


@desktop_socket.on('sensor/realtime')
def on_sensor_realtime(payload: dict):
    handle_incoming_sensor_data(payload)


def handle_incoming_sensor_data(raw: dict) -> None:
    global DATA_BUFFER

    try:
        do_value = raw.get('do_value', raw.get('do'))
        params = {
            'DO(mg/l)': float(do_value or 0),
            'pH(ph_units)': float(raw.get('ph', 0) or 0),
            'TDS(ppm)': float(raw.get('tds', 0) or 0),
            'Temp(cel)': float(raw.get('temp_water', 0) or 0),
        }

        # === Prediksi KNN ===
        ordered = [params[col] for col in feature_columns]
        features_scaled = scaler.transform([ordered])
        status = model.predict(features_scaled)[0]
        proba = model.predict_proba(features_scaled)[0]
        confidence = float(max(proba) * 100)

        timestamp_jkt = get_jakarta_time()
        data = {
            'timestamp': timestamp_jkt.isoformat(),
            'status': status,
            'confidence': confidence,
            'sensor_valid': True,
            'parameters': params,
        }

        print(f"[{timestamp_jkt.strftime('%H:%M:%S')}] PUSH: Status: {status} | DO: {params['DO(mg/l)']} | pH: {params['pH(ph_units)']} | TDS: {params['TDS(ppm)']} | Temp: {params['Temp(cel)']}")

        # === Distribusi ke Redis & WebSocket (klien mobile) ===
        redis_client.set('current_water_data', json.dumps(data), ex=TTL)
        history_key = "water_sensor_history"
        redis_client.lpush(history_key, json.dumps(data))
        redis_client.ltrim(history_key, 0, 3600)
        redis_client.expire(history_key, TTL)

        socketio.emit('water_data_update', data)

        # Cek notifikasi bahaya
        try:
            check_and_send_notification(status, data)
        except Exception as notif_err:
            print(f"[ERROR NOTIF] {notif_err}")

        # Tampung data ke buffer untuk agregasi
        DATA_BUFFER.append(data)
        if len(DATA_BUFFER) > BUFFER_MAX_SIZE:
            DATA_BUFFER = DATA_BUFFER[-BUFFER_MAX_SIZE:]

        _maybe_save_aggregate()

    except Exception as e:
        print(f"[ERROR] handle_incoming_sensor_data: {e}")


def _maybe_save_aggregate() -> None:
    """Simpan rata-rata 5 menit ke tabel water_history."""
    global last_db_save_time, DATA_BUFFER

    current_time = time.time()
    if current_time - last_db_save_time < DB_SAVE_INTERVAL:
        return

    if not DATA_BUFFER:
        print("[DATA ENGINE ⚠] Buffer kosong — tidak ada data untuk diagregasi.")
        last_db_save_time = current_time
        return

    agg = aggregate_buffer(DATA_BUFFER)
    avg_status, avg_confidence = classify_average(agg)
    print(f"--- status={avg_status} ({round(avg_confidence, 1)}%) — "
          f"menyimpan ke tabel water_history ({len(DATA_BUFFER)} sampel) ---")

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        save_time = get_jakarta_time()
        cursor.execute(
            """
            INSERT INTO water_history
            (created_at, water_Temp, water_pH, disolved_oxg, TDS, status)
            VALUES (%s, %s, %s, %s, %s, %s)
            """,
            (save_time,
             round(agg['temp_avg'], 3),
             round(agg['ph_avg'], 3),
             round(agg['do_avg'], 3),
             int(round(agg['tds_avg'])),
             avg_status)
        )
        conn.commit()
        cursor.close()
        print("[DB WRITE ✓] Data rata-rata 5 menit berhasil disimpan.")
    except Exception as db_write_err:
        print(f"[DB WRITE ✗] Gagal menyimpan: {db_write_err}")
        if conn:
            conn.rollback()
    finally:
        if conn:
            return_db_connection(conn)

    last_db_save_time = current_time
    DATA_BUFFER = []


def start_desktop_socket_client() -> None:
    """Loop koneksi client Socket.IO ke server Desktop."""
    while True:
        try:
            if not desktop_socket.connected:
                desktop_socket.connect(DESKTOP_SOCKET_URL, wait_timeout=10)
            desktop_socket.wait()
        except Exception as e:
            print(f"[SOCKET-CLIENT] Gagal konek ke {DESKTOP_SOCKET_URL}: {e} "
                  f"— coba lagi 5 detik lagi...")
            time.sleep(5)


# Buat blueprint API
api_bp = create_api_blueprint(
    redis_client=redis_client,
    db_pool=db_pool,
    socketio=socketio,
    FIREBASE_ENABLED=FIREBASE_ENABLED,
    send_push_notification=send_push_notification,
    REDIS_FCM_TOKENS_KEY=REDIS_FCM_TOKENS_KEY,
    TTL_NOTIF=TTL_NOTIF,
    TTL_FCM_TOKEN=TTL_FCM_TOKEN,
)
app.register_blueprint(api_bp)


@socketio.on('connect')
def handle_connect():
    print('Client terhubung via WebSocket')
    emit('connected', {'message': 'Connected to real-time water quality data'})
    try:
        data = redis_client.get('current_water_data')
        if data:
            emit('water_data_update', json.loads(data))
    except Exception:
        pass


@socketio.on('disconnect')
def handle_disconnect():
    print('Client terputus')


if __name__ == '__main__':
    print("=" * 60)
    print("  Flask API + WebSocket + Firebase FCM — Akuaponik Monitor")
    print("=" * 60)
    print("API endpoints:")
    print("  GET    /api/current              — Data terkini")
    print("  GET    /api/history              — History 1 jam")
    print("  GET    /api/stats                — Statistik")
    print("  GET    /api/health               — Health check")
    print("  GET    /api/notifications        — History notifikasi bahaya")
    print("  DELETE /api/notifications/clear  — Hapus semua notifikasi")
    print("  DELETE /api/notifications/clean  — Hapus notifikasi > 7 hari")
    print("  POST   /api/fcm/register         — Daftarkan token perangkat")
    print("  DELETE /api/fcm/unregister       — Hapus token perangkat")
    print("  GET    /api/fcm/tokens           — Lihat token terdaftar")
    print("  POST   /api/fcm/send             — Kirim notifikasi manual")
    print("")
    print(f"Timezone         : Asia/Jakarta (UTC+7)")
    print(f"Sumber Data      : Push via Socket.IO dari {DESKTOP_SOCKET_URL} event 'sensor/realtime'.")
    print(f"DB Save Interval : {DB_SAVE_INTERVAL}s ({DB_SAVE_INTERVAL // 60} menit)")
    print(f"Notif Threshold  : {CONSECUTIVE_THRESHOLD}x berturut-turut")
    print(f"Notif Cooldown   : {NOTIFICATION_COOLDOWN_MAX // 60} menit")
    print(f"Firebase         : {'✓ Aktif' if FIREBASE_ENABLED else '✗ Tidak Aktif'}")
    print("=" * 60)

    ensure_table_exists()
    socket_client_thread = threading.Thread(target=start_desktop_socket_client, daemon=True)
    socket_client_thread.start()

    socketio.run(app, host='0.0.0.0', port=5000, debug=False, allow_unsafe_werkzeug=True)