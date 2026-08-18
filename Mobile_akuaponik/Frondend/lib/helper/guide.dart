import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

class AppGuide {
  static void showHelpDialog(BuildContext context) {
    showHelpSheet(context);
  }

  static const List<Map<String, dynamic>> helpItems = [
    {
      'section': 'Mengenal Aplikasi',
      'icon': Icons.hub_rounded,
      'color': AppTheme.primaryGreen,
      'title': 'Dua Server, Dua Fungsi Berbeda',
      'desc':
          'Aplikasi ini terhubung ke DUA server sekaligus: "Smartfarm" dan "Desktop". '
          'Keduanya diatur terpisah di halaman Pengaturan dan bisa aktif bersamaan '
          'tanpa saling mengganggu.',
    },
    {
      'section': 'Mengenal Aplikasi',
      'icon': Icons.psychology_rounded,
      'color': Color(0xFF3B82F6),
      'title': 'Server Smartfarm — Analisis AI',
      'desc':
          'Menyediakan status kualitas air hasil klasifikasi model Machine Learning (Ideal/'
          'Normal/Bahaya), riwayat teragregasi, statistik, dan notifikasi push. '
          'Server ini biasanya berjalan di layanan cloud/VPS sehingga bisa diakses '
          'dari mana saja selama ada koneksi internet — cocok untuk pemantauan jarak jauh.',
    },
    {
      'section': 'Mengenal Aplikasi',
      'icon': Icons.computer_rounded,
      'color': AppTheme.tdsColor,
      'title': 'Server Desktop — Data Mentah dari Alat',
      'desc':
          'Menyediakan data sensor mentah langsung dari perangkat yang tersambung kabel USB '
          'ke Arduino/ESP32 (tanpa diproses AI), riwayat lengkap dari database lokal, serta '
          'kontrol manual Aerator dan Pompa Air. Berguna untuk analisis data asli oleh pembudidaya, '
          'terpisah dari hasil klasifikasi AI.',
    },
    {
      'section': 'Mengenal Aplikasi',
      'icon': Icons.travel_explore_rounded,
      'color': AppTheme.statusWarning,
      'title': 'Bisakah Dipantau dari Jarak Jauh?',
      'desc':
          'Bisa. Server Smartfarm umumnya sudah bisa diakses dari luar rumah/kebun karena berjalan '
          'di VPS. Server Desktop pada dasarnya berada di jaringan lokal alat, namun kini bisa '
          'diakses jarak jauh juga bila pemilik sistem mengaktifkan domain/tunnel (mis. Cloudflare '
          'Tunnel) untuknya — tanyakan ke pengelola sistem apakah domain jarak jauh untuk server '
          'Desktop sudah tersedia.',
    },
    {
      'section': 'Dashboard',
      'icon': Icons.dashboard_rounded,
      'color': AppTheme.primaryGreen,
      'title': 'Monitoring Real-Time',
      'desc':
          'Tampilan utama Menunjukkan status kualitas air terkini (Ideal / Normal / Bahaya) '
          'berdasarkan sensor pH, Suhu, TDS dan DO yang diperbarui setiap 5 detik secara otomatis '
          'sesuai dengan preset ekosistem yang aktif.',
    },
    {
      'section': 'Dashboard',
      'icon': Icons.show_chart_rounded,
      'color': Color(0xFF3B82F6),
      'title': 'Grafik Parameter',
      'desc':
          'untuk melihat tren historis pH, Suhu, TDS dan DO '
          'dalam bentuk line chart dari waktu ke waktu.',
    },
    {
      'section': 'Dashboard',
      'icon': Icons.warning_amber_rounded,
      'color': AppTheme.statusWarning,
      'title': 'Indikator Status Bahaya',
      'desc':
          'kartu status akan berubah warna dan menampilkan label "Bahaya" bila parameter keluar dari rentang ideal. '
          'cek Notifikasi di halaman Riwayat untuk melihat detail parameter yang bermasalah.',
    },
    {
      'section': 'Riwayat',
      'icon': Icons.notifications_active_rounded,
      'color': AppTheme.statusDanger,
      'title': 'Tab Notifikasi',
      'desc':
          'Menyimpan daftar peringatan otomatis saat parameter berada di batas bahaya. '
          'Setiap catatan berisi informasi detail parameter yang bermasalah dan notifikasi dihapus otomatis setelah 7 hari',
    },
    {
      'section': 'Riwayat',
      'icon': Icons.sensors_rounded,
      'color': AppTheme.tdsColor,
      'title': 'Tab Data Sensor',
      'desc':
          'Tabel lengkap semua pembacaan sensor (waktu, pH, Suhu, TDS, DO serta status). '
          'Berdasarkan data real-time dari Redis (cache 1 jam) serta dukungan unduh CSV untuk laporan lengkap.',
    },
    {
      'section': 'Riwayat',
      'icon': Icons.calendar_today_rounded,
      'color': Color(0xFF3B82F6),
      'title': 'Filter Tanggal',
      'desc':
          'Ketuk tombol "Filter" untuk menyaring data berdasarkan tanggal tertentu, '
          'memudahkan pengecekan riwayat pada hari spesifik tanpa harus menggulir seluruh data. ',
    },
    {
      'section': 'Riwayat',
      'icon': Icons.download_rounded,
      'color': AppTheme.doColor,
      'title': 'Unduh CSV (Data Lengkap)',
      'desc':
          'Di tab "Data Sensor", ketuk tombol ↓ (pojok kanan bawah) untuk mengunduh '
          'seluruh riwayat sensor dari database. File CSV dapat dibuka di Excel / Google Sheets '
          'untuk analisis lebih lanjut.',
    },
    {
      'section': 'Ekosistem',
      'icon': Icons.eco_rounded,
      'color': AppTheme.primaryGreen,
      'title': 'Konfigurasi Ekosistem',
      'desc':
          'pilih preset ekosistem yang sesuai dengan jenis ikan dan tanaman pada sistem akuaponik Anda. '
          'Setiap preset menampilkan rentang ideal untuk pH, Suhu, TDS dan DO yang akan digunakan sebagai acuan status kualitas air di Dashboard.',
    },
    {
      'section': 'Ekosistem',
      'icon': Icons.tune_rounded,
      'color': AppTheme.tdsColor,
      'title': 'Tabel Batas Parameter Ideal',
      'desc':
          'Menampilkan rentang ideal gabungan untuk pH, Suhu, TDS dan DO berdasarkan preset ekosistem yang aktif',
    },
    {
      'section': 'Pengaturan',
      'icon': Icons.wifi_rounded,
      'color': AppTheme.primaryGreen,
      'title': 'Konfigurasi Server',
      'desc':
          'Isi kartu "Server Smartfarm" dan/atau "Server Desktop" dengan alamat IP atau nama domain '
          'beserta port-nya, lalu ketuk "Hubungkan". Kedua server diatur terpisah — Anda bisa '
          'menghubungkan salah satu saja atau keduanya sekaligus. Status koneksi akan tampil '
          'setelah aplikasi berhasil terhubung ke server.',
    },
    {
      'section': 'Pengaturan',
      'icon': Icons.lock_rounded,
      'color': Color(0xFF3B82F6),
      'title': 'HTTP vs HTTPS',
      'desc':
          'Setiap kartu server punya sakelar HTTP/HTTPS. Pilih "HTTP" jika mengakses lewat alamat '
          'IP di jaringan lokal (mis. rumah/kebun yang sama dengan alat atau VPS tanpa SSL). '
          'Pilih "HTTPS" jika mengakses lewat nama domain untuk pemantauan jarak jauh yang lebih '
          'aman dan stabil (mis. domain VPS dengan SSL, atau domain Cloudflare Tunnel untuk server '
          'Desktop). Kolom Port boleh dikosongkan bila domain HTTPS sudah memakai port standar (443).',
    },
    {
      'section': 'Pengaturan',
      'icon': Icons.air_rounded,
      'color': Color(0xFF3B82F6),
      'title': 'Kontrol Manual Perangkat',
      'desc':
          'Nyalakan / matikan Kontrol Aerator dan Pompa Air langsung dari aplikasi. '
          'Perangkat harus terhubung ke server terlebih dahulu sebelum mengirim perintah dan '
          'setiap perubahan status akan langsung tercermin pada tampilan kontrol.',
    },
  ];

  static void showHelpSheet(BuildContext context) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in helpItems) {
      final sec = item['section'] as String;
      grouped.putIfAbsent(sec, () => []).add(item);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(color: Colors.transparent),
              ),
            ),
            DraggableScrollableSheet(
              initialChildSize: 0.60,
              minChildSize: 0.4,
              maxChildSize: 0.90,
              builder: (_, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: AppTheme.containerBg(context),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppTheme.textSecondary(
                              context,
                            ).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.help_outline_rounded,
                              color: AppTheme.primaryGreen,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Panduan Penggunaan Aplikasi',
                            style: AppTheme.display(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...grouped.entries.map(
                        (entry) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: AppTheme.primaryGreen.withOpacity(
                                      0.2,
                                    ),
                                    thickness: 1,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Text(
                                    entry.key.toUpperCase(),
                                    style: AppTheme.display(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryGreen,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: AppTheme.primaryGreen.withOpacity(
                                      0.2,
                                    ),
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ...entry.value.map(
                              (item) => _buildHelpItem(
                                context: context,
                                icon: item['icon'] as IconData,
                                color: item['color'] as Color,
                                title: item['title'] as String,
                                desc: item['desc'] as String,
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  static Widget _buildHelpItem({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondary(context),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
