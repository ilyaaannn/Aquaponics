import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../helper/app_theme.dart';
import '../helper/desktop_config.dart';
import '../page_AI/AI_history.dart'
    show paginateList, PaginationControls, HistoryEmptyState;
import '../model/model_desktop.dart';

class DesktopHistoryTab extends StatefulWidget {
  const DesktopHistoryTab({Key? key}) : super(key: key);

  @override
  State<DesktopHistoryTab> createState() => _DesktopHistoryTabState();
}

class _DesktopHistoryTabState extends State<DesktopHistoryTab> {
  List<dynamic> _logs = [];
  bool _isLoading = true;
  String _errorMessage = '';
  int _limit = 50;

  DateTime? _startDate;
  DateTime? _endDate;

  int _currentPage = 0;
  final int _itemsPerPage = 8;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _endDate = now;
    _startDate = now.subtract(const Duration(days: 1));
    DesktopConfig.apiUrlNotifier.addListener(_onConfigChanged);
    _loadLatest();
  }

  @override
  void dispose() {
    DesktopConfig.apiUrlNotifier.removeListener(_onConfigChanged);
    super.dispose();
  }

  void _onConfigChanged() {
    if (!mounted) return;
    setState(() {
      _logs = [];
      _isLoading = true;
      _errorMessage = '';
    });
    _loadLatest();
  }

  Future<void> _loadLatest() async {
    if (!DesktopConfig.isConfigured) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _currentPage = 0;
    });
    try {
      final uri = Uri.parse(
        '${DesktopConfig.apiUrl}/api/history',
      ).replace(queryParameters: {'limit': '$_limit'});
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      _handleResponse(response);
    } on TimeoutException {
      _handleError(
        'Server tidak merespons. Periksa IP: ${DesktopConfig.apiUrl}',
      );
    } catch (e) {
      _handleError('Gagal memuat data dari database desktop.');
    }
  }

  Future<void> _loadByDateRange() async {
    if (!DesktopConfig.isConfigured) return;
    if (_startDate == null || _endDate == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _currentPage = 0;
    });
    try {
      final uri = Uri.parse('${DesktopConfig.apiUrl}/api/history').replace(
        queryParameters: {
          'start_date':
              '${DateFormat('yyyy-MM-dd').format(_startDate!)} 00:00:00',
          'end_date': '${DateFormat('yyyy-MM-dd').format(_endDate!)} 23:59:59',
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      _handleResponse(response);
    } on TimeoutException {
      _handleError(
        'Server tidak merespons. Periksa IP: ${DesktopConfig.apiUrl}',
      );
    } catch (e) {
      _handleError('Gagal memuat data berdasarkan filter tanggal.');
    }
  }

  void _handleResponse(http.Response response) {
    if (!mounted) return;
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final List<dynamic> data = decoded['data'] ?? [];
      setState(() {
        _logs = data;
        _isLoading = false;
        _errorMessage = '';
      });
    } else {
      _handleError('Server error (${response.statusCode}).');
    }
  }

  void _handleError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _isLoading = false;
    });
  }

  void _nextPage() {
    if ((_currentPage + 1) * _itemsPerPage < _logs.length) {
      setState(() => _currentPage++);
    }
  }

  void _previousPage() {
    if (_currentPage > 0) setState(() => _currentPage--);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = (isStart ? _startDate : _endDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
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
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!DesktopConfig.isConfigured) {
      return HistoryEmptyState(
        icon: Icons.settings_ethernet_rounded,
        message: 'Server desktop belum terhubung',
        subtitle:
            'Hubungkan lewat ikon di pojok kanan atas untuk melihat riwayat.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLatest,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilterCard(),
            const SizedBox(height: 12),
            _buildInfoBar(),
            const SizedBox(height: 10),
            _buildTableCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.containerBg(context),
          boxShadow: [AppTheme.cardShadow],
        ),
        child: Column(
          children: [
            AppTheme.currentLine(),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateButton(
                          label: 'Dari Tanggal',
                          date: _startDate,
                          onTap: () => _pickDate(isStart: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDateButton(
                          label: 'Sampai Tanggal',
                          date: _endDate,
                          onTap: () => _pickDate(isStart: false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _loadByDateRange,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.aquaBlue,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 1,
                          ),
                          child: Text(
                            'Filter',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Jumlah:',
                        style: AppTheme.body(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      DropdownButton<int>(
                        value: _limit,
                        underline: const SizedBox(),
                        style: AppTheme.data(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary(context),
                        ),
                        items: const [25, 50, 100, 200]
                            .map(
                              (v) =>
                                  DropdownMenuItem(value: v, child: Text('$v')),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _limit = v);
                          _loadLatest();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateButton({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAF9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTheme.body(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary(context),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 12,
                  color: AppTheme.primaryGreen,
                ),
                const SizedBox(width: 6),
                Text(
                  date == null ? '—' : DateFormat('dd/MM/yyyy').format(date),
                  style: AppTheme.data(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.storage_rounded, size: 14, color: AppTheme.primaryGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Menampilkan ${_logs.length} data dari database desktop',
              style: AppTheme.body(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorMessage.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: HistoryEmptyState(
          icon: Icons.cloud_off_rounded,
          message: 'Gagal memuat data',
          subtitle: _errorMessage,
        ),
      );
    }
    if (_logs.isEmpty) {
      return const HistoryEmptyState(
        icon: Icons.inbox_rounded,
        message: 'Belum ada data log tersimpan',
        subtitle:
            'Data akan otomatis tersimpan saat perangkat desktop terhubung.',
      );
    }

    final paginated = paginateList(_logs, _currentPage, _itemsPerPage);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.containerBg(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [AppTheme.rowShadow],
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.8),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 18,
                headingRowHeight: 40,
                dataRowMinHeight: 46,
                dataRowMaxHeight: 54,
                headingRowColor: MaterialStateProperty.all(AppTheme.inkDeep),
                border: TableBorder(
                  horizontalInside: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 0.5,
                  ),
                ),
                columns: [
                  _header('WAKTU'),
                  for (final p in kDesktopParams) _header(p.shortLabel),
                ],
                rows: paginated.map<DataRow>((item) {
                  final log = item as Map<String, dynamic>;
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          _formatTimestamp(log['timestamp']),
                          style: AppTheme.data(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ),
                      for (final p in kDesktopParams)
                        DataCell(
                          Text(
                            p.format(numFromLog(log, p.jsonKey)),
                            style: AppTheme.data(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: p.color,
                            ),
                          ),
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          PaginationControls(
            totalItems: _logs.length,
            currentPage: _currentPage,
            itemsPerPage: _itemsPerPage,
            itemName: 'data',
            onPrevious: _previousPage,
            onNext: _nextPage,
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  DataColumn _header(String label) {
    return DataColumn(
      label: Text(
        label,
        style: AppTheme.data(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppTheme.aquaBlueSoft,
        ).copyWith(letterSpacing: 0.6),
      ),
    );
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '—';
    final parsed = DateTime.tryParse(ts.toString());
    if (parsed == null) return '—';
    return DateFormat('dd/MM/yy HH:mm:ss').format(parsed);
  }
}
