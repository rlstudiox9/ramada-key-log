import 'dart:math' as math;

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

  static const _colors = [
    Color(0xFF8F2940),
    Color(0xFF9A6500),
    Color(0xFF23704F),
    Color(0xFF2C5F9E),
    Color(0xFF69438E),
    Color(0xFFA84B25),
    Color(0xFF14737B),
    Color(0xFF983D63),
    Color(0xFF596B2B),
    Color(0xFF465898),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalKeys = widget.metrics
        .fold<int>(0, (total, metric) => total + metric.keysIssued);
    final borderColor = theme.brightness == Brightness.light
        ? const Color(0xFFCBD5E1)
        : theme.dividerColor;
    final chartTrackColor = theme.brightness == Brightness.light
        ? const Color(0xFFCBD5E1)
        : theme.dividerColor;
    final hoveredMetrics =
        widget.metrics.where((metric) => metric.staffName == _hoveredStaff);
    final hoveredMetric = hoveredMetrics.isEmpty ? null : hoveredMetrics.first;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.donut_large_rounded,
                    color: theme.colorScheme.primary),
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
                            ? 'Issued key share • all recorded shifts'
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
            else if (totalKeys == 0)
              Text(
                'No key issuance data yet.',
                style: theme.textTheme.bodyMedium,
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final chartSize =
                      constraints.maxWidth < 300 ? constraints.maxWidth : 240.0;
                  final chart = SizedBox(
                    width: chartSize,
                    height: chartSize,
                    child: MouseRegion(
                      key: const ValueKey('staff-performance-donut'),
                      onHover: (event) {
                        final hovered = _metricAtPosition(
                          event.localPosition,
                          Size(chartSize, chartSize),
                        );
                        if (_hoveredStaff != hovered?.staffName) {
                          setState(() => _hoveredStaff = hovered?.staffName);
                        }
                      },
                      onExit: (_) => setState(() => _hoveredStaff = null),
                      child: Tooltip(
                        key: const ValueKey('staff-performance-tooltip'),
                        message: hoveredMetric == null
                            ? 'Hover a slice to view staff totals'
                            : '${hoveredMetric.staffName} • '
                                '${hoveredMetric.keysIssued} '
                                '${hoveredMetric.keysIssued == 1 ? 'key' : 'keys'} issued',
                        waitDuration: Duration.zero,
                        child: CustomPaint(
                          painter: _DonutPainter(
                            metrics: widget.metrics,
                            totalKeys: totalKeys,
                            hoveredStaff: _hoveredStaff,
                            colors: _colors,
                            trackColor: chartTrackColor,
                          ),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 140),
                              child: Column(
                                key: ValueKey(
                                  hoveredMetric?.staffName ?? 'total',
                                ),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    hoveredMetric == null
                                        ? '$totalKeys'
                                        : '${hoveredMetric.keysIssued}',
                                    style:
                                        theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: hoveredMetric == null
                                          ? theme.colorScheme.onSurface
                                          : _colorFor(hoveredMetric),
                                    ),
                                  ),
                                  Text(
                                    hoveredMetric == null
                                        ? 'keys issued'
                                        : 'keys',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                  final legend = Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      for (final metric in widget.metrics)
                        _StaffLegendItem(
                          metric: metric,
                          color: _colorFor(metric),
                          totalKeys: totalKeys,
                          hovered: _hoveredStaff == metric.staffName,
                          onHover: (hovered) {
                            setState(() {
                              _hoveredStaff = hovered ? metric.staffName : null;
                            });
                          },
                        ),
                    ],
                  );
                  if (constraints.maxWidth < 520) {
                    return Column(
                      children: [
                        chart,
                        const SizedBox(height: 12),
                        SizedBox(width: double.infinity, child: legend),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      chart,
                      const SizedBox(width: 20),
                      Expanded(child: legend),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Color _colorFor(StaffIssueMetric metric) {
    final index = widget.metrics.indexOf(metric);
    return _colors[index % _colors.length];
  }

  StaffIssueMetric? _metricAtPosition(Offset position, Size size) {
    final total = widget.metrics.fold<int>(
      0,
      (sum, metric) => sum + metric.keysIssued,
    );
    if (total == 0) return null;

    final center = Offset(size.width / 2, size.height / 2);
    final delta = position - center;
    final radius = size.shortestSide * 0.38;
    final distance = delta.distance;
    if (distance < radius * 0.57 || distance > radius * 1.28) return null;

    var angle = (math.atan2(delta.dy, delta.dx) + math.pi / 2) % (math.pi * 2);
    if (angle < 0) angle += math.pi * 2;
    var accumulatedAngle = 0.0;
    for (final metric in widget.metrics) {
      if (metric.keysIssued <= 0) continue;
      final sweep = metric.keysIssued / total * math.pi * 2;
      if (angle >= accumulatedAngle && angle < accumulatedAngle + sweep) {
        return metric;
      }
      accumulatedAngle += sweep;
    }
    return null;
  }
}

class _StaffLegendItem extends StatelessWidget {
  final StaffIssueMetric metric;
  final int totalKeys;
  final Color color;
  final bool hovered;
  final ValueChanged<bool> onHover;

  const _StaffLegendItem({
    required this.metric,
    required this.totalKeys,
    required this.color,
    required this.hovered,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final share = totalKeys == 0 ? 0 : metric.keysIssued / totalKeys * 100;
    return Tooltip(
      message: '${metric.staffName} • ${metric.keysIssued} '
          '${metric.keysIssued == 1 ? 'key' : 'keys'} issued',
      waitDuration: Duration.zero,
      child: MouseRegion(
        key: ValueKey(
          'staff-performance-legend:${metric.staffName.toLowerCase()}',
        ),
        onEnter: (_) => onHover(true),
        onExit: (_) => onHover(false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: hovered ? color.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  metric.staffName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: hovered ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${metric.keysIssued} (${share.toStringAsFixed(0)}%)',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: hovered ? color : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<StaffIssueMetric> metrics;
  final int totalKeys;
  final String? hoveredStaff;
  final List<Color> colors;
  final Color trackColor;

  const _DonutPainter({
    required this.metrics,
    required this.totalKeys,
    required this.hoveredStaff,
    required this.colors,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.38;
    final strokeWidth = size.shortestSide * 0.16;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (totalKeys == 0) return;
    var startAngle = -math.pi / 2;
    for (var index = 0; index < metrics.length; index++) {
      final metric = metrics[index];
      if (metric.keysIssued <= 0) continue;
      final sweepAngle = metric.keysIssued / totalKeys * math.pi * 2;
      final isHovered = metric.staffName == hoveredStaff;
      final paint = Paint()
        ..color = colors[index % colors.length].withValues(
          alpha: hoveredStaff == null || isHovered ? 1 : 0.68,
        )
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt
        ..strokeWidth = isHovered ? strokeWidth + 5 : strokeWidth;
      canvas.drawArc(
        rect,
        startAngle + 0.012,
        math.max(0, sweepAngle - 0.024),
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.metrics != metrics ||
      oldDelegate.totalKeys != totalKeys ||
      oldDelegate.hoveredStaff != hoveredStaff ||
      oldDelegate.trackColor != trackColor;
}
