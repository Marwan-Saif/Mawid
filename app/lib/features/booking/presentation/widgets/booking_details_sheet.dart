import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/l10n/failure_messages.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/launch.dart';
import '../../../../core/widgets/check_in_qr.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/booking.dart';
import '../../domain/usecases/cancel_booking.dart';

/// Booking details with reschedule / cancel. Returns true when something changed.
Future<bool?> showBookingDetails(BuildContext context, Booking booking) => showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _BookingDetailsSheet(booking: booking),
    );

class _BookingDetailsSheet extends StatefulWidget {
  const _BookingDetailsSheet({required this.booking});

  final Booking booking;

  @override
  State<_BookingDetailsSheet> createState() => _BookingDetailsSheetState();
}

class _BookingDetailsSheetState extends State<_BookingDetailsSheet> {
  bool _busy = false;

  Future<void> _cancel() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cancelTitle),
        content: Text(l10n.cancelBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.keepIt)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: ctx.colors.danger),
            child: Text(l10n.yesCancel),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final result = await sl<CancelBooking>()(widget.booking);
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      (f) => showMessage(context, f.message(context.l10n)),
      (_) {
        showMessage(context, context.l10n.bookingCancelled);
        Navigator.pop(context, true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final l10n = context.l10n;
    final c = context.colors;
    final fmt = Fmt.of(context);
    final text = Theme.of(context).textTheme;
    final lang = l10n.localeName;
    final canChange = b.canChange(DateTime.now());

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, AppSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text(b.serviceName(lang), style: text.titleLarge)),
            StatusChip(status: b.status),
          ]),
          const SizedBox(height: AppSpace.xs),
          Text(b.placeName(lang), style: text.bodyLarge),
          const SizedBox(height: AppSpace.lg),
          _line(context, Icons.event_outlined, fmt.dateTime(b.startAt, b.placeTimezone)),
          _line(context, Icons.person_outline, b.staffName),
          _line(context, Icons.payments_outlined, fmt.money(b.price, b.currency)),
          if (b.status.isActive && b.checkInCode != null) ...[
            const SizedBox(height: AppSpace.lg),
            CheckInQr(booking: b),
          ],
          const SizedBox(height: AppSpace.lg),
          if (b.status.isActive && !canChange)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.md),
              child: Text(l10n.changeLocked, style: text.bodyMedium?.copyWith(color: c.warning)),
            ),
          if (b.status.isActive) ...[
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: !canChange || _busy
                      ? null
                      : () async {
                          final moved = await context.push<Booking>('/bookings/${b.id}/reschedule', extra: b);
                          if (moved != null && context.mounted) Navigator.pop(context, true);
                        },
                  child: Text(l10n.reschedule),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: OutlinedButton(
                  onPressed: !canChange || _busy ? null : _cancel,
                  style: OutlinedButton.styleFrom(foregroundColor: c.danger),
                  child: _busy
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(l10n.cancel),
                ),
              ),
            ]),
            const SizedBox(height: AppSpace.md),
          ],
          TextButton.icon(
            onPressed: () => openWhatsApp(null, '${b.serviceName(lang)} · #${b.id}'),
            icon: const Icon(Icons.chat_outlined),
            label: Text(l10n.whatsapp),
          ),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, IconData icon, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
        child: Row(children: [
          Icon(icon, size: 20, color: context.colors.textSecondary),
          const SizedBox(width: AppSpace.md),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyLarge)),
        ]),
      );
}
