import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import '../helper/app_theme.dart';
import '../helper/config.dart';
import '../helper/header.dart';
import 'history_tabnotifikasi.dart';
import 'history_tabdatasensor.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<dynamic> historyData = [];
  List<dynamic> filteredNotifications = [];
  bool isLoading = true;
  String errorMessage = '';
  String selectedTab = 'Notifikasi';
  DateTime? lastSensorSave;

  // Pagination Global
  int currentPage = 0;
  final int itemsPerPage = 10;
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    fetchHistoryData();
    cleanOldNotifications();
  }

  // Hapus notifikasi lebih dari 7 hari
  Future<void> cleanOldNotifications() async {
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      await http.delete(
        Uri.parse('${AppConfig.apiUrl}/api/notifications/clean'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'before_date': sevenDaysAgo.toIso8601String()}),
      );
    } catch (e) {
      print('Error membersihkan notifikasi lama: $e');
    }
  }

  Future<void> fetchHistoryData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
      currentPage = 0;
    });
    try {
      final results = await Future.wait([
        http
            .get(Uri.parse('${AppConfig.apiUrl}/api/history'))
            .timeout(const Duration(seconds: 5)),
        http
            .get(Uri.parse('${AppConfig.apiUrl}/api/notifications'))
            .timeout(const Duration(seconds: 5)),
      ]);

      final historyResponse = results[0];
      final notifResponse = results[1];

      if (historyResponse.statusCode == 200) {
        List<dynamic> allData = json.decode(historyResponse.body);
        allData.sort((a, b) {
          final dateA = DateTime.parse(a['timestamp']);
          final dateB = DateTime.parse(b['timestamp']);
          return dateB.compareTo(dateA);
        });

        List<dynamic> notifData = [];
        if (notifResponse.statusCode == 200) {
          notifData = json.decode(notifResponse.body);
        }

        setState(() {
          historyData = allData;
          filteredNotifications = notifData;
          isLoading = false;
          errorMessage = '';
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load data';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Connection error';
        isLoading = false;
      });
    }
  }

  List<dynamic> getFilteredData(List<dynamic> data) {
    if (selectedDate == null) return data;
    return data.where((item) {
      final itemDate = DateTime.tryParse(item['timestamp'] ?? '');
      if (itemDate == null) return false;
      return itemDate.year == selectedDate!.year &&
          itemDate.month == selectedDate!.month &&
          itemDate.day == selectedDate!.day;
    }).toList();
  }

  List<dynamic> getFilteredSensorData() {
    return getFilteredData(historyData);
  }

  List<dynamic> getFilteredNotifications() {
    return getFilteredData(filteredNotifications);
  }

  void loadNextPage() {
    final currentData = selectedTab == 'Notifikasi'
        ? getFilteredNotifications()
        : getFilteredSensorData();
    if ((currentPage + 1) * itemsPerPage < currentData.length) {
      setState(() => currentPage++);
    }
  }

  void loadPreviousPage() {
    if (currentPage > 0) {
      setState(() => currentPage--);
    }
  }

  void resetPagination() {
    currentPage = 0;
  }

  void onDateSelected(DateTime? date) {
    setState(() {
      selectedDate = date;
      currentPage = 0;
    });
  }

  Widget _buildHeader() {
    return const CustomAppHeader(
      title: 'RIWAYAT & NOTIFIKASI',
      showStatus: false,
    );
  }

  Widget _buildGlobalDateFilter() {
    Future<void> _selectDate() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: selectedDate ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: AppTheme.primaryGreen,
                onPrimary: Colors.white,
                onSurface: AppTheme.textPrimary(context),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryGreen,
                ),
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null) onDateSelected(picked);
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      padding: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 14,
            color: AppTheme.textSecondary(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: _selectDate,
              child: Text(
                selectedDate == null
                    ? 'Semua tanggal'
                    : DateFormat('EEEE, dd MMMM yyyy').format(selectedDate!),
                style: AppTheme.data(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary(context),
                ),
              ),
            ),
          ),
          if (selectedDate != null)
            GestureDetector(
              onTap: () => onDateSelected(null),
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: AppTheme.textSecondary(context),
                ),
              ),
            ),
          GestureDetector(
            onTap: _selectDate,
            child: Text(
              selectedDate == null ? 'PILIH' : 'UBAH',
              style: AppTheme.body(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryGreen,
              ).copyWith(letterSpacing: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: _buildHeader(),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: _buildTabButton(
                      'Notifikasi',
                      Icons.notifications_rounded,
                      getFilteredNotifications().length,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTabButton(
                      'Data Sensor',
                      Icons.sensors_rounded,
                      getFilteredSensorData().length,
                    ),
                  ),
                ],
              ),
            ),
            _buildGlobalDateFilter(),
            Expanded(
              child: Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: fetchHistoryData,
                    color: AppTheme.primaryGreen,
                    backgroundColor: AppTheme.containerBg(context),
                    child: isLoading
                        ? _buildLoadingState()
                        : errorMessage.isNotEmpty
                        ? _buildErrorState()
                        : SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 88),
                            child: selectedTab == 'Notifikasi'
                                ? NotificationTab(
                                    notifications: getFilteredNotifications(),
                                    currentPage: currentPage,
                                    itemsPerPage: itemsPerPage,
                                    selectedDate: selectedDate,
                                    onNextPage: loadNextPage,
                                    onPreviousPage: loadPreviousPage,
                                  )
                                : DataSensorTab(
                                    sensorData: getFilteredSensorData(),
                                    currentPage: currentPage,
                                    itemsPerPage: itemsPerPage,
                                    selectedDate: selectedDate,
                                    onNextPage: loadNextPage,
                                    onPreviousPage: loadPreviousPage,
                                  ),
                          ),
                  ),
                  if (selectedTab == 'Data Sensor' &&
                      !isLoading &&
                      errorMessage.isEmpty)
                    Positioned(
                      bottom: 16,
                      right: 20,
                      child: FloatingActionButton.extended(
                        onPressed: () => showDownloadOptionsDialog(context),
                        backgroundColor: AppTheme.inkDeep,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 17),
                        label: Text(
                          'CSV',
                          style: AppTheme.data(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ).copyWith(letterSpacing: 0.4),
                        ),
                        tooltip: 'Unduh CSV ke Download',
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AppTheme.primaryGreen,
            strokeWidth: 2.5,
          ),
          const SizedBox(height: 16),
          Text(
            'MEMUAT DATA',
            style: AppTheme.data(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary(context),
            ).copyWith(letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: AppTheme.paramTemp.withOpacity(0.7),
            ),
            const SizedBox(height: 18),
            Text(
              'Koneksi Gagal',
              style: AppTheme.display(
                fontSize: 17,
                color: AppTheme.textPrimary(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: AppTheme.body(
                fontSize: 13,
                color: AppTheme.textSecondary(context),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: fetchHistoryData,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: Text(
                'Coba Lagi',
                style: AppTheme.body(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, IconData icon, int count) {
    final isSelected = selectedTab == title;
    final accentColor = title == 'Notifikasi'
        ? AppTheme.primaryGreen
        : AppTheme.aquaBlue;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          selectedTab = title;
          currentPage = 0;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accentColor : Colors.grey.withOpacity(0.2),
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? accentColor : AppTheme.textSecondary(context),
            ),
            const SizedBox(width: 7),
            Text(
              title,
              style: AppTheme.body(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppTheme.textPrimary(context)
                    : AppTheme.textSecondary(context),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: AppTheme.data(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? accentColor
                    : AppTheme.textSecondary(context).withOpacity(0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HELPER & WIDGET BERSAMA
// Dipakai oleh history_tabnotifikasi.dart & history_tabdatasensor.dart
// ============================================================

String formatDateTime(String? timestamp) {
  if (timestamp == null) return 'N/A';
  try {
    final dateTime = DateTime.parse(timestamp);
    final days = [
      'Minggu',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
    ];
    final months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${days[dateTime.weekday % 7]}, ${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
  } catch (e) {
    return 'N/A';
  }
}

String formatTime(String? timestamp) {
  if (timestamp == null) return '';
  try {
    final dateTime = DateTime.parse(timestamp);
    return DateFormat('HH:mm').format(dateTime);
  } catch (e) {
    return '';
  }
}

Color getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'ideal':
      return AppTheme.statusIdeal;
    case 'normal':
      return AppTheme.statusNormal;
    case 'bahaya':
      return AppTheme.statusDanger;
    default:
      return Colors.grey;
  }
}

String getDetailedWarning(dynamic item) {
  final status = item['status'] ?? '';
  if (status.toLowerCase() != 'bahaya') {
    return '';
  }
  if (item['parameters'] == null) {
    return 'Beberapa parameter di luar batas normal';
  }

  final params = item['parameters'] as Map<String, dynamic>;
  final pH = params['pH(ph_units)'] ?? 0.0;
  final temp = params['Temp(cel)'] ?? 0.0;
  final TDS = params['TDS(ppm)'] ?? 0.0;
  final DO = params['DO(mg/l)'] ?? 0.0;

  List<String> warnings = [];

  if (pH < 5.5 || pH > 8.5) {
    warnings.add('pH tidak normal (${pH.toStringAsFixed(1)})');
  }
  if (temp < 20.0 || temp > 34.0) {
    warnings.add('Suhu ekstrem (${temp.toStringAsFixed(1)}°C)');
  }
  if (TDS > 1300) {
    warnings.add('TDS tinggi (${TDS.toStringAsFixed(0)}ppm)');
  }
  if (DO < 3) {
    warnings.add('Oksigen rendah (${DO.toStringAsFixed(1)}mg/l)');
  }
  return warnings.isNotEmpty
      ? warnings.join(' • ')
      : 'Beberapa parameter di luar batas normal';
}

/// Ambil satu halaman data dari [data] berdasarkan [currentPage] & [itemsPerPage].
List<dynamic> paginateList(
  List<dynamic> data,
  int currentPage,
  int itemsPerPage,
) {
  final start = currentPage * itemsPerPage;
  final end = start + itemsPerPage;
  if (start >= data.length) return [];
  return data.sublist(start, end > data.length ? data.length : end);
}

/// Kontrol pagination (Prev / Next) yang dipakai bersama oleh kedua tab.
class PaginationControls extends StatelessWidget {
  final int totalItems;
  final int currentPage;
  final int itemsPerPage;
  final String itemName;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const PaginationControls({
    Key? key,
    required this.totalItems,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPrevious,
    required this.onNext,
    this.itemName = 'data',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final totalPages = (totalItems / itemsPerPage).ceil();
    final startIndex = currentPage * itemsPerPage + 1;
    final endIndex = (currentPage * itemsPerPage + itemsPerPage).clamp(
      0,
      totalItems,
    );

    if (totalPages <= 1) return const SizedBox.shrink();

    final hasPrevious = currentPage > 0;
    final hasNext = (currentPage + 1) * itemsPerPage < totalItems;

    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$startIndex\u2013$endIndex dari $totalItems $itemName',
            style: AppTheme.data(
              fontSize: 11,
              color: AppTheme.textSecondary(context),
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: hasPrevious ? onPrevious : null,
                icon: Icon(
                  Icons.chevron_left_rounded,
                  size: 22,
                  color: hasPrevious
                      ? AppTheme.textPrimary(context)
                      : AppTheme.textSecondary(context).withOpacity(0.35),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 18,
              ),
              const SizedBox(width: 4),
              Text(
                '${currentPage + 1} / $totalPages',
                style: AppTheme.data(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: hasNext ? onNext : null,
                icon: Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: hasNext
                      ? AppTheme.textPrimary(context)
                      : AppTheme.textSecondary(context).withOpacity(0.35),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 18,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// State kosong (data tidak ditemukan) yang dipakai bersama oleh kedua tab.
class HistoryEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subtitle;

  const HistoryEmptyState({
    Key? key,
    required this.icon,
    required this.message,
    this.subtitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 38,
              color: AppTheme.textSecondary(context).withOpacity(0.35),
            ),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTheme.body(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary(context),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: AppTheme.body(
                  fontSize: 12.5,
                  color: AppTheme.textSecondary(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
