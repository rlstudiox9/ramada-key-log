import 'package:flutter/material.dart';

import '../models/key_issuance.dart';
import '../models/staff_roster_member.dart';

class StaffIssueMetric {
  final String staffName;
  final int keysIssued;

  const StaffIssueMetric({
    required this.staffName,
    required this.keysIssued,
  });
}

class StaffPerformanceChart extends StatefulWidget {
  final List<StaffIssueMetric> metrics;

  const StaffPerformanceChart({
    super.key,
    required this.metrics,
  });

  static List<StaffIssueMetric> calculateMetrics({
    required Iterable<KeyIssuanceItem> entries,
    required Iterable<StaffRosterMember> staffRoster,
  }) {
    final namesByKey = <String, String>{};
    final totals = <String, int>{};
    for (final staff in staffRoster) {
      final name = staff.name.trim();
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      namesByKey.putIfAbsent(key, () => name);
      totals.putIfAbsent(key, () => 0);
    }

    for (final entry in entries) {
      if (entry.isCarriedForward) continue;
      final name = entry.issuingStaff.trim();
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      namesByKey.putIfAbsent(key, () => name);
      totals.update(key, (total) => total + entry.qtyIssued,
          ifAbsent: () => entry.qtyIssued);
    }

    final metrics = [
      for (final entry in totals.entries)
        StaffIssueMetric(
          staffName: namesByKey[entry.key]!,
          keysIssued: entry.value,
        ),
    ];
    metrics.sort((a, b) {
      final countComparison = b.keysIssued.compareTo(a.keysIssued);
      return countComparison != 0
          ? countComparison
          : a.staffName.toLowerCase().compareTo(b.staffName.toLowerCase());
    });
    return metrics;
  }

  @override
  State<StaffPerformanceChart> createState() => _StaffPerformanceChartState();
}

class _StaffPerformanceChartState extends State<StaffPerformanceChart> {
  String? _hoveredStaff;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxKeys = widget.metrics.fold<int>(
      0,
      (maximum, metric) =>
          metric.keysIssued > maximum ? metric.keysIssued : maximum,
    );
    final hoveredMetrics =
        widget.metrics.where((metric) => metric.staffName == _hoveredStaff);
    final hoveredMetric = hoveredMetrics.isEmpty ? null : hoveredMetrics.first;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Staff performance',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        hoveredMetric == null
                            ? 'Total keys issued by staff • all recorded shifts'
                            : '${hoveredMetric.staffName} • '
                                '${hoveredMetric.keysIssued} keys issued',
                        key: const ValueKey('staff-performance-hover-metric'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.metrics.isEmpty)
              Text(
                'No key issuance data yet.',
                style: theme.textTheme.bodyMedium,
              )
            else
              for (final metric in widget.metrics)
                _StaffBarRow(
                  metric: metric,
                  maxKeys: maxKeys,
                  hovered: _hoveredStaff == metric.staffName,
                  onHover: (isHovered) {
                    setState(() {
                      _hoveredStaff = isHovered ? metric.staffName : null;
                    });
                  },
                ),
          ],
        ),
      ),
    );
  }
}

class _StaffBarRow extends StatelessWidget {
  final StaffIssueMetric metric;
  final int maxKeys;
  final bool hovered;
  final ValueChanged<bool> onHover;

  const _StaffBarRow({
    required this.metric,
    required this.maxKeys,
    required this.hovered,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barColor = theme.colorScheme.primary;
    final fraction =
        maxKeys == 0 ? 0.0 : metric.keysIssued / maxKeys.toDouble();
    return Tooltip(
      message: '${metric.staffName} • ${metric.keysIssued} '
          '${metric.keysIssued == 1 ? 'key' : 'keys'} issued',
      waitDuration: Duration.zero,
      child: MouseRegion(
        key: ValueKey(
          'staff-performance-row:${metric.staffName.toLowerCase()}',
        ),
        onEnter: (_) => onHover(true),
        onExit: (_) => onHover(false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          margin: const EdgeInsets.only(bottom: 1),
          decoration: BoxDecoration(
            color: hovered
                ? barColor.withValues(alpha: 0.09)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final nameWidth = (constraints.maxWidth * 0.34).clamp(72.0, 130.0);
              return Row(
                children: [
                  SizedBox(
                    width: nameWidth,
                    child: Text(
                      metric.staffName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            hovered ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Container(
                        height: 10,
                        color: theme.dividerColor.withValues(alpha: 0.45),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: fraction,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: hovered
                                  ? barColor
                                  : barColor.withValues(alpha: 0.76),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${metric.keysIssued}',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hovered ? barColor : null,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
