import 'dart:math' as math;

import 'package:flutter/material.dart';

class InventoryMetric {
  final String label;
  final int count;
  final Color color;

  const InventoryMetric({
    required this.label,
    required this.count,
    required this.color,
  });
}

class InventoryDistributionChart extends StatefulWidget {
  final List<InventoryMetric> metrics;
  final ValueChanged<String>? onMetricTap;

  const InventoryDistributionChart({
    super.key,
    required this.metrics,
    this.onMetricTap,
  });

  @override
  State<InventoryDistributionChart> createState() =>
      _InventoryDistributionChartState();
}

class _InventoryDistributionChartState
    extends State<InventoryDistributionChart> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.brightness == Brightness.light
        ? const Color(0xFF1F2937)
        : theme.colorScheme.onSurface;
    final hoveredMetric =
        _hoveredIndex == null ? null : widget.metrics[_hoveredIndex!];
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartSize = math.min(220.0, constraints.maxWidth);
        final chart = SizedBox(
          key: const ValueKey('inventory-distribution-donut'),
          width: chartSize,
          height: chartSize,
          child: GestureDetector(
            onTapDown: (details) {
              final index = _metricAtPosition(
                details.localPosition,
                Size(chartSize, chartSize),
              );
              if (index != null) {
                setState(() => _hoveredIndex = index);
                widget.onMetricTap?.call(widget.metrics[index].label);
              }
            },
            child: MouseRegion(
              onHover: (event) {
                final index = _metricAtPosition(
                  event.localPosition,
                  Size(chartSize, chartSize),
                );
                if (_hoveredIndex != index) {
                  setState(() => _hoveredIndex = index);
                }
              },
              onExit: (_) => setState(() => _hoveredIndex = null),
              child: Tooltip(
                key: const ValueKey('inventory-distribution-tooltip'),
                message: hoveredMetric == null
                    ? 'Hover over a segment to view its count'
                    : '${hoveredMetric.label} • ${hoveredMetric.count}',
                waitDuration: Duration.zero,
                child: CustomPaint(
                  painter: _InventoryDonutPainter(
                    metrics: widget.metrics,
                    hoveredIndex: _hoveredIndex,
                    trackColor: theme.dividerColor.withValues(alpha: 0.32),
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 140),
                      child: Column(
                        key: ValueKey(_hoveredIndex ?? 'overview'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            hoveredMetric == null
                                ? 'Key metrics'
                                : '${hoveredMetric.count}',
                            style: (hoveredMetric == null
                                    ? theme.textTheme.titleMedium
                                    : theme.textTheme.headlineSmall)
                                ?.copyWith(
                              color: textColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            hoveredMetric?.label ?? 'inventory & movement',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        final legend = LayoutBuilder(
          builder: (context, legendConstraints) {
            final itemWidth = legendConstraints.maxWidth >= 500
                ? (legendConstraints.maxWidth - 10) / 2
                : legendConstraints.maxWidth;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var index = 0; index < widget.metrics.length; index++)
                  SizedBox(
                    width: itemWidth,
                    child: _InventoryLegendItem(
                      metric: widget.metrics[index],
                      textColor: textColor,
                      isHovered: _hoveredIndex == index,
                      onHover: (hovered) {
                        setState(() => _hoveredIndex = hovered ? index : null);
                      },
                      onTap: () => widget.onMetricTap?.call(
                        widget.metrics[index].label,
                      ),
                    ),
                  ),
              ],
            );
          },
        );

        if (constraints.maxWidth >= 520) {
          return Row(
            children: [
              chart,
              const SizedBox(width: 24),
              Expanded(child: legend),
            ],
          );
        }
        return Column(
          children: [
            chart,
            const SizedBox(height: 16),
            legend,
          ],
        );
      },
    );
  }

  int? _metricAtPosition(Offset position, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final offset = position - center;
    final radius = offset.distance;
    if (radius < size.shortestSide * 0.27 ||
        radius > size.shortestSide * 0.48) {
      return null;
    }

    final total = widget.metrics.fold<int>(
      0,
      (sum, metric) => sum + math.max(metric.count, 0),
    );
    if (total == 0) return null;

    var angle = math.atan2(offset.dy, offset.dx) + math.pi / 2;
    if (angle < 0) angle += math.pi * 2;

    const gap = 0.035;
    var start = 0.0;
    for (var index = 0; index < widget.metrics.length; index++) {
      final count = math.max(widget.metrics[index].count, 0);
      if (count == 0) continue;
      final sweep = count / total * math.pi * 2;
      final visibleSweep = math.max(0.0, sweep - gap);
      final arcStart = start + gap / 2;
      if (angle >= arcStart && angle <= arcStart + visibleSweep) {
        return index;
      }
      start += sweep;
    }
    return null;
  }
}

class _InventoryLegendItem extends StatelessWidget {
  final InventoryMetric metric;
  final Color textColor;
  final bool isHovered;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;

  const _InventoryLegendItem({
    required this.metric,
    required this.textColor,
    required this.isHovered,
    required this.onHover,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: Semantics(
        key: ValueKey('inventory-metric-${metric.label}'),
        button: true,
        label: '${metric.label}: ${metric.count}',
        child: Material(
          color: isHovered
              ? metric.color.withValues(alpha: 0.12)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              constraints: const BoxConstraints(minWidth: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isHovered
                      ? metric.color.withValues(alpha: 0.7)
                      : theme.dividerColor.withValues(alpha: 0.55),
                ),
                boxShadow: isHovered
                    ? [
                        BoxShadow(
                          color: metric.color.withValues(alpha: 0.2),
                          blurRadius: 14,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: metric.color,
                      shape: BoxShape.circle,
                      boxShadow: isHovered
                          ? [
                              BoxShadow(
                                color: metric.color.withValues(alpha: 0.65),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      metric.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${metric.count}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InventoryDonutPainter extends CustomPainter {
  final List<InventoryMetric> metrics;
  final int? hoveredIndex;
  final Color trackColor;

  const _InventoryDonutPainter({
    required this.metrics,
    required this.hoveredIndex,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.37;
    const strokeWidth = 28.0;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final total = metrics.fold<int>(
      0,
      (sum, metric) => sum + math.max(metric.count, 0),
    );

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);
    if (total == 0) return;

    const gap = 0.035;
    var start = -math.pi / 2;
    for (var index = 0; index < metrics.length; index++) {
      final metric = metrics[index];
      final count = math.max(metric.count, 0);
      if (count == 0) continue;
      final sweep = count / total * math.pi * 2;
      final visibleSweep = math.max(0.0, sweep - gap);
      final arcStart = start + gap / 2;
      if (index == hoveredIndex) {
        final glowPaint = Paint()
          ..color = metric.color.withValues(alpha: 0.38)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 12
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
        canvas.drawArc(rect, arcStart, visibleSweep, false, glowPaint);
      }
      final segmentPaint = Paint()
        ..color = metric.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = index == hoveredIndex ? strokeWidth + 4 : strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, arcStart, visibleSweep, false, segmentPaint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _InventoryDonutPainter oldDelegate) =>
      oldDelegate.metrics != metrics ||
      oldDelegate.hoveredIndex != hoveredIndex ||
      oldDelegate.trackColor != trackColor;
}
