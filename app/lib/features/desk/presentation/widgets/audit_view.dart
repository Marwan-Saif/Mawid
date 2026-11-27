import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../places/presentation/cubit/home_cubit.dart';
import '../../domain/entities/audit_entry.dart';
import '../../domain/entities/desk_board.dart';
import '../cubit/audit_cubit.dart';
import '../l10n/desk_strings.dart';

/// "سارة (الاستقبال) عدّل فاتورة #1042 · ١١:١٢ — الإجمالي ٢٠ ← ٢٥ · اتضاف: قياس ضغط".
class AuditView extends StatelessWidget {
  const AuditView({super.key, required this.timezone, this.shrinkWrap = false});

  final String timezone;

  /// Inside another scroll view (an invoice's history).
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuditCubit, AuditState>(
      builder: (context, state) {
        final cubit = context.read<AuditCubit>();
        if (state.status == LoadStatus.loading && state.entries.isEmpty) {
          return const Padding(padding: EdgeInsets.all(AppSpace.lg), child: SkeletonList(count: 3, height: 56));
        }
        if (state.status == LoadStatus.failure && state.entries.isEmpty) {
          return ErrorView(failure: state.failure!, onRetry: cubit.load);
        }
        if (state.entries.isEmpty) {
          return EmptyState(icon: Icons.history, title: context.desk.logEmpty);
        }
        final list = ListView.separated(
          shrinkWrap: shrinkWrap,
          physics: shrinkWrap ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(shrinkWrap ? 0 : AppSpace.lg),
          itemCount: state.entries.length,
          separatorBuilder: (_, __) => const Divider(height: AppSpace.lg),
          itemBuilder: (context, i) => AuditRow(entry: state.entries[i], timezone: timezone),
        );
        return shrinkWrap ? list : RefreshIndicator(onRefresh: cubit.load, child: list);
      },
    );
  }
}

class AuditRow extends StatelessWidget {
  const AuditRow({super.key, required this.entry, required this.timezone});

  final AuditEntry entry;
  final String timezone;

  @override
  Widget build(BuildContext context) {
    final d = context.desk;
    final c = context.colors;
    final fmt = Fmt.of(context);
    final text = Theme.of(context).textTheme;
    final detail = describe(context, entry);
    final (IconData icon, Color color) = switch (entry.action) {
      'INVOICE_EDITED' || 'INVOICE_VOIDED' => (Icons.edit_note, c.warning),
      'INVOICE_CREATED' || 'INVOICE_PAID' => (Icons.receipt_long_outlined, c.success),
      'CALLED' => (Icons.campaign_outlined, c.primary),
      'CHECKED_IN' || 'WALK_IN_ADDED' => (Icons.qr_code_2, c.primary),
      'NO_SHOW' || 'BOOKING_CANCELLED' => (Icons.person_off_outlined, c.danger),
      _ => (Icons.history, c.textSecondary),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: entry.actorName, style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: ' (${d.role(entry.actorRole)}) ', style: TextStyle(color: c.textSecondary)),
                TextSpan(text: d.action(entry.action)),
                if (entry.entityLabel != null)
                  TextSpan(text: ' ${entry.entityLabel}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ])),
              if (detail != null) Text(detail, style: text.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Text(fmt.time(entry.at, timezone), style: text.labelMedium),
      ],
    );
  }

  /// The specifics, in words. Old → new reads in the language's direction.
  static String? describe(BuildContext context, AuditEntry e) {
    final d = context.desk;
    final fmt = Fmt.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final arrow = rtl ? ' ← ' : ' → ';
    final x = e.details;
    String money(Object? v) => v is num ? fmt.number(v, decimals: v == v.roundToDouble() ? 0 : 2) : '$v';
    final parts = <String>[];
    switch (e.action) {
      case 'INVOICE_EDITED':
        if (x['totalFrom'] != null) parts.add('${d.total} ${money(x['totalFrom'])}$arrow${money(x['totalTo'])}');
        if (x['added'] is List) parts.add('+ ${(x['added'] as List).join('، ')}');
        if (x['removed'] is List) parts.add('− ${(x['removed'] as List).join('، ')}');
        if (x['discountTo'] != null) parts.add('${d.discount} ${money(x['discountFrom'])}$arrow${money(x['discountTo'])}');
      case 'INVOICE_CREATED' || 'INVOICE_PAID' || 'INVOICE_VOIDED':
        if (x['total'] != null) parts.add('${d.total} ${money(x['total'])} ${x['currency'] ?? ''}'.trim());
        if (x['reason'] != null) parts.add('${x['reason']}');
      case 'CALLED':
        if (x['ticket'] != null) parts.add(d.ticket(fmt.number(x['ticket'] as num)));
        if (x['room'] != null) parts.add('${x['room']}');
        if (x['repeat'] == true) parts.add(d.callAgain);
      case 'CHECKED_IN':
        if (x['ticket'] != null) parts.add(d.ticket(fmt.number(x['ticket'] as num)));
        if (x['via'] == 'QR') parts.add('QR');
      case 'PRESENCE_CHANGED':
        final from = _presence(x['from']);
        final to = _presence(x['to']);
        if (from != null && to != null) parts.add('${d.presence(from)}$arrow${d.presence(to)}');
      case 'SERVICE_SAVED':
        if (x['priceFrom'] != null) parts.add('${d.price} ${money(x['priceFrom'])}$arrow${money(x['priceTo'])}');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static StaffPresence? _presence(Object? code) => switch (code) {
        'AVAILABLE' => StaffPresence.available,
        'BUSY' => StaffPresence.busy,
        'BREAK' => StaffPresence.onBreak,
        'AWAY' => StaffPresence.away,
        _ => null,
      };
}
