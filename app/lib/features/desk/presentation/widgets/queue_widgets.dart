import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../booking/domain/entities/booking.dart';
import '../../domain/entities/desk_board.dart';
import '../../domain/entities/invoice.dart';
import '../cubit/desk_cubit.dart';
import '../l10n/desk_strings.dart';

/// Offline / not-sent-yet strip at the top of the desk.
class SyncBanner extends StatelessWidget {
  const SyncBanner({super.key, required this.state});

  final DeskState state;

  @override
  Widget build(BuildContext context) {
    final d = context.desk;
    final c = context.colors;
    final board = state.board;
    final offline = !state.sync.online || (board?.isOffline ?? false);
    final rejected = state.sync.rejected;
    if (!offline && state.sync.pending == 0 && rejected.isEmpty) return const SizedBox.shrink();
    final fmt = Fmt.of(context);
    final since = board?.offlineSince;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: offline ? c.warningSoft : c.primarySoft,
        padding: const EdgeInsetsDirectional.fromSTEB(AppSpace.lg, AppSpace.md, AppSpace.sm, AppSpace.md),
        child: Row(
          children: [
            Icon(offline ? Icons.wifi_off_rounded : Icons.cloud_sync_outlined, color: offline ? c.warning : c.primary),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (offline || state.sync.pending > 0)
                    Text(d.offline(state.sync.pending), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600)),
                  if (offline && since != null && board != null)
                    Text(d.lastUpdate(fmt.time(since, board.place.timezone)),
                        style: TextStyle(color: c.textSecondary, fontSize: 13)),
                  if (rejected.isNotEmpty) Text(d.rejected(rejected.length), style: TextStyle(color: c.danger, fontSize: 13)),
                ],
              ),
            ),
            if (state.simulatingOffline)
              TextButton(
                onPressed: () => context.read<DeskCubit>().toggleSimulatedOffline(),
                child: Text(d.endSimulation),
              ),
          ],
        ),
      ),
    );
  }
}

class CountsRow extends StatelessWidget {
  const CountsRow({super.key, required this.counts});

  final DeskCounts counts;

  @override
  Widget build(BuildContext context) {
    final d = context.desk;
    final fmt = Fmt.of(context);
    Widget tile(String label, int n, IconData icon) => Expanded(
          child: AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.md, horizontal: AppSpace.sm),
            child: Column(
              children: [
                Icon(icon, size: 20, color: context.colors.primary),
                const SizedBox(height: AppSpace.xs),
                Text(fmt.number(n), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                Text(label, style: Theme.of(context).textTheme.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        );
    return Row(
      children: [
        tile(d.countBooked, counts.booked, Icons.event_outlined),
        const SizedBox(width: AppSpace.sm),
        tile(d.countWaiting, counts.waiting, Icons.event_seat_outlined),
        const SizedBox(width: AppSpace.sm),
        tile(d.countInRoom, counts.inRoom, Icons.meeting_room_outlined),
        const SizedBox(width: AppSpace.sm),
        tile(d.countDone, counts.done, Icons.task_alt),
      ],
    );
  }
}

/// Text + color + icon, never color alone.
class PresenceChip extends StatelessWidget {
  const PresenceChip({super.key, required this.presence});

  final StaffPresence presence;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color fg, Color bg, IconData icon) = switch (presence) {
      StaffPresence.available => (c.success, c.successSoft, Icons.check_circle_outline),
      StaffPresence.busy => (c.warning, c.warningSoft, Icons.person_outline),
      StaffPresence.onBreak => (c.warning, c.warningSoft, Icons.coffee_outlined),
      StaffPresence.away => (c.textSecondary, c.taken, Icons.do_not_disturb_on_outlined),
    };
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpace.md, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: fg),
        const SizedBox(width: 6),
        Text(context.desk.presence(presence),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class StaffCard extends StatelessWidget {
  const StaffCard({super.key, required this.staff, required this.board, required this.busy});

  final DeskStaff staff;
  final DeskBoard board;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final d = context.desk;
    final text = Theme.of(context).textTheme;
    final lang = context.l10n.localeName;
    final current = board.queue.where((q) => q.id == staff.currentBookingId).firstOrNull;
    final fmt = Fmt.of(context);
    return SizedBox(
      width: 220,
      child: AppCard(
        onTap: busy ? null : () => showPresenceSheet(context, staff),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(staff.name, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(staff.room ?? staff.title(lang), style: text.bodySmall, maxLines: 1),
            const SizedBox(height: AppSpace.sm),
            Row(children: [
              PresenceChip(presence: staff.presence),
              if (busy) ...[
                const SizedBox(width: AppSpace.sm),
                const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ]),
            const SizedBox(height: AppSpace.sm),
            Text(
              current?.booking.ticketNo != null
                  ? d.nowServing(fmt.number(current!.booking.ticketNo!))
                  : d.waitingFor(fmt.number(staff.waiting)),
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showPresenceSheet(BuildContext context, DeskStaff staff) {
  final cubit = context.read<DeskCubit>();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) {
      final d = sheet.desk;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.sm),
              child: Text('${staff.name} · ${d.changePresence}', style: Theme.of(sheet).textTheme.titleMedium),
            ),
            for (final p in StaffPresence.values)
              ListTile(
                leading: PresenceChip(presence: p),
                trailing: p == staff.presence ? const Icon(Icons.check) : null,
                onTap: () {
                  Navigator.pop(sheet);
                  if (p != staff.presence) cubit.setPresence(staff, p);
                },
              ),
            const SizedBox(height: AppSpace.md),
          ],
        ),
      );
    },
  );
}

/// Big number on a circle: the ticket, or the booked time if they haven't checked in.
class TicketBadge extends StatelessWidget {
  const TicketBadge({super.key, required this.entry, required this.timezone});

  final QueueEntry entry;
  final String timezone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fmt = Fmt.of(context);
    final b = entry.booking;
    final hasTicket = b.ticketNo != null;
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hasTicket ? c.primary : c.taken,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: hasTicket
          ? Text(fmt.number(b.ticketNo!),
              style: TextStyle(color: c.onPrimary, fontSize: 22, fontWeight: FontWeight.w800))
          : b.status == BookingStatus.arrived
              ? Icon(Icons.hourglass_top, color: c.textSecondary)
              : Text(fmt.time(b.startAt, timezone),
                  textAlign: TextAlign.center, style: TextStyle(color: c.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class QueueTile extends StatelessWidget {
  const QueueTile({super.key, required this.entry, required this.board, required this.busy, this.onInvoice});

  final QueueEntry entry;
  final DeskBoard board;
  final bool busy;
  final void Function(QueueEntry entry)? onInvoice;

  @override
  Widget build(BuildContext context) {
    final d = context.desk;
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final lang = context.l10n.localeName;
    final fmt = Fmt.of(context);
    final b = entry.booking;
    final tz = board.place.timezone;
    final staff = board.staffById(b.staffId);
    final cubit = context.read<DeskCubit>();

    final String? hint = switch (b.status) {
      BookingStatus.arrived => d.goesInAt(fmt.time(entry.expectedStartAt, tz)),
      BookingStatus.inProgress => b.room != null ? d.calledTo(b.room!) : null,
      _ when entry.late => d.late,
      _ when b.status.isBooked => fmt.time(b.startAt, tz),
      _ => null,
    };

    final Widget? action = busy
        ? const SizedBox.square(dimension: 28, child: Padding(padding: EdgeInsets.all(4), child: CircularProgressIndicator(strokeWidth: 2.5)))
        : switch (b.status) {
            BookingStatus.pending || BookingStatus.confirmed => FilledButton.tonal(
                onPressed: () => cubit.checkIn(entry), child: Text(d.checkIn)),
            BookingStatus.arrived => FilledButton.icon(
                onPressed: () => cubit.call(entry), icon: const Icon(Icons.campaign_outlined, size: 18), label: Text(d.call)),
            BookingStatus.inProgress => OutlinedButton(onPressed: () => cubit.finish(entry), child: Text(d.finish)),
            BookingStatus.completed when entry.invoiceStatus == null && onInvoice != null =>
              OutlinedButton.icon(
                  onPressed: () => onInvoice!(entry),
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: Text(d.makeInvoice)),
            _ => null,
          };

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      onTap: () => showVisitSheet(context, entry, board, onInvoice: onInvoice),
      child: Row(
        children: [
          TicketBadge(entry: entry, timezone: tz),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.customerName ?? b.customerPhone ?? '—',
                    style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${b.serviceName(lang)} · ${staff?.name ?? b.staffName}',
                    style: text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppSpace.xs),
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (hint != null)
                      Text(hint, style: text.labelMedium?.copyWith(color: entry.late ? c.danger : c.textSecondary)),
                    if (entry.delayMin >= 5 && (b.status == BookingStatus.arrived || b.status.isBooked))
                      _Badge(text: d.delay(fmt.number(entry.delayMin)), fg: c.warning, bg: c.warningSoft),
                    if (entry.invoiceNumber != null || entry.invoiceStatus != null)
                      _Badge(
                        text: entry.invoiceNumber != null ? '#${entry.invoiceNumber}' : d.provisional,
                        fg: entry.invoiceStatus == InvoiceStatus.paid ? c.success : c.warning,
                        bg: entry.invoiceStatus == InvoiceStatus.paid ? c.successSoft : c.warningSoft,
                        icon: Icons.receipt_long_outlined,
                      ),
                    if (entry.pendingSync)
                      _Badge(text: d.notSentYet, fg: c.textSecondary, bg: c.taken, icon: Icons.cloud_off_outlined),
                    if (b.status == BookingStatus.noShow) const StatusChip(status: BookingStatus.noShow),
                  ],
                ),
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: AppSpace.sm), action],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.fg, required this.bg, this.icon});

  final String text;
  final Color fg;
  final Color bg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpace.sm, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
          Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w700)),
        ]),
      );
}

/// One visit: the arrive → doctor → invoice timeline and every action that fits its stage.
Future<void> showVisitSheet(BuildContext context, QueueEntry entry, DeskBoard board,
    {void Function(QueueEntry entry)? onInvoice}) {
  final cubit = context.read<DeskCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) {
      final d = sheet.desk;
      final l10n = sheet.l10n;
      final fmt = Fmt.of(sheet);
      final text = Theme.of(sheet).textTheme;
      final b = entry.booking;
      final tz = board.place.timezone;
      String? at(DateTime? t) => t == null ? null : fmt.time(t, tz);
      final steps = [
        (d.arrival, at(b.checkedInAt), b.checkedInAt != null),
        (d.doctor, at(b.startedAt) ?? (b.room ?? ''), b.startedAt != null),
        (
          d.invoiceStep,
          entry.invoiceNumber != null ? '#${entry.invoiceNumber}' : (entry.invoiceStatus != null ? d.provisional : null),
          entry.invoiceStatus != null
        ),
      ];
      void run(Future<void> Function() f) {
        Navigator.pop(sheet);
        f();
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                TicketBadge(entry: entry, timezone: tz),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(b.customerName ?? '—', style: text.titleMedium),
                    if (b.customerPhone != null)
                      Text(b.customerPhone!, style: text.bodySmall, textDirection: TextDirection.ltr),
                  ]),
                ),
                StatusChip(status: b.status),
              ]),
              const SizedBox(height: AppSpace.md),
              Text('${b.serviceName(l10n.localeName)} · ${b.staffName} — ${fmt.time(b.startAt, tz)}', style: text.bodyMedium),
              const SizedBox(height: AppSpace.lg),
              Row(
                children: [
                  for (var i = 0; i < steps.length; i++) ...[
                    Expanded(child: _Step(label: steps[i].$1, value: steps[i].$2, done: steps[i].$3)),
                    if (i < steps.length - 1)
                      Container(width: 24, height: 2, color: steps[i].$3 ? sheet.colors.primary : sheet.colors.border),
                  ],
                ],
              ),
              const SizedBox(height: AppSpace.xl),
              Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.sm,
                children: [
                  if (b.status.isBooked) FilledButton(onPressed: () => run(() => cubit.checkIn(entry)), child: Text(d.checkIn)),
                  if (b.status == BookingStatus.arrived)
                    FilledButton.icon(
                        onPressed: () => run(() => cubit.call(entry)),
                        icon: const Icon(Icons.campaign_outlined),
                        label: Text(d.call)),
                  if (b.status == BookingStatus.inProgress) ...[
                    OutlinedButton.icon(
                        onPressed: () => run(() => cubit.call(entry)),
                        icon: const Icon(Icons.replay),
                        label: Text(d.callAgain)),
                    FilledButton(onPressed: () => run(() => cubit.finish(entry)), child: Text(d.finish)),
                  ],
                  if (b.status == BookingStatus.completed && entry.invoiceStatus == null && onInvoice != null)
                    FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(sheet);
                          onInvoice(entry);
                        },
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: Text(d.makeInvoice)),
                  if (b.status.isBooked || b.status == BookingStatus.arrived)
                    TextButton(onPressed: () => run(() => cubit.noShow(entry)), child: Text(d.noShow)),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.value, required this.done});

  final String label;
  final String? value;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? c.primary : c.surface,
          border: Border.all(color: done ? c.primary : c.border, width: 2),
        ),
        child: done ? Icon(Icons.check, size: 16, color: c.onPrimary) : null,
      ),
      const SizedBox(height: AppSpace.xs),
      Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: done ? FontWeight.w700 : null)),
      if (value != null && value!.isNotEmpty) Text(value!, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}
