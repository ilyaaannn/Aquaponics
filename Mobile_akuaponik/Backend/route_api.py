from flask import Blueprint, jsonify, request, Response
from datetime import datetime
import json
import pytz 

# Set zona waktu Asia/Jakarta
JAKARTA_TZ = pytz.timezone('Asia/Jakarta')

def get_jakarta_time():
    return datetime.now(JAKARTA_TZ)


def format_jakarta_iso(dt):
    if dt.tzinfo is None:
        dt = JAKARTA_TZ.localize(dt)
    return dt.isoformat()


def create_api_blueprint(
    *,
    redis_client,
    db_pool,
    socketio,
    FIREBASE_ENABLED,
    send_push_notification,
    REDIS_FCM_TOKENS_KEY,
    TTL_NOTIF,
    TTL_FCM_TOKEN,
):
    api_bp = Blueprint('api', __name__)
    from firebase_admin import messaging

    # Helper untuk mendapatkan koneksi database
    def get_db_conn():
        return db_pool.getconn()

    def return_db_conn(conn):
        if conn:
            db_pool.putconn(conn)


    # -------------------------------------------------
    # SENSOR
    @api_bp.route('/api/current', methods=['GET'])
    def get_current_data():
        """Ambil data kualitas air paling terkini dari cache Redis."""
        try:
            data = redis_client.get('current_water_data')
            if data:
                response_data = json.loads(data)
                try:
                    dt = datetime.fromisoformat(response_data['timestamp'])
                    if dt.tzinfo is None:
                        dt = JAKARTA_TZ.localize(dt)
                    response_data['timestamp'] = dt.isoformat()
                except:
                    response_data['timestamp'] = get_jakarta_time().isoformat()
                response_data['last_update'] = get_jakarta_time().isoformat()
                return jsonify(response_data)
            return jsonify({'error': 'No data available'}), 404
        except Exception as e:
            return jsonify({'error': str(e)}), 500

    @api_bp.route('/api/history', methods=['GET'])
    def get_history():
        """Ambil data riwayat sensor selama 1 jam terakhir dari Redis."""
        try:
            history_key  = "water_sensor_history"
            history_data = redis_client.lrange(history_key, 0, -1)
            if history_data:
                history = []
                for item in history_data:
                    data = json.loads(item)
                    try:
                        dt = datetime.fromisoformat(data['timestamp'])
                        if dt.tzinfo is None:
                            dt = JAKARTA_TZ.localize(dt)
                        data['timestamp'] = dt.isoformat()
                    except:
                        pass
                    history.append(data)
                history.reverse()
                return jsonify(history)
            return jsonify([])
        except Exception as e:
            return jsonify({'error': str(e)}), 500

    @api_bp.route('/api/stats', methods=['GET'])
    def get_stats():
        """Statistik ringkas: total pembacaan, distribusi status, rata-rata confidence."""
        try:
            history_key  = "water_sensor_history"
            history_data = redis_client.lrange(history_key, 0, -1)
            if not history_data:
                return jsonify({'error': 'No data available'}), 404
            history = [json.loads(item) for item in history_data]

            status_counts    = {'ideal': 0, 'normal': 0, 'bahaya': 0}
            total_confidence = 0
            for item in history:
                if item['status'] in status_counts:
                    status_counts[item['status']] += 1
                total_confidence += item['confidence']

            total = max(len(history), 1)
            stats = {
                'total_readings'      : total,
                'status_distribution' : {
                    k: (v / total) * 100 for k, v in status_counts.items()
                },
                'average_confidence'  : total_confidence / total,
                'last_update'         : history[-1]['timestamp'] if history else None,
            }
            return jsonify(stats)
        except Exception as e:
            return jsonify({'error': str(e)}), 500

    @api_bp.route('/api/sensor/export', methods=['GET'])
    def export_sensor_csv():
        """Export data sensor ke CSV dari tabel water_history."""
        conn = None
        cursor = None
        try:
            conn = get_db_conn()
            cursor = conn.cursor()

            start_date = request.args.get('start_date')
            end_date = request.args.get('end_date')
            query = """ SELECT created_at, water_Temp, water_pH, disolved_oxg, TDS, status FROM water_history """
            conditions = []
            params = []

            if start_date:
                conditions.append("created_at >= %s")
                params.append(start_date)
            if end_date:
                conditions.append("created_at <= %s")
                params.append(end_date)

            if conditions:
                query += " WHERE " + " AND ".join(conditions)

            query += " ORDER BY created_at ASC"

            cursor.execute(query, tuple(params))
            rows = cursor.fetchall()
            col_names = [desc[0] for desc in cursor.description]

            print(f"[EXPORT] filter start_date={start_date!r} end_date={end_date!r} -> {len(rows)} baris")

            lines = [','.join(col_names)]
            for row in rows:
                formatted_row = []
                for i, v in enumerate(row):
                    if v is None:
                        formatted_row.append('')
                    elif isinstance(v, datetime):
                        # Konversi ke waktu Jakarta untuk export
                        if v.tzinfo is None:
                            v = JAKARTA_TZ.localize(v)
                        formatted_row.append(v.strftime('%Y-%m-%d %H:%M:%S'))
                    elif isinstance(v, float):
                        formatted_row.append(f"{v:.3f}")
                    else:
                        formatted_row.append(str(v))
                lines.append(','.join(formatted_row))
            csv_content = '\n'.join(lines)

            # Nama file dinamis dengan waktu Jakarta
            now_jkt = get_jakarta_time()
            if start_date and end_date:
                start_label = start_date[:10].replace('-', '')
                end_label = end_date[:10].replace('-', '')
                filename = f'sensor_data_{start_label}-{end_label}.csv'
            else:
                filename = f'sensor_data_{now_jkt.strftime("%Y%m%d_%H%M%S")}.csv'

            return Response(
                csv_content,
                mimetype='text/csv',
                headers={
                    'Content-Disposition':
                        f'attachment; filename={filename}'
                }
            )
        except Exception as e:
            return jsonify({'error': str(e)}), 500
        finally:
            if cursor:
                cursor.close()
            if conn:
                return_db_conn(conn)


    # -------------------------------------------------
    # CATATAN ARSITEKTUR (Opsi A):
    # Kontrol aktuator (aerator/pompa air) TIDAK lagi lewat server Python ini.
    # Mobile app mengirim perintah langsung ke server Desktop (Electron) via
    # Socket.IO event 'actuator/command', karena server Desktop-lah yang
    # memegang koneksi serial fisik ke Arduino. Server Python di sini murni
    # untuk pembacaan AI/histori kualitas air.
    # -------------------------------------------------
    # NOTIFIKASI
    @api_bp.route('/api/notifications', methods=['GET'])
    def get_notifications():
        """Ambil semua daftar riwayat notifikasi bahaya yang tersimpan di Redis."""
        try:
            raw_list = redis_client.lrange("water_notifications", 0, -1)
            if raw_list:
                return jsonify([json.loads(item) for item in raw_list])
            return jsonify([])
        except Exception as e:
            return jsonify({'error': str(e)}), 500

    @api_bp.route('/api/notifications/clear', methods=['DELETE'])
    def clear_notifications():
        """Hapus seluruh riwayat notifikasi tanpa sisa dari Redis."""
        try:
            redis_client.delete("water_notifications")
            return jsonify({'message': 'Semua notifikasi berhasil dihapus'})
        except Exception as e:
            return jsonify({'error': str(e)}), 500

    @api_bp.route('/api/notifications/clean', methods=['DELETE'])
    def clean_old_notifications():
        """Hapus notifikasi lama sebelum tanggal tertentu."""
        try:
            data = request.get_json(silent=True) or {}
            before_date_str = data.get('before_date')
            if not before_date_str:
                return jsonify({'error': 'Parameter before_date diperlukan'}), 400

            before_date = datetime.fromisoformat(before_date_str)
            notif_key   = "water_notifications"
            raw_list    = redis_client.lrange(notif_key, 0, -1)

            if not raw_list:
                return jsonify({'message': 'Tidak ada notifikasi untuk dibersihkan', 'removed': 0})

            kept    = []
            removed = 0
            for raw in raw_list:
                try:
                    item = json.loads(raw)
                    ts   = datetime.fromisoformat(item.get('timestamp', ''))
                    if ts >= before_date:
                        kept.append(raw)
                    else:
                        removed += 1
                except Exception:
                    kept.append(raw)

            pipe = redis_client.pipeline()
            pipe.delete(notif_key)
            if kept:
                pipe.rpush(notif_key, *kept)
                pipe.expire(notif_key, TTL_NOTIF)
            pipe.execute()

            print(f"[CLEAN] {removed} notifikasi lama dihapus (sebelum {before_date_str})")
            return jsonify({'message': f'{removed} notifikasi lama dihapus', 'removed': removed})
        except Exception as e:
            return jsonify({'error': str(e)}), 500


    # -------------------------------------------------
    # FCM (Firebase Cloud Messaging)
    @api_bp.route('/api/fcm/register', methods=['POST'])
    def register_fcm_token():
        """Daftarkan token unik FCM dari ponsel pengguna & subscribe ke topik 'bahaya_alerts'."""
        try:
            body     = request.get_json(silent=True) or {}
            token    = body.get('token', '').strip()
            platform = body.get('platform', 'android')

            if not token:
                return jsonify({'error': 'Token tidak boleh kosong'}), 400

            metadata = json.dumps({
                'platform'      : platform,
                'registered_at' : body.get('registered_at', datetime.now().isoformat()),
                'last_seen'     : datetime.now().isoformat(),
            })
            redis_client.hset(REDIS_FCM_TOKENS_KEY, token, metadata)
            redis_client.expire(REDIS_FCM_TOKENS_KEY, TTL_FCM_TOKEN)

            if FIREBASE_ENABLED:
                try:
                    messaging.subscribe_to_topic([token], 'bahaya_alerts')
                    print(f"[FCM] Token di-subscribe ke 'bahaya_alerts': {token[:20]}…")
                except Exception as e:
                    print(f"[FCM] Gagal subscribe topik: {e}")

            print(f"[FCM] Token terdaftar ({platform}): {token[:20]}…")
            return jsonify({'message': 'Token berhasil didaftarkan', 'platform': platform}), 200
        except Exception as e:
            return jsonify({'error': str(e)}), 500

    @api_bp.route('/api/fcm/unregister', methods=['DELETE'])
    def unregister_fcm_token():
        """Hapus token perangkat dari Redis."""
        try:
            body  = request.get_json(silent=True) or {}
            token = body.get('token', '').strip()
            if not token:
                return jsonify({'error': 'Token tidak boleh kosong'}), 400

            redis_client.hdel(REDIS_FCM_TOKENS_KEY, token)

            if FIREBASE_ENABLED:
                try:
                    messaging.unsubscribe_from_topic([token], 'bahaya_alerts')
                except Exception:
                    pass

            print(f"[FCM] Token dihapus: {token[:20]}…")
            return jsonify({'message': 'Token berhasil dihapus'}), 200
        except Exception as e:
            return jsonify({'error': str(e)}), 500

    @api_bp.route('/api/fcm/tokens', methods=['GET'])
    def list_fcm_tokens():
        """Tampilkan daftar seluruh token perangkat yang terdaftar."""
        try:
            all_tokens = redis_client.hgetall(REDIS_FCM_TOKENS_KEY)
            result = []
            for token, meta_str in all_tokens.items():
                try:
                    meta = json.loads(meta_str)
                except Exception:
                    meta = {}
                result.append({
                    'token_preview' : token[:20] + '…',
                    'platform'      : meta.get('platform', 'unknown'),
                    'registered_at' : meta.get('registered_at'),
                    'last_seen'     : meta.get('last_seen'),
                })
            return jsonify({'total': len(result), 'tokens': result})
        except Exception as e:
            return jsonify({'error': str(e)}), 500

    @api_bp.route('/api/fcm/send', methods=['POST'])
    def send_fcm_manual():
        """Endpoint pengujian: kirim notifikasi push secara manual dengan teks kustom."""
        try:
            body  = request.get_json(silent=True) or {}
            title = body.get('title', 'Test Notifikasi Akuaponik')
            msg   = body.get('body',  'Ini adalah notifikasi pengujian.')
            topic = body.get('topic')

            result = send_push_notification(
                title=title,
                body=msg,
                data={'type': 'manual_test', 'timestamp': datetime.now().isoformat()},
                topic=topic,
            )
            return jsonify({'message': 'Notifikasi dikirim', 'result': result})
        except Exception as e:
            return jsonify({'error': str(e)}), 500


    # -------------------------------------------------
    # HEALTH CHECK
    @api_bp.route('/api/health', methods=['GET'])
    def health_check():
        """Pastikan server backend, Redis, database, model ML, dan Firebase berjalan normal."""
        try:
            redis_client.ping()
            conn = None
            try:
                conn = get_db_conn()
                cursor = conn.cursor()
                cursor.execute("SELECT 1")
                cursor.close()
                db_status = 'connected'
            except Exception as e:
                db_status = f'error: {str(e)}'
            finally:
                if conn:
                    return_db_conn(conn)

            return jsonify({
                'status'          : 'healthy',
                'redis'           : 'connected',
                'database'        : db_status,
                'model'           : 'loaded',
                'firebase'        : 'enabled' if FIREBASE_ENABLED else 'disabled',
                'fcm_tokens_total': redis_client.hlen(REDIS_FCM_TOKENS_KEY),
                'timestamp'       : get_jakarta_time().isoformat(),
                'timezone'        : 'Asia/Jakarta',
            })
        except Exception as e:
            return jsonify({'status': 'unhealthy', 'error': str(e)}), 500

    return api_bp