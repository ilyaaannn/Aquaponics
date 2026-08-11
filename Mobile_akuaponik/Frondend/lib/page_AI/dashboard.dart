import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import '../helper/app_theme.dart';
import '../helper/config.dart';
import '../helper/header.dart';
import '../helper/navbar.dart';
import '../helper/water_quality_reference.dart';
import '../model/model_ekosistem.dart';

class WaterQualityDashboard extends StatefulWidget {
  const WaterQualityDashboard({Key? key}) : super(key: key);

  @override
  State<WaterQualityDashboard> createState() => _WaterQualityDashboardState();
}

class _WaterQualityDashboardState extends State<WaterQualityDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Timer? _timer;

  Map<String, dynamic>? currentData;
  List<dynamic> historyData = [];
  bool isLoading = true;
  String errorMessage = '';
  bool isOnline = false;

  @override
  void initState() {
    super.initState();
    AppConfig.apiUrlNotifier.addListener(_onApiUrlChanged);
    activeEcosystem.addListener(_onExternalChange);
    activePresetIndex.addListener(_onExternalChange);

    _startPolling();
  }

  void _onApiUrlChanged() {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = '';
      currentData = null;
      historyData = [];
      isOnline = false;
    });
    _restartPolling();
  }

  void _onExternalChange() {
    if (mounted) setState(() {});
  }

  void _startPolling() {
    fetchData();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => fetchData());
  }

  void _restartPolling() {
    _timer?.cancel();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    AppConfig.apiUrlNotifier.removeListener(_onApiUrlChanged);
    activeEcosystem.removeListener(_onExternalChange);
    activePresetIndex.removeListener(_onExternalChange);
    super.dispose();
  }

  Future<void> fetchData() async {
    if (!AppConfig.isConfigured) {
      if (mounted) {
        setState(() {
          isLoading = false;
          isOnline = false;
          errorMessage =
              'Buka tab Setting dan masukkan IP server\n untuk koneksi ke perangkat';
        });
      }
      return;
    }

    try {
      final results = await Future.wait([
        http
            .get(Uri.parse('${AppConfig.apiUrl}/api/current'))
            .timeout(const Duration(seconds: 5)),
        http
            .get(Uri.parse('${AppConfig.apiUrl}/api/history'))
            .timeout(const Duration(seconds: 5)),
      ]);

      final currentResponse = results[0];
      final historyResponse = results[1];

      if (currentResponse.statusCode == 200 &&
          historyResponse.statusCode == 200) {
        if (mounted) {
          setState(() {
            currentData = json.decode(currentResponse.body);
            historyData = json.decode(historyResponse.body);
            isLoading = false;
            isOnline = true;
            errorMessage = '';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            errorMessage =
                'Server error (${currentResponse.statusCode}). Periksa backend.';
            isLoading = false;
            isOnline = false;
          });
        }
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          errorMessage =
              'server tidak merespons Silahkan Periksa IP: ${AppConfig.apiUrl}';
          isLoading = false;
          isOnline = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage =
              'Koneksi gagal.\nPastikan HP dan Raspberry Pi di jaringan yang sama.\n'
              'Server: ${AppConfig.apiUrl}';
          isLoading = false;
          isOnline = false;
        });
      }
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

  double get _effectivePH {
    return (currentData?['parameters']?['pH(ph_units)'] ?? 0.0).toDouble();
  }

  double get _effectiveTemp {
    return (currentData?['parameters']?['Temp(cel)'] ?? 0.0).toDouble();
  }

  double get _effectiveTDS {
    return (currentData?['parameters']?['TDS(ppm)'] ?? 0.0).toDouble();
  }

  double get _effectiveDO {
    return (currentData?['parameters']?['DO(mg/l)'] ?? 0.0).toDouble();
  }

  String get _effectiveStatus {
    return currentData?['status'] ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      key: _scaffoldKey,
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage.isNotEmpty
            ? _buildErrorState()
            : Column(
                children: [
                  Container(
                    color: AppTheme.scaffoldBg(context),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: _buildHeader(),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: fetchData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Column(
                          children: [
                            _buildRealtimeSensors(),
                            const SizedBox(height: 24),
                            if (historyData.isNotEmpty)
                              _buildWaterQualityStatus(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildErrorState() {
    final isNotConfigured = !AppConfig.isConfigured;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isNotConfigured ? Icons.settings_ethernet : Icons.cloud_off,
              size: 64,
              color: AppTheme.aquaBlueSoft,
            ),
            const SizedBox(height: 16),
            Text(
              isNotConfigured ? 'Server Belum Dikonfigurasi' : 'Koneksi Gagal',
              style: AppTheme.display(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (isNotConfigured)
              ElevatedButton.icon(
                onPressed: () {
                  MainNavigation.goToTab(3);
                },
                icon: const Icon(Icons.settings_rounded, color: Colors.white),
                label: Text(
                  'Buka Setting',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    isLoading = true;
                  });
                  fetchData();
                },
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: Text(
                  'Coba Lagi',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return CustomAppHeader(
      title: 'DASHBOARD AKUAPONIK',
      subtitle: isOnline
          ? (AppConfig.isConfigured ? AppConfig.currentIp : '—')
          : 'Offline',
      statusColor: isOnline ? AppTheme.secondaryGreen : Colors.redAccent,
      showStatus: true,
    );
  }

  Widget _buildRealtimeSensors() {
    final pH = _effectivePH;
    final temp = _effectiveTemp;
    final tds = _effectiveTDS;
    final doV = _effectiveDO;
    final status = _effectiveStatus;
    final statusColor = getStatusColor(status);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.containerBg(context),
          boxShadow: [AppTheme.cardShadow],
        ),
        child: Column(
          children: [
            AppTheme.currentLine(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.bolt,
                              color: AppTheme.primaryGreen,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Pemantauan Sensor & Prediksi',
                              style: AppTheme.display(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryGreen,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildEcosystemIndicator(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildSensorItem(
                        icon: Icons.water_drop,
                        label: 'pH',
                        value: pH.toStringAsFixed(1),
                        color: AppTheme.phColor,
                        param: 'pH',
                        rawValue: pH,
                      ),
                      _buildSensorItem(
                        icon: Icons.thermostat,
                        label: 'Temp',
                        value: '${temp.toStringAsFixed(1)}°C',
                        color: AppTheme.tempColor,
                        param: 'Temp',
                        rawValue: temp,
                      ),
                      _buildSensorItem(
                        icon: Icons.wb_sunny,
                        label: 'TDS',
                        value: '${tds.toStringAsFixed(0)}ppm',
                        color: AppTheme.tdsColor,
                        param: 'TDS',
                        rawValue: tds,
                      ),
                      _buildSensorItem(
                        icon: Icons.bubble_chart,
                        label: 'DO',
                        value: '${doV.toStringAsFixed(1)}mg/l',
                        color: AppTheme.doColor,
                        param: 'DO',
                        rawValue: doV,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSensorSolutionPanels(pH, temp, tds, doV),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPredictionCard(
                          status: status,
                          color: statusColor,
                        ),
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

  Widget _buildEcosystemIndicator() {
    final eco = activeEcosystem.value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.aquaBlueSoft.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.aquaBlueSoft.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            eco.name,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.aquaBlueSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionCard({required String status, required Color color}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: AppTheme.inkDeep,
        borderRadius: BorderRadius.circular(18),
        border: Border(left: BorderSide(color: color, width: 5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Text(
                'HASIL PREDIKSI STATUS',
                style: AppTheme.data(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.55),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            status.toUpperCase(),
            style: AppTheme.display(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorSolutionPanels(
    double pH,
    double temp,
    double tds,
    double doV,
  ) {
    const icons = {
      'pH': Icons.water_drop,
      'Temp': Icons.thermostat,
      'TDS': Icons.wb_sunny,
      'DO': Icons.bubble_chart,
    };

    final issues = WaterQualityReference.evaluateAll(
      ph: pH,
      temp: temp,
      tds: tds,
      doVal: doV,
    );

    if (issues.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(color: AppTheme.primaryGreen, width: 4),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: AppTheme.primaryGreen,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Semua parameter dalam rentang ideal — kondisi ekosistem akuaponik sangat baik.',
                style: AppTheme.body(
                  fontSize: 12,
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: issues.map((issue) {
        final icon = icons[issue.param] ?? Icons.info_outline;
        final isCritical = issue.isCritical;
        final borderColor = issue.color;
        final bgColor = borderColor.withOpacity(0.07);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: borderColor, width: 4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: borderColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: borderColor, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isCritical
                              ? Icons.warning_amber_rounded
                              : Icons.info_outline,
                          color: borderColor,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            isCritical
                                ? '${issue.label} — STATUS BAHAYA'
                                : '${issue.label} — STATUS NORMAL',
                            style: AppTheme.body(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: borderColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '💡 ${issue.solution}',
                      style: AppTheme.body(
                        fontSize: 11.5,
                        color: AppTheme.textPrimary(context),
                      ).copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSensorItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required String param,
    required double rawValue,
  }) {
    final isCritical = WaterQualityReference.isCriticalRealtime(
      param,
      rawValue,
    );
    final isOutOfRange = WaterQualityReference.isOutOfRange(param, rawValue);

    Color textColor;
    if (isCritical) {
      textColor = AppTheme.statusDanger;
    } else if (isOutOfRange) {
      textColor = WaterQualityReference.warningColor;
    } else {
      textColor = AppTheme.textPrimary(context);
    }

    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.35), width: 1.5),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppTheme.body(
            fontSize: 12,
            color: AppTheme.textSecondary(context),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTheme.data(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildWaterQualityStatus() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.containerBg(context),
          boxShadow: [AppTheme.cardShadow],
        ),
        child: Column(
          children: [
            AppTheme.currentLine(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.aquaBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.show_chart,
                              color: AppTheme.aquaBlue,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Grafik Parameter Akuaponik',
                              style: AppTheme.display(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.aquaBlue,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildTankLevelChart(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTankLevelChart() {
    return Column(
      children: [
        _buildParameterChart(
          'pH',
          'pH(ph_units)',
          AppTheme.phColor,
          Icons.water_drop,
        ),
        const SizedBox(height: 24),
        _buildParameterChart(
          'Temp',
          'Temp(cel)',
          AppTheme.tempColor,
          Icons.thermostat,
        ),
        const SizedBox(height: 24),
        _buildParameterChart(
          'TDS',
          'TDS(ppm)',
          AppTheme.tdsColor,
          Icons.wb_sunny,
        ),
        const SizedBox(height: 24),
        _buildParameterChart(
          'DO',
          'DO(mg/l)',
          AppTheme.doColor,
          Icons.bubble_chart,
        ),
      ],
    );
  }

  Widget _buildParameterChart(
    String title,
    String paramKey,
    Color color,
    IconData icon,
  ) {
    final spots = <FlSpot>[];
    final dataToShow = historyData.length > 25
        ? historyData.sublist(historyData.length - 25)
        : historyData;

    for (int i = 0; i < dataToShow.length; i++) {
      final params = dataToShow[i]['parameters'];
      if (params != null && params[paramKey] != null) {
        spots.add(FlSpot(i.toDouble(), (params[paramKey] as num).toDouble()));
      }
    }

    if (spots.isEmpty) return const SizedBox();

    double minY, maxY, interval;
    if (paramKey == 'pH(ph_units)') {
      minY = 0.0;
      maxY = 14.0;
      interval = 2.0;
    } else if (paramKey == 'Temp(cel)') {
      minY = 0.0;
      maxY = 42.0;
      interval = 7.0;
    } else if (paramKey == 'TDS(ppm)') {
      minY = 0.0;
      maxY = 1500.0;
      interval = 250.0;
    } else {
      minY = 0.0;
      maxY = 18.0;
      interval = 3.0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: AppTheme.display(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: interval,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Theme.of(context).dividerColor,
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: interval,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: AppTheme.textSecondary(context),
                      ),
                    ),
                  ),
                ),
                bottomTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (spot) => AppTheme.inkDeep,
                  getTooltipItems: (touchedSpots) => touchedSpots
                      .map(
                        (spot) => LineTooltipItem(
                          spot.y.toStringAsFixed(1),
                          AppTheme.data(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: color,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.3), color.withOpacity(0.0)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
