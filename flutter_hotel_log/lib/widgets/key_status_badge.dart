import 'package:flutter/material.dart';

enum KeyStatus { available, issued, returned, missing, longStay }

class KeyStatusBadge extends StatelessWidget {
  final KeyStatus status;
  final bool isDark;
  final int? count;

  const KeyStatusBadge({
    super.key,
    required this.status,
    required this.isDark,
    this.count,
  });

  String get _label => switch (status) {
        KeyStatus.available => 'Available',
        KeyStatus.issued => 'Issued',
        KeyStatus.returned => 'Returned',
        KeyStatus.missing => 'Missing',
        KeyStatus.longStay => 'Long-Stay',
      };

  Color get _color => switch (status) {
        KeyStatus.available => const Color(0xFF21A675),
        KeyStatus.issued => const Color(0xFF3B9AE1),
        KeyStatus.returned => const Color(0xFF21A675),
        KeyStatus.missing => const Color(0xFFE44855),
        KeyStatus.longStay => const Color(0xFFED8A24),
      };

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return AnimatedContainer(
      key: ValueKey('status-badge-${status.name}'),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.65)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.2 : 0.12),
            blurRadius: 8,
          ),
        ],
      ),
      child: Text(
        count == null ? _label : '$_label · $count',
        style: TextStyle(
          color: isDark ? Color.lerp(color, Colors.white, 0.28) : color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
