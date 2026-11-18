import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../booking/domain/entities/booking.dart';

/// The big blue card on Home: what's next and when.
class NextAppointmentCard extends StatelessWidget {
  const NextAppointmentCard({super.key, required this.booking, required this.onDetails, required this.onReschedule});

  final Booking booking;
  final VoidCallback onDetails;
  final VoidCallback? onReschedule;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = context.l10n;
    final fmt = Fmt.of(context);
    final text = Theme.of(context).textTheme;
    final untilStart = booking.startAt.difference(DateTime.now().toUtc()).inMinutes;
    final minutes = untilStart < 0 ? 0 : untilStart;
    final onCard = c.onPrimary;

    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.lg),
        decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpace.md, vertical: 6),
                  decoration: BoxDecoration(
                    color: onCard.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(l10n.nextAppointment,
                      style: text.labelMedium?.copyWith(color: onCard, fontWeight: FontWeight.w700)),
                ),
                const Spacer(),
                Text(l10n.inTime(minutes), style: text.labelMedium?.copyWith(color: onCard)),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: Icon(Icons.event_note_outlined, color: c.primary),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${booking.serviceName(l10n.localeName)} — ${booking.staffName}',
                        style: text.titleMedium?.copyWith(color: onCard),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${booking.placeName(l10n.localeName)} · ${fmt.dateTime(booking.startAt, booking.placeTimezone)}',
                        style: text.bodyMedium?.copyWith(color: onCard.withValues(alpha: 0.9)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onDetails,
                    style: FilledButton.styleFrom(backgroundColor: c.surface, foregroundColor: c.primary),
                    child: Text(l10n.details),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReschedule,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: onCard,
                      side: BorderSide(color: onCard.withValues(alpha: 0.6), width: 1.5),
                    ),
                    child: Text(l10n.reschedule),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
