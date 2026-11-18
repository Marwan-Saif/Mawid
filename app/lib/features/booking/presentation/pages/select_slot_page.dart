import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/state_views.dart';
import '../bloc/booking_bloc.dart';
import '../widgets/day_strip.dart';
import '../widgets/slots_grid.dart';
import '../widgets/staff_picker.dart';

class SelectSlotPage extends StatelessWidget {
  const SelectSlotPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocConsumer<BookingBloc, BookingState>(
      listenWhen: (a, b) => a.status != b.status,
      listener: (context, state) {
        if (state.status == Status.success && state.booking != null) {
          if (state.isRescheduling) {
            showMessage(context, l10n.rescheduled);
            context.pop(state.booking);
          } else {
            context.pushReplacement('/booking/confirmed', extra: state.booking);
          }
        } else if (state.status == Status.failure && state.failure != null && state.details != null) {
          showFailure(context, state.failure!);
        }
      },
      builder: (context, state) {
        if (state.details == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.chooseTime)),
            body: state.status == Status.failure && state.failure != null
                ? ErrorView(failure: state.failure!, onRetry: () => context.pop())
                : const Padding(padding: EdgeInsets.all(AppSpace.lg), child: SkeletonList()),
          );
        }
        return _Body(state: state);
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final BookingState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final fmt = Fmt.of(context);
    final text = Theme.of(context).textTheme;
    final bloc = context.read<BookingBloc>();
    final details = state.details!;
    final service = state.service!;
    final tz = details.place.timezone;
    final staff = details.staffFor(service.id);
    final available = state.slots.where((s) => s.available).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(state.isRescheduling ? l10n.reschedule : l10n.chooseTime, style: text.titleLarge),
            Text('${service.name(l10n.localeName)} · ${l10n.minutes(fmt.number(service.durationMin))}',
                style: text.bodyMedium),
          ],
        ),
        toolbarHeight: 72,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpace.xxl),
        children: [
          if (state.day != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.md),
              child: Text(fmt.monthYear(state.day!), style: text.titleMedium),
            ),
          DayStrip(
            days: state.days,
            selected: state.day,
            isClosed: state.isClosed,
            onSelected: (d) => bloc.add(DaySelected(d)),
          ),
          if (staff.length > 1) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xl, AppSpace.lg, AppSpace.sm),
              child: Text(l10n.withWhom, style: text.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
              child: StaffPicker(
                staff: staff,
                selectedId: state.staffId,
                onSelected: (id) => bloc.add(StaffSelected(id)),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xl, AppSpace.lg, AppSpace.md),
            child: Row(
              children: [
                Expanded(child: Text(l10n.availableTimes, style: text.titleMedium)),
                const SlotsLegend(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: state.slotsLoading
                  ? const SkeletonList(count: 3, height: 48)
                  : available == 0
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
                          child: Text(l10n.noSlots, style: text.bodyLarge, textAlign: TextAlign.center),
                        )
                      : SlotsGrid(
                          slots: state.slots,
                          selected: state.selectedSlot,
                          timezone: tz,
                          onSelected: (s) => bloc.add(SlotSelected(s)),
                        ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(AppSpace.lg),
          decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.yourAppointment, style: text.bodyMedium),
                    Text(
                      state.selectedSlot == null ? '—' : fmt.dateTime(state.selectedSlot!.startAt, tz),
                      style: text.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.md),
              SizedBox(
                width: 140,
                child: PrimaryButton(
                  label: l10n.confirm,
                  loading: state.status == Status.submitting,
                  onPressed: state.selectedSlot == null ? null : () => bloc.add(const BookingConfirmed()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
