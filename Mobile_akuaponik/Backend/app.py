from flask import Flask
from flask_cors import CORS
from flask_socketio import SocketIO, emit
import redis
import psycopg2
from psycopg2 import pool as psycopg2_pool
import json
import joblib
import threading
import time
from datetime import datetime
import firebase_admin
from route_api import create_api_blueprint
from firebase_admin import credentials, messaging
from water_quality_reference import (
    danger_notification_body as wq_danger_notification_body,
    DANGER_NOTIFICATION_TITLE as WQ_DANGER_TITLE,
    evaluate_all,
)

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

# Koneksi database utama: Redis — cache dan postgresql - basis data utama
db_pool = psycopg2_pool.ThreadedConnectionPool(
    1, 10,
    host="localhost", database="akuaponik",
    user="postgres", password="123456", port=5432
)
redis_client = redis.Redis(
    host='localhost', port=6379, db=0,
    decode_responses=True,
    socket_connect_timeout=5,
    socket_keepalive=True,
)

# Variabel retensi & waktu
DATA_BUFFER      = []      # Buffer penampung data 5 detik sebelum diagregasi jadi 5 menit
BUFFER_MAX_SIZE  = 60      # 60 data (5 menit / interval 5 detik)
TTL              = 3600        # 1 jam — data riwayat sensor di Redis
TTL_NOTIF        = 7*24*3600   # 7 hari — riwayat notifikasi
TTL_FCM_TOKEN    = 30*24*3600  # 30 hari — retensi token FCM
UPDATE_INTERVAL  = 5           # 5 detik — polling real-time
DB_SAVE_INTERVAL = 300         # 5 menit — simpan hasil agregasi ke PostgreSQL
WARNING_STATUSES          = {'bahaya'}
CONSECUTIVE_THRESHOLD     = 3
NOTIFICATION_COOLDOWN_MAX = 10*60
REDIS_FCM_TOKENS_KEY      = "fcm_device_tokens"

notification_lock  = threading.Lock()
notification_state = {
    'bahaya': {'count': 0, 'last_sent': None},
}

# Model Machine Learning (KNN)
model           = joblib.load('knn_water_quality_model.pkl')
scaler          = joblib.load('scaler.pkl')
feature_columns = joblib.load('feature_columns.pkl')


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
    """
    Kirim push notification via FCM.
    - topic diisi  → kirim ke topik (broadcast)
    - topic None   → kirim multicast ke semua token terdaftar
    """
    if not FIREBASE_ENABLED:
        print("[FCM] Firebase tidak aktif — push tidak dikirim.")
        return {'success': False, 'reason': 'firebase_disabled'}

    str_data: dict = {}
    if data:
        str_data = {k: str(v) for k, v in data.items()}

    str_data['title'] = title
    str_data['body']  = body

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

        state           = notification_state[status]
        state['count'] += 1
        now             = time.time()
        consecutive     = state['count']
        last_sent       = state['last_sent']

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
        do_    = params.get('DO(mg/l)')
        ph     = params.get('pH(ph_units)')
        tds    = params.get('TDS(ppm)')
        temp   = params.get('Temp(cel)')

        issues = evaluate_all(ph=ph, temp=temp, tds=tds, do_val=do_)
        critical_issues = [issue for issue in issues if issue.is_critical]
        notif_title = WQ_DANGER_TITLE
        notif_body  = wq_danger_notification_body(critical_issues, consecutive)

        notification_payload = {
            'type'       : 'alert',
            'status'     : status,
            'message'    : (f"PERINGATAN: Kualitas air '{status.upper()}' "
                            f"selama {consecutive} pembacaan berturut-turut!"),
            'timestamp'  : data['timestamp'],
            'parameters' : data['parameters'],
            'confidence' : data['confidence'],
            'read'       : False,
        }

        notif_key = "water_notifications"
        redis_client.lpush(notif_key, json.dumps(notification_payload))
        redis_client.ltrim(notif_key, 0, 499)
        redis_client.expire(notif_key, TTL_NOTIF)

        socketio.emit('water_alert', notification_payload)
        push_data = {
            'status'    : status,
            'timestamp' : data['timestamp'],
            'do'        : str(do_  if do_  is not None else ''),
            'pH'        : str(ph   if ph   is not None else ''),
            'tds'       : str(tds  if tds  is not None else ''),
            'temp'      : str(temp if temp is not None else ''),
            'screen'    : 'history',
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

        state['count']     = 0
        state['last_sent'] = now


def aggregate_buffer(buffer: list) -> dict:
    temps = [d['parameters']['Temp(cel)']    for d in buffer]
    phs   = [d['parameters']['pH(ph_units)'] for d in buffer]
    dos   = [d['parameters']['DO(mg/l)']     for d in buffer]
    tdss  = [d['parameters']['TDS(ppm)']     for d in buffer]
    return {
        'temp_avg': sum(temps) / len(temps),
        'ph_avg':   sum(phs) / len(phs),
        'do_avg':   sum(dos) / len(dos),
        'tds_avg':  sum(tdss) / len(tdss),
        'sample_count': len(buffer),
    }

def classify_average(agg: dict) -> tuple:
    avg_params = {
        'DO(mg/l)':     agg['do_avg'],
        'pH(ph_units)': agg['ph_avg'],
        'TDS(ppm)':     agg['tds_avg'],
        'Temp(cel)':    agg['temp_avg'],
    }
    ordered = [avg_params[col] for col in feature_columns]
    features_scaled = scaler.transform([ordered])
    status = model.predict(features_scaled)[0]
    proba = model.predict_proba(features_scaled)[0]
    confidence = float(max(proba) * 100)
    return status, confidence


def generate_sensor_data():
    global current_index
    global DATA_BUFFER

    last_db_save_time = time.time()
    print("[DATA ENGINE] Menjalankan engine hibrida dua database...")

    # KONEKSI A: Khusus Membaca Data dari Database Electron (aquaphonik)
    try:
        electron_conn = psycopg2.connect(
            host="localhost",
            database="aquaphonik",
            user="postgres",
            password="123456",
            port=5432
        )
        electron_cursor = electron_conn.cursor()
        print("[DATA ENGINE ✓] Terhubung ke Database Electron (aquaphonik) untuk pembacaan.")
    except Exception as err_a:
        print(f"[DATA ENGINE ✗] Gagal terhubung ke Database Electron: {err_a}")
        return

    # KONEKSI B: Khusus Menyimpan Data ke Database Riset Python (akuaponik)
    try:
        research_conn = psycopg2.connect(
            host="localhost",
            database="akuaponik",
            user="postgres",
            password="123456",
            port=5432
        )
        research_cursor = research_conn.cursor()
        print("[DATA ENGINE ✓] Terhubung ke Database Riset (akuaponik) untuk penyimpanan histori.")
    except Exception as err_b:
        print(f"[DATA ENGINE ✗] Gagal terhubung ke Database Riset Anda: {err_b}")
        return

    while True:
        try:
            # === LANGKAH 1: Ambil 1 baris data sensor terbaru dari tabel milik Electron ===
            electron_cursor.execute(
                """
                SELECT id, temp_water, ph, tds, do_value, timestamp
                FROM sensor_logs ORDER BY timestamp DESC LIMIT 1
                """
            )
            row = electron_cursor.fetchone()

            if row:
                db_id, temp_water, ph, tds, do_value, timestamp = row

                # === LANGKAH 2: Petakan 4 parameter yang dibutuhkan oleh Model KNN ===
                params = {
                    'DO(mg/l)':     float(do_value or 0),
                    'pH(ph_units)': float(ph or 0),
                    'TDS(ppm)':     float(tds or 0),
                    'Temp(cel)':    float(temp_water or 0),
                }

                # === LANGKAH 3: Jalankan Prediksi Kualitas Air dengan KNN ===
                ordered = [params[col] for col in feature_columns]
                features_scaled = scaler.transform([ordered])
                status = model.predict(features_scaled)[0]
                proba = model.predict_proba(features_scaled)[0]
                confidence = float(max(proba) * 100)

                # Bentuk objek data akhir untuk cache dan Flutter (nilai TERKINI, real-time 5 detik)
                data = {
                    'timestamp': timestamp.isoformat() if hasattr(timestamp, 'isoformat') else str(timestamp),
                    'status': status,
                    'confidence': confidence,
                    'sensor_valid': True,
                    'parameters': params,
                }

                # === LANGKAH 4: Distribusi ke Redis & WebSocket (Untuk Flutter) ===
                redis_client.set('current_water_data', json.dumps(data), ex=TTL)
                history_key = "water_sensor_history"
                redis_client.lpush(history_key, json.dumps(data))
                redis_client.ltrim(history_key, 0, 3600)
                redis_client.expire(history_key, TTL)

                socketio.emit('water_data_update', data)
                print(f"[{datetime.now().strftime('%H:%M:%S')}] READ: Electron DB -> Status: {status} | DO: {params['DO(mg/l)']} | pH: {params['pH(ph_units)']} | TDS: {params['TDS(ppm)']} | Temp: {params['Temp(cel)']}")

                # Cek notifikasi bahaya (berbasis pembacaan real-time berturut-turut)
                try:
                    check_and_send_notification(status, data)
                except Exception as notif_err:
                    print(f"[ERROR NOTIF] {notif_err}")

                # Tampung data ke buffer untuk diagregasi setiap 5 menit
                DATA_BUFFER.append(data)
                if len(DATA_BUFFER) > BUFFER_MAX_SIZE:
                    DATA_BUFFER = DATA_BUFFER[-BUFFER_MAX_SIZE:]

                # === LANGKAH 5: Simpan HASIL AGREGASI 5 menit ke Database Riset (akuaponik) ===
                current_time = time.time()
                if current_time - last_db_save_time >= DB_SAVE_INTERVAL:
                    if DATA_BUFFER:
                        agg = aggregate_buffer(DATA_BUFFER)
                        avg_status, avg_confidence = classify_average(agg)
                        print(f"--- status={avg_status} ({round(avg_confidence,1)}%) — menyimpan ke Database Riset (akuaponik) ---")
                        try:
                            research_cursor.execute(
                                """
                                INSERT INTO water_history
                                (created_at, water_Temp, water_pH, disolved_oxg, TDS, status)
                                VALUES (%s, %s, %s, %s, %s, %s)
                                """,
                                (data['timestamp'],
                                 round(agg['temp_avg'], 3),
                                 round(agg['ph_avg'], 3),
                                 round(agg['do_avg'], 3),
                                 int(round(agg['tds_avg'])),
                                 avg_status)
                            )
                            research_conn.commit()
                            print("[DB WRITE ✓] Data rata-rata 5 menit berhasil disimpan ke database.")
                        except Exception as db_write_err:
                            print(f"[DB WRITE ✗] Gagal menyimpan ke database riset: {db_write_err}")
                            research_conn.rollback()
                    else:
                        print("[DATA ENGINE ⚠] Buffer kosong — tidak ada data untuk diagregasi pada window ini.")
                    last_db_save_time = current_time
                    DATA_BUFFER = []  
                time.sleep(UPDATE_INTERVAL)
            else:
                print("[DATA ENGINE ⚠] Tabel sensor_logs di database Electron kosong. Menunggu data masuk...")

        except Exception as e:
            print(f"[ERROR MAIN LOOP] generate_sensor_data: {e}")
            time.sleep(2)
            try:
                electron_conn.rollback()
                research_conn.rollback()
            except Exception:
                pass

data_thread = threading.Thread(target=generate_sensor_data, daemon=True)
data_thread.start()


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
    print("  Flask API + WebSocket + Firebase FCM — Akuaponik Monitor")
    print("Sensor:")
    print("  GET    /api/current              — Data terkini")
    print("  GET    /api/history              — History 1 jam")
    print("  GET    /api/stats                — Statistik")
    print("  GET    /api/health               — Health check")
    print("Kontrol Perangkat:")
    print("  POST   /api/control              — Kirim perintah ON/OFF")
    print("  GET    /api/control/status       — Status semua perangkat")
    print("Notifikasi:")
    print("  GET    /api/notifications        — History notifikasi bahaya")
    print("  DELETE /api/notifications/clear  — Hapus semua notifikasi")
    print("  DELETE /api/notifications/clean  — Hapus notifikasi > 7 hari")
    print("FCM:")
    print("  POST   /api/fcm/register         — Daftarkan token perangkat")
    print("  DELETE /api/fcm/unregister       — Hapus token perangkat")
    print("  GET    /api/fcm/tokens           — Lihat token terdaftar")
    print("  POST   /api/fcm/send             — Kirim notifikasi manual")
    print(f"Update Interval  : {UPDATE_INTERVAL}s")
    print(f"DB Save Interval : {DB_SAVE_INTERVAL}s ({DB_SAVE_INTERVAL // 60} menit)")
    print(f"Notif Threshold  : {CONSECUTIVE_THRESHOLD}x berturut-turut")
    print(f"Notif Cooldown   : {NOTIFICATION_COOLDOWN_MAX // 60} menit")
    print(f"Firebase         : {'✓ Aktif' if FIREBASE_ENABLED else '✗ Tidak Aktif'}")
    print("=" * 60)
    socketio.run(app, host='0.0.0.0', port=5000, debug=False, allow_unsafe_werkzeug=True,)