import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/launch.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/booking.dart';

class BookingConfirmedPage extends StatelessWidget {
  const BookingConfirmedPage({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final fmt = Fmt.of(context);
    final text = Theme.of(context).textTheme;
    final lang = l10n.localeName;

    Widget row(String label, String value, {TextStyle? style}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 96, child: Text(label, style: text.bodyMedium)),
              Expanded(child: Text(value, style: style ?? text.titleMedium, textAlign: TextAlign.end)),
            ],
          ),
        );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/home');
      },
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.xl),
            children: [
              const SizedBox(height: AppSpace.xl),
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(color: c.successSoft, shape: BoxShape.circle),
                  child: Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(color: c.success, shape: BoxShape.circle),
                      child: Icon(Icons.check_rounded, color: c.surface, size: 36),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.xl),
              Text(l10n.bookingConfirmed, style: text.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: AppSpace.sm),
              Text(l10n.bookingConfirmedSub, style: text.bodyLarge?.copyWith(color: c.textSecondary), textAlign: TextAlign.center),
              const SizedBox(height: AppSpace.xl),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.xs),
                child: Column(
                  children: [
                    row(l10n.placeLabel, booking.placeName(lang)),
                    const Divider(),
                    row(l10n.serviceLabel, booking.serviceName(lang)),
                    const Divider(),
                    row(l10n.dateTimeLabel, fmt.dateTime(booking.startAt, booking.placeTimezone)),
                    const Divider(),
                    row(l10n.staffLabel, booking.staffName),
                    const Divider(),
                    row(l10n.paymentLabel, l10n.payAtPlace),
                    const Divider(),
                    row(l10n.total, fmt.money(booking.price, booking.currency),
                        style: text.titleMedium?.copyWith(color: c.primary)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => openDirections(booking.placeName(lang)),
                      icon: const Icon(Icons.place_outlined),
                      label: Text(l10n.directions),
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => openWhatsApp(null, '${booking.serviceName(lang)} · #${booking.id}'),
                      icon: const Icon(Icons.chat_outlined),
                      label: Text(l10n.whatsapp),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              FilledButton(onPressed: () => context.go('/home'), child: Text(l10n.backHome)),
            ],
          ),
        ),
      ),
    );
  }
}
