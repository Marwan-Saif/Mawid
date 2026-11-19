import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/launch.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../booking/domain/entities/booking.dart';
import '../../../places/presentation/cubit/home_cubit.dart';
import '../cubit/owner_dashboard_cubit.dart';
import '../widgets/manual_booking_sheet.dart';

class OwnerDashboardPage extends StatelessWidget {
  const OwnerDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocConsumer<OwnerDashboardCubit, OwnerDashboardState>(
      listenWhen: (a, b) => b.alert != null && a.alert != b.alert,
      listener: (context, state) =>
          showMessage(context, l10n.newBookingFrom(state.alert!.customerName ?? state.alert!.customerPhone ?? '')),
      builder: (context, state) {
        final cubit = context.read<OwnerDashboardCubit>();
        if (state.status == LoadStatus.failure && state.place == null) {
          return Scaffold(body: ErrorView(failure: state.failure!, onRetry: cubit.load));
        }
        return Scaffold(
          body: RefreshIndicator(
            onRefresh: cubit.load,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _Header(state: state)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xl, AppSpace.lg, AppSpace.sm),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Expanded(child: Text(l10n.schedule, style: Theme.of(context).textTheme.titleMedium)),
                        FilledButton.tonalIcon(
                          onPressed: state.place == null
                              ? null
                              : () async {
                                  final added = await showManualBookingSheet(context, state.place!, state.day);
                                  if (added == true) cubit.load();
                                },
                          icon: const Icon(Icons.add),
                          label: Text(l10n.manualBooking),
                        ),
                      ],
                    ),
                  ),
                ),
                if (state.status == LoadStatus.loading && state.bookings.isEmpty)
                  const SliverPadding(
                    padding: EdgeInsets.all(AppSpace.lg),
                    sliver: SliverToBoxAdapter(child: SkeletonList()),
                  )
                else if (state.bookings.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(icon: Icons.event_available_outlined, title: l10n.emptyDay),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.xxl),
                    sliver: SliverList.separated(
                      itemCount: state.bookings.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpace.md),
                      itemBuilder: (context, i) => _ScheduleRow(
                        booking: state.bookings[i],
                        busy: state.updatingId == state.bookings[i].id,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final OwnerDashboardState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final fmt = Fmt.of(context);
    final text = Theme.of(context).textTheme;
    final cubit = context.read<OwnerDashboardCubit>();
    final place = state.place?.place;
    final headerBg = Color.alphaBlend(Colors.black.withValues(alpha: 0.35), c.primary);
    const onHeader = Colors.white;
    final now = DateTime.now().toUtc();
    final isToday = place != null && state.day != null && _sameDay(state.day!, Fmt.inZone(now, place.timezone));

    // Bottom padding leaves room for the stat cards that overlap the header edge.
    return Padding(
      padding: const EdgeInsets.only(bottom: 48),
      child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          color: headerBg,
          padding: EdgeInsets.fromLTRB(
              AppSpace.lg, MediaQuery.paddingOf(context).top + AppSpace.lg, AppSpace.lg, 72),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.dashboardOf(place?.name(l10n.localeName) ?? ''),
                  style: text.bodyMedium?.copyWith(color: onHeader.withValues(alpha: 0.85))),
              const SizedBox(height: AppSpace.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isToday ? l10n.todaysAppointments : (state.day == null ? '' : fmt.weekday(state.day!)),
                      style: text.headlineSmall?.copyWith(color: onHeader),
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).previousPageTooltip,
                    onPressed: () => cubit.shiftDay(-1),
                    icon: const Icon(Icons.chevron_left, color: onHeader),
                  ),
                  if (state.day != null)
                    Text(fmt.dayNumber(state.day!), style: text.titleMedium?.copyWith(color: onHeader)),
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).nextPageTooltip,
                    onPressed: () => cubit.shiftDay(1),
                    icon: const Icon(Icons.chevron_right, color: onHeader),
                  ),
                ],
              ),
            ],
          ),
        ),
        PositionedDirectional(
          start: AppSpace.lg,
          end: AppSpace.lg,
          bottom: -44,
          child: Row(
            children: [
              _Stat(value: fmt.number(state.total), label: l10n.bookingsCount, color: c.primary),
              const SizedBox(width: AppSpace.sm),
              _Stat(value: fmt.number(state.completed), label: l10n.completedCount, color: c.success),
              const SizedBox(width: AppSpace.sm),
              _Stat(value: fmt.number(state.newSince(now)), label: l10n.newCount, color: c.warning),
            ],
          ),
        ),
      ],
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.color});

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
        child: Column(
          children: [
            Text(value, style: text.headlineSmall?.copyWith(color: color)),
            Text(label, style: text.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.booking, required this.busy});

  final Booking booking;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = Fmt.of(context);
    final text = Theme.of(context).textTheme;
    final lang = l10n.localeName;
    final faded = booking.status == BookingStatus.cancelled || booking.status == BookingStatus.noShow;

    return Opacity(
      opacity: faded ? 0.6 : 1,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpace.lg),
              child: Text(fmt.time(booking.startAt, booking.placeTimezone), style: text.labelMedium),
            ),
          ),
          Expanded(
            child: AppCard(
              onTap: () => _actions(context),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(booking.customerName ?? booking.customerPhone ?? '—', style: text.titleMedium),
                        Text('${booking.serviceName(lang)} · ${booking.staffName}', style: text.bodyMedium),
                      ],
                    ),
                  ),
                  busy
                      ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : StatusChip(status: booking.status),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _actions(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<OwnerDashboardCubit>();
    final options = <(BookingStatus, String, IconData)>[
      if (booking.status == BookingStatus.pending) (BookingStatus.confirmed, l10n.confirmBooking, Icons.check),
      if (booking.status == BookingStatus.pending || booking.status == BookingStatus.confirmed)
        (BookingStatus.inProgress, l10n.markInProgress, Icons.play_arrow_outlined),
      if (booking.status.isActive) (BookingStatus.completed, l10n.markCompleted, Icons.done_all),
      if (booking.status.isActive) (BookingStatus.noShow, l10n.markNoShow, Icons.person_off_outlined),
      if (booking.status.isActive) (BookingStatus.cancelled, l10n.cancel, Icons.close),
    ];
    final picked = await showModalBottomSheet<Object>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(booking.customerName ?? '', style: Theme.of(ctx).textTheme.titleMedium),
              subtitle: Text(l10n.changeStatus),
            ),
            for (final (status, label, icon) in options)
              ListTile(leading: Icon(icon), title: Text(label), onTap: () => Navigator.pop(ctx, status)),
            if (booking.customerPhone != null) ...[
              ListTile(
                leading: const Icon(Icons.call_outlined),
                title: Text(booking.customerPhone!, textDirection: TextDirection.ltr),
                onTap: () => Navigator.pop(ctx, 'call'),
              ),
              ListTile(
                leading: const Icon(Icons.chat_outlined),
                title: Text(l10n.whatsapp),
                onTap: () => Navigator.pop(ctx, 'whatsapp'),
              ),
            ],
          ],
        ),
      ),
    );
    if (picked is BookingStatus) {
      final failure = await cubit.setStatus(booking, picked);
      if (failure != null && context.mounted) showFailure(context, failure);
    } else if (picked == 'call') {
      await callPhone(booking.customerPhone!);
    } else if (picked == 'whatsapp' && context.mounted) {
      final fmt = Fmt.of(context);
      await openWhatsApp(
        booking.customerPhone,
        '${booking.placeName(l10n.localeName)}: ${booking.serviceName(l10n.localeName)} · '
        '${fmt.dateTime(booking.startAt, booking.placeTimezone)}',
      );
    }
  }
}
