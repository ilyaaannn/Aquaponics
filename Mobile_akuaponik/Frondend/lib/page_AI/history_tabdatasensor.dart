import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../helper/app_theme.dart';
import '../helper/config.dart';
import 'AI_history.dart';

class DataSensorTab extends StatelessWidget {
  final List<dynamic> sensorData;
  final int currentPage;
  final int itemsPerPage;
  final DateTime? selectedDate;
  final VoidCallback onNextPage;
  final VoidCallback onPreviousPage;

  const DataSensorTab({
    Key? key,
    required this.sensorData,
    required this.currentPage,
    required this.itemsPerPage,
    required this.selectedDate,
    required this.onNextPage,
    required this.onPreviousPage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (sensorData.isEmpty) {
      return HistoryEmptyState(
        icon: Icons.sensors_off_rounded,
        message: selectedDate == null
            ? 'Belum ada data sensor'
            : 'Tidak ada data pada tanggal ${DateFormat('dd/MM/yyyy').format(selectedDate!.toLocal())}',
        subtitle: selectedDate == null
            ? 'Data akan muncul setelah sensor terhubung'
            : 'Pilih tanggal lain untuk melihat data',
      );
    }

    final paginatedData = paginateList(sensorData, currentPage, itemsPerPage);
    final startIndex = currentPage * itemsPerPage + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.containerBg(context),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [AppTheme.rowShadow],
            border: Border.all(
              color: Theme.of(context).dividerColor,
              width: 0.8,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                headingRowHeight: 42,
                dataRowMinHeight: 50,
                dataRowMaxHeight: 64,
                headingRowColor: MaterialStateProperty.all(AppTheme.inkDeep),
                border: TableBorder(
                  horizontalInside: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 0.5,
                  ),
                ),
                columns: [
                  _sensorTableHeader('NO'),
                  _sensorTableHeader('WAKTU'),
                  _sensorTableHeader('pH'),
                  _sensorTableHeader('SUHU'),
                  _sensorTableHeader('TDS'),
                  _sensorTableHeader('DO'),
                  _sensorTableHeader('STATUS'),
                ],
                rows: List.generate(paginatedData.length, (index) {
                  final item = paginatedData[index];
                  final params = item['parameters'] ?? {};
                  final pH = params['pH(ph_units)'] ?? 0.0;
                  final temp = params['Temp(cel)'] ?? 0.0;
                  final TDS = params['TDS(ppm)'] ?? 0.0;
                  final DO = params['DO(mg/l)'] ?? 0.0;
                  final time = formatTime(item['timestamp']);
                  final status = item['status'] ?? 'Normal';
                  final statusColor = getStatusColor(status);

                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          '${startIndex + index}',
                          style: AppTheme.data(
                            fontSize: 12,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          time,
                          style: AppTheme.data(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          pH.toStringAsFixed(1),
                          style: AppTheme.data(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.phColor,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${temp.toStringAsFixed(1)}\u00b0C',
                          style: AppTheme.data(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.tempColor,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${TDS.toStringAsFixed(0)}ppm',
                          style: AppTheme.data(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.tdsColor,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${DO.toStringAsFixed(1)}mg/l',
                          style: AppTheme.data(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.doColor,
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: statusColor.withOpacity(0.5),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: AppTheme.data(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ).copyWith(letterSpacing: 0.4),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
        PaginationControls(
          totalItems: sensorData.length,
          currentPage: currentPage,
          itemsPerPage: itemsPerPage,
          itemName: 'data sensor',
          onPrevious: onPreviousPage,
          onNext: onNextPage,
        ),
      ],
    );
  }

  DataColumn _sensorTableHeader(String label) {
    return DataColumn(
      label: Text(
        label,
        style: AppTheme.data(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppTheme.aquaBlueSoft,
        ).copyWith(letterSpacing: 0.8),
      ),
    );
  }
}

Future<void> showDownloadOptionsDialog(BuildContext context) async {
  await showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Text(
          'Unduh Data Sensor',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary(context),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOptionItem(
                context: context,
                label: 'Hari Ini',
                onTap: () => _handleQuickDownload(context, ctx, days: 0),
              ),
              _buildDivider(context),
              _buildOptionItem(
                context: context,
                label: '3 Hari Terakhir',
                onTap: () => _handleQuickDownload(context, ctx, days: 3),
              ),
              _buildDivider(context),
              _buildOptionItem(
                context: context,
                label: '7 Hari Terakhir',
                onTap: () => _handleQuickDownload(context, ctx, days: 7),
              ),
              _buildDivider(context),
              _buildOptionItem(
                context: context,
                label: 'Semua Data',
                onTap: () => _handleQuickDownload(context, ctx, allData: true),
              ),
              _buildDivider(context),
              _buildOptionItem(
                context: context,
                label: 'Pilih Tanggal Kustom',
                icon: Icons.calendar_today_rounded,
                onTap: () => _handleCustomRangeDownload(context, ctx),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondary(context),
            ),
            child: Text(
              'Batal',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    },
  );
}

Widget _buildOptionItem({
  required BuildContext context,
  required String label,
  IconData? icon,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppTheme.primaryGreen),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary(context),
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppTheme.textSecondary(context).withOpacity(0.5),
          ),
        ],
      ),
    ),
  );
}

Widget _buildDivider(BuildContext context) {
  return Divider(
    height: 1,
    thickness: 1,
    color: Theme.of(context).dividerColor.withOpacity(0.3),
  );
}

void _handleQuickDownload(
  BuildContext context,
  BuildContext dialogCtx, {
  int? days,
  bool allData = false,
}) {
  Navigator.pop(dialogCtx);

  if (allData) {
    downloadSensorDataCSV(context);
    return;
  }

  final now = DateTime.now();
  final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
  final startDate = days == 0
      ? DateTime(now.year, now.month, now.day, 0, 0, 0)
      : DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: (days ?? 1) - 1));

  downloadSensorDataCSV(context, startDate: startDate, endDate: endDate);
}

Future<void> _handleCustomRangeDownload(
  BuildContext context,
  BuildContext dialogCtx,
) async {
  Navigator.pop(dialogCtx);

  final now = DateTime.now();
  final picked = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2020),
    lastDate: now,
    initialDateRange: DateTimeRange(
      start: now.subtract(const Duration(days: 7)),
      end: now,
    ),
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppTheme.primaryGreen,
            onPrimary: Colors.white,
            onSurface: AppTheme.textPrimary(context),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryGreen),
          ),
        ),
        child: child!,
      );
    },
  );

  if (picked == null) return;

  final startDate = DateTime(
    picked.start.year,
    picked.start.month,
    picked.start.day,
    0,
    0,
    0,
  );
  final endDate = DateTime(
    picked.end.year,
    picked.end.month,
    picked.end.day,
    23,
    59,
    59,
  );

  downloadSensorDataCSV(context, startDate: startDate, endDate: endDate);
}

Future<bool> _requestStoragePermission(BuildContext context) async {
  if (!Platform.isAndroid) return true;
  final androidInfo = await DeviceInfoPlugin().androidInfo;
  final sdkInt = androidInfo.version.sdkInt;
  if (sdkInt >= 30) {
    return true;
  }

  final status = await Permission.storage.status;
  if (status.isGranted) return true;
  if (status.isPermanentlyDenied) {
    _showPermissionDeniedDialog(context);
    return false;
  }

  final result = await Permission.storage.request();
  if (result.isGranted) return true;

  if (result.isPermanentlyDenied) {
    _showPermissionDeniedDialog(context);
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Izin penyimpanan ditolak. Aktifkan di Pengaturan Aplikasi.',
          style: GoogleFonts.inter(fontSize: 12),
        ),
        backgroundColor: AppTheme.paramTemp,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'Buka Pengaturan',
          textColor: Colors.white,
          onPressed: () => openAppSettings(),
        ),
      ),
    );
  }
  return false;
}

void _showPermissionDeniedDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      title: Text(
        'Izin Penyimpanan Diperlukan',
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary(context),
        ),
      ),
      content: Text(
        'Aplikasi memerlukan izin penyimpanan untuk menyimpan file CSV.',
        style: GoogleFonts.inter(
          fontSize: 13,
          color: AppTheme.textSecondary(context),
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.textSecondary(context),
          ),
          child: Text(
            'Batal',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            openAppSettings();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: Text(
            'Buka Pengaturan',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

Future<String?> _getDownloadPath(String filename) async {
  if (Platform.isAndroid) {
    final Directory? extDir = await getExternalStorageDirectory();
    if (extDir == null) return null;

    final List<String> pathSegments = extDir.path.split('/');
    final int androidIdx = pathSegments.indexOf('Android');
    String downloadPath;
    if (androidIdx != -1) {
      downloadPath =
          '${pathSegments.sublist(0, androidIdx).join('/')}/Download';
    } else {
      downloadPath = '/storage/emulated/0/Download';
    }

    final Directory downloadDir = Directory(downloadPath);
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return '$downloadPath/$filename';
  } else {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$filename';
  }
}

Future<void> downloadSensorDataCSV(
  BuildContext context, {
  DateTime? startDate,
  DateTime? endDate,
}) async {
  try {
    final bool hasPermission = await _requestStoragePermission(context);
    if (!hasPermission) return;

    final bool isRangeDownload = startDate != null && endDate != null;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isRangeDownload
                    ? 'Mengunduh data ${DateFormat('dd/MM/yy').format(startDate)} - ${DateFormat('dd/MM/yy').format(endDate)}...'
                    : 'Mengunduh seluruh data dari database...',
                style: GoogleFonts.inter(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    final queryParams = <String, String>{};
    if (startDate != null) {
      queryParams['start_date'] = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).format(startDate);
    }
    if (endDate != null) {
      queryParams['end_date'] = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).format(endDate);
    }

    final uri = Uri.parse(
      '${AppConfig.apiUrl}/api/sensor/export',
    ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

    final response = await http.get(uri).timeout(const Duration(seconds: 30));

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (response.statusCode == 200) {
      final rangeLabel = isRangeDownload
          ? ' - ${DateFormat('yyyyMMdd').format(startDate)}-${DateFormat('yyyyMMdd').format(endDate)}'
          : '';
      final filename = 'sensor_data${rangeLabel}.csv';
      final filePath = await _getDownloadPath(filename);

      if (filePath == null) {
        throw Exception('Gagal mengakses folder Download');
      }

      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      final lineCount = response.body.split('\n').length - 1;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '✓ $lineCount data berhasil diunduh',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '📁 Download/$filename',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } else {
      throw Exception('Server error: ${response.statusCode}');
    }
  } catch (e) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Gagal mengunduh: $e',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        backgroundColor: AppTheme.paramTemp,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
