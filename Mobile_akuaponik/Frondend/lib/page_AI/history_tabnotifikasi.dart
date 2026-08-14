import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../helper/app_theme.dart';
import 'AI_history.dart';

class NotificationTab extends StatelessWidget {
  final List<dynamic> notifications;
  final int currentPage;
  final int itemsPerPage;
  final DateTime? selectedDate;
  final VoidCallback onNextPage;
  final VoidCallback onPreviousPage;

  const NotificationTab({
    Key? key,
    required this.notifications,
    required this.currentPage,
    required this.itemsPerPage,
    required this.selectedDate,
    required this.onNextPage,
    required this.onPreviousPage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) {
      return HistoryEmptyState(
        icon: Icons.notifications_off_rounded,
        message: selectedDate == null
            ? 'Tidak ada notifikasi peringatan'
            : 'Tidak ada notifikasi pada tanggal ${DateFormat('dd/MM/yyyy').format(selectedDate!.toLocal())}',
        subtitle: selectedDate == null
            ? 'Semua parameter dalam kondisi normal'
            : 'Pilih tanggal lain untuk melihat notifikasi',
      );
    }

    final paginatedData = paginateList(
      notifications,
      currentPage,
      itemsPerPage,
    );

    Map<String, List<dynamic>> groupedData = {};
    for (var item in paginatedData) {
      String date = formatDateTime(item['timestamp']);
      groupedData.putIfAbsent(date, () => []).add(item);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...groupedData.entries.map(
          (entry) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateHeaderNotif(context, entry.key, entry.value.length),
              ...entry.value.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _buildNotificationCard(context, item),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        PaginationControls(
          totalItems: notifications.length,
          currentPage: currentPage,
          itemsPerPage: itemsPerPage,
          itemName: 'notifikasi',
          onPrevious: onPreviousPage,
          onNext: onNextPage,
        ),
      ],
    );
  }

  Widget _buildDateHeaderNotif(
    BuildContext context,
    String dateKey,
    int total,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 4),
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.primaryGreen.withOpacity(0.3),
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              dateKey.toUpperCase(),
              style: AppTheme.body(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryGreen,
              ).copyWith(letterSpacing: 0.8),
            ),
          ),
          Text(
            '$total',
            style: AppTheme.data(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, dynamic item) {
    final status = item['status'] ?? 'Unknown';
    final statusColor = getStatusColor(status);
    final detailWarning = getDetailedWarning(item);
    final time = formatTime(item['timestamp']);
    final isBahaya = status.toLowerCase() == 'bahaya';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.containerBg(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [AppTheme.rowShadow],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5.5, color: statusColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isBahaya
                                    ? Icons.warning_amber_rounded
                                    : Icons.error_outline_rounded,
                                color: statusColor,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                status.toUpperCase(),
                                style: AppTheme.body(
                                  color: statusColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ).copyWith(letterSpacing: 0.6),
                              ),
                            ],
                          ),
                          if (time.isNotEmpty)
                            Text(
                              time,
                              style: AppTheme.data(
                                fontSize: 11.5,
                                color: AppTheme.textSecondary(
                                  context,
                                ).withOpacity(0.8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (detailWarning.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey.shade100,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            detailWarning,
                            style: AppTheme.data(
                              fontSize: 12,
                              color: AppTheme.textPrimary(context),
                              fontWeight: FontWeight.w600,
                            ).copyWith(height: 1.4),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
