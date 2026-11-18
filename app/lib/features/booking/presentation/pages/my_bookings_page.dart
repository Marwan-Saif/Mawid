import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../places/presentation/cubit/home_cubit.dart';
import '../../domain/entities/booking.dart';
import '../cubit/my_bookings_cubit.dart';
import '../widgets/booking_details_sheet.dart';

class MyBookingsPage extends StatelessWidget {
  const MyBookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.myBookings),
          bottom: TabBar(tabs: [Tab(text: l10n.upcoming), Tab(text: l10n.past)]),
        ),
        body: BlocBuilder<MyBookingsCubit, MyBookingsState>(
          builder: (context, state) {
            final cubit = context.read<MyBookingsCubit>();
            if (state.status == LoadStatus.failure) return ErrorView(failure: state.failure!, onRetry: cubit.load);
            if (state.status == LoadStatus.loading && state.bookings.isEmpty) {
              return const Padding(padding: EdgeInsets.all(AppSpace.lg), child: SkeletonList());
            }
            final now = DateTime.now();
            return TabBarView(children: [
              _list(context, state.upcoming(now), cubit),
              _list(context, state.past(now), cubit),
            ]);
          },
        ),
      ),
    );
  }

  Widget _list(BuildContext context, List<Booking> items, MyBookingsCubit cubit) {
    final l10n = context.l10n;
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.event_busy_outlined,
        title: l10n.noBookings,
        subtitle: l10n.noBookingsHint,
        action: FilledButton(onPressed: () => context.go('/home'), child: Text(l10n.navHome)),
      );
    }
    return RefreshIndicator(
      onRefresh: cubit.load,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpace.lg),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpace.md),
        itemBuilder: (context, i) => _BookingCard(
          booking: items[i],
          onTap: () async {
            final changed = await showBookingDetails(context, items[i]);
            if (changed == true) cubit.load();
          },
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.onTap});

  final Booking booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final fmt = Fmt.of(context);
    final text = Theme.of(context).textTheme;
    final lang = l10n.localeName;
    final local = Fmt.inZone(booking.startAt, booking.placeTimezone);

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
            decoration: BoxDecoration(color: c.primarySoft, borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Column(children: [
              Text(fmt.weekdayShort(local), style: text.labelSmall?.copyWith(color: c.primary)),
              Text(fmt.dayNumber(local), style: text.titleLarge?.copyWith(color: c.primary)),
            ]),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(booking.serviceName(lang), style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${booking.placeName(lang)} · ${booking.staffName}', style: text.bodyMedium, maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(fmt.time(booking.startAt, booking.placeTimezone), style: text.bodyMedium),
              ],
            ),
          ),
          StatusChip(status: booking.status),
        ],
      ),
    );
  }
}
