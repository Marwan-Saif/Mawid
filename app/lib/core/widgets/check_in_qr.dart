import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../config/app_config.dart';
import '../../features/booking/domain/entities/booking.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/formatters.dart';

/// The customer's check-in QR. Reception scans it; opened on a phone it's the self check-in page.
class CheckInQr extends StatelessWidget {
  const CheckInQr({super.key, required this.booking, this.size = 168});

  final Booking booking;
  final double size;

  static String linkFor(String code) => '${AppConfig.publicUrl}/c/$code';

  @override
  Widget build(BuildContext context) {
    final code = booking.checkInCode;
    if (code == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final arrived = booking.ticketNo != null;
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          if (arrived)
            Text(l10n.yourTicket(Fmt.of(context).number(booking.ticketNo!)),
                style: text.titleMedium?.copyWith(color: c.success, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center)
          else ...[
            Semantics(
              label: l10n.showAtReception,
              image: true,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(AppSpace.sm),
                child: QrImageView(data: linkFor(code), size: size, backgroundColor: Colors.white, padding: EdgeInsets.zero),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            SelectableText(code, style: text.titleMedium?.copyWith(letterSpacing: 2), textDirection: TextDirection.ltr),
            Text(l10n.showAtReception, style: text.bodyMedium, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
