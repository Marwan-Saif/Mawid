import 'package:flutter/material.dart';

import '../../features/booking/domain/entities/booking.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Booking status as text + color (never color alone).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = context.l10n;
    final (String label, Color fg, Color bg) = switch (status) {
      BookingStatus.pending => (l10n.statusPending, c.warning, c.warningSoft),
      BookingStatus.confirmed => (l10n.statusConfirmed, c.textSecondary, c.taken),
      BookingStatus.arrived => (l10n.statusArrived, c.warning, c.warningSoft),
      BookingStatus.inProgress => (l10n.statusInProgress, c.onPrimary, c.primary),
      BookingStatus.completed => (l10n.statusCompleted, c.success, c.successSoft),
      BookingStatus.cancelled => (l10n.statusCancelled, c.danger, c.taken),
      BookingStatus.noShow => (l10n.statusNoShow, c.danger, c.taken),
    };
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpace.md, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}
