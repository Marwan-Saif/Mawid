import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';

/// Horizontal list of days. Closed days are shown but disabled.
class DayStrip extends StatelessWidget {
  const DayStrip({super.key, required this.days, required this.selected, required this.isClosed, required this.onSelected});

  final List<DateTime> days;
  final DateTime? selected;
  final bool Function(DateTime) isClosed;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fmt = Fmt.of(context);
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpace.sm),
        itemBuilder: (context, i) {
          final d = days[i];
          final isSelected = d == selected;
          final closed = isClosed(d);
          final fg = isSelected ? c.onPrimary : (closed ? c.textSecondary : c.textPrimary);
          return Semantics(
            selected: isSelected,
            button: true,
            enabled: !closed,
            label: '${fmt.weekday(d)} ${fmt.dayNumber(d)}${closed ? ' · ${context.l10n.closedDay}' : ''}',
            excludeSemantics: true,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 64,
              decoration: BoxDecoration(
                color: isSelected ? c.primary : (closed ? c.taken : c.surface),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: isSelected ? c.primary : c.border, width: 1.5),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: closed ? null : () => onSelected(d),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(fmt.weekdayShort(d), style: text.labelSmall?.copyWith(color: fg)),
                      const SizedBox(height: 2),
                      Text(fmt.dayNumber(d), style: text.titleLarge?.copyWith(color: fg)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
