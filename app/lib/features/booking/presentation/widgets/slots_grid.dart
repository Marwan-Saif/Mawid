import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/time_slot.dart';

/// Three-column grid of times: available (green outline), booked (grey, struck through), selected (filled).
class SlotsGrid extends StatelessWidget {
  const SlotsGrid({super.key, required this.slots, required this.selected, required this.timezone, required this.onSelected});

  final List<TimeSlot> slots;
  final TimeSlot? selected;
  final String timezone;
  final ValueChanged<TimeSlot> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const spacing = AppSpace.sm;
      final columns = constraints.maxWidth > 520 ? 4 : 3;
      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final s in slots)
            SizedBox(width: width, child: SlotChip(slot: s, selected: s == selected, timezone: timezone, onTap: () => onSelected(s))),
        ],
      );
    });
  }
}

class SlotChip extends StatelessWidget {
  const SlotChip({super.key, required this.slot, required this.selected, required this.timezone, required this.onTap});

  final TimeSlot slot;
  final bool selected;
  final String timezone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = context.l10n;
    final label = Fmt.of(context).time(slot.startAt, timezone);
    final available = slot.available;
    final bg = selected ? c.success : (available ? c.surface : c.taken);
    final fg = selected ? c.surface : (available ? c.success : c.textSecondary);

    return Semantics(
      button: true,
      selected: selected,
      enabled: available,
      label: '$label, ${available ? l10n.available : l10n.booked}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: AppSpace.touch,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: available ? c.success : Colors.transparent, width: 1.5),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: available ? onTap : null,
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: fg,
                      decoration: available ? null : TextDecoration.lineThrough,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Legend: shape + text, not just color.
class SlotsLegend extends StatelessWidget {
  const SlotsLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme.bodyMedium;
    Widget dot(Color fill, Color border) => Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: border, width: 1.5),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot(c.surface, c.success),
        const SizedBox(width: AppSpace.xs),
        Text(l10n.available, style: text),
        const SizedBox(width: AppSpace.md),
        dot(c.taken, c.taken),
        const SizedBox(width: AppSpace.xs),
        Text(l10n.booked, style: text),
      ],
    );
  }
}
