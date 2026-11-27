import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/launch.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../places/domain/entities/place.dart';
import '../../domain/entities/desk_board.dart';
import '../../domain/entities/invoice.dart';
import '../cubit/audit_cubit.dart';
import '../cubit/invoices_cubit.dart';
import '../l10n/desk_strings.dart';
import '../widgets/audit_view.dart';
import '../widgets/invoice_editor_sheet.dart';

/// One invoice: a paper preview (A4 or receipt), pay, edit, print, void, and its history.
class InvoicePage extends StatefulWidget {
  const InvoicePage({super.key, required this.invoiceId, required this.place, required this.services});

  final String invoiceId;
  final DeskPlace place;
  final List<PlaceService> services;

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  bool _receipt = false;

  @override
  Widget build(BuildContext context) {
    final d = context.desk;
    final l10n = context.l10n;
    return BlocBuilder<InvoicesCubit, InvoicesState>(
      builder: (context, state) {
        final inv = state.invoices.where((i) => i.id == widget.invoiceId).firstOrNull;
        if (inv == null) {
          return Scaffold(appBar: AppBar(), body: EmptyState(icon: Icons.receipt_long_outlined, title: d.noInvoices));
        }
        final cubit = context.read<InvoicesCubit>();
        Future<void> report((Invoice?, Failure?) r) async {
          final f = r.$2;
          if (f != null && context.mounted) showMessage(context, d.failure(f, l10n));
          if (f == null && context.mounted) context.read<AuditCubit>().load();
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(d.invoiceNo(inv.number?.toString() ?? d.provisional)),
            actions: [
              if (inv.status != InvoiceStatus.voided && !inv.id.startsWith('local-'))
                IconButton(
                  tooltip: d.edit,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    final saved = await showInvoiceEditor(context,
                        cubit: cubit, services: widget.services, currency: inv.currency, editing: inv);
                    if (saved != null && context.mounted) context.read<AuditCubit>().load();
                  },
                ),
              if (inv.status != InvoiceStatus.voided && !inv.id.startsWith('local-'))
                PopupMenuButton<String>(
                  onSelected: (_) async {
                    final reason = await _askReason(context);
                    if (reason != null && reason.trim().isNotEmpty) await report(await cubit.voidIt(inv, reason));
                  },
                  itemBuilder: (_) => [PopupMenuItem(value: 'void', child: Text(d.voidInvoice))],
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpace.lg),
            children: [
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(d.printA4), icon: const Icon(Icons.description_outlined)),
                  ButtonSegment(value: true, label: Text(d.printReceipt), icon: const Icon(Icons.receipt_outlined)),
                ],
                selected: {_receipt},
                onSelectionChanged: (s) => setState(() => _receipt = s.first),
              ),
              const SizedBox(height: AppSpace.lg),
              Center(child: InvoicePaper(invoice: inv, place: widget.place, receipt: _receipt)),
              const SizedBox(height: AppSpace.lg),
              Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.sm,
                alignment: WrapAlignment.center,
                children: [
                  if (inv.status == InvoiceStatus.issued)
                    for (final m in [PaymentMethod.cash, PaymentMethod.card])
                      FilledButton.tonalIcon(
                        onPressed: state.busy ? null : () async => report(await cubit.pay(inv, m)),
                        icon: Icon(m == PaymentMethod.cash ? Icons.payments_outlined : Icons.credit_card),
                        label: Text('${d.markPaid} · ${d.method(m)}'),
                      ),
                  FilledButton.icon(
                    onPressed: () {
                      final url = inv.printUrl;
                      if (url == null) {
                        showMessage(context, d.previewNote);
                        return;
                      }
                      openLink('$url?size=${_receipt ? 'receipt' : 'a4'}&lang=${l10n.localeName}&print=1');
                    },
                    icon: const Icon(Icons.print_outlined),
                    label: Text(_receipt ? d.printReceipt : d.printA4),
                  ),
                ],
              ),
              if (!inv.id.startsWith('local-')) ...[
                const SizedBox(height: AppSpace.xl),
                Text(d.history, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpace.md),
                AuditView(timezone: widget.place.timezone, shrinkWrap: true),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<String?> _askReason(BuildContext context) {
    final d = context.desk;
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(d.voidInvoice),
        content: TextField(controller: controller, autofocus: true, decoration: InputDecoration(labelText: d.voidReason)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: Text(MaterialLocalizations.of(dialog).cancelButtonLabel)),
          FilledButton(onPressed: () => Navigator.pop(dialog, controller.text), child: Text(d.voidInvoice)),
        ],
      ),
    ).whenComplete(controller.dispose);
  }
}

/// The invoice as it prints: place, number, lines, totals, status stamp and a QR to verify it.
class InvoicePaper extends StatelessWidget {
  const InvoicePaper({super.key, required this.invoice, required this.place, this.receipt = false});

  final Invoice invoice;
  final DeskPlace place;
  final bool receipt;

  @override
  Widget build(BuildContext context) {
    final d = context.desk;
    final l10n = context.l10n;
    final fmt = Fmt.of(context);
    final c = context.colors;
    final inv = invoice;
    const ink = Color(0xFF0F172A);
    const muted = Color(0xFF475569);
    final base = Theme.of(context).textTheme.bodyMedium!.copyWith(color: ink, fontSize: receipt ? 12 : 14);
    final (String stamp, Color stampColor) = switch (inv.status) {
      InvoiceStatus.paid => (
          '${d.status(InvoiceStatus.paid)}${inv.paymentMethod == null ? '' : ' · ${d.method(inv.paymentMethod!)}'}',
          const Color(0xFF047857)
        ),
      InvoiceStatus.voided => (d.status(InvoiceStatus.voided), const Color(0xFFB91C1C)),
      InvoiceStatus.issued => (d.status(InvoiceStatus.issued), const Color(0xFFB45309)),
    };
    Widget row(String a, String b, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(a, style: base.copyWith(fontWeight: bold ? FontWeight.w800 : null))),
            Text(b, style: base.copyWith(fontWeight: bold ? FontWeight.w800 : null, fontSize: bold ? base.fontSize! + 4 : null)),
          ]),
        );
    final qrData = inv.printUrl ?? 'mawid:invoice:${place.slug}:${inv.number ?? inv.clientRef}';

    final qr = QrImageView(data: qrData, size: receipt ? 120 : 104, backgroundColor: Colors.white, padding: EdgeInsets.zero);
    final notes = [
      Text(d.scanToVerify, style: base, textAlign: receipt ? TextAlign.center : TextAlign.start),
      if (inv.edited) Text(d.editedAt(fmt.time(inv.updatedAt!, place.timezone)), style: base.copyWith(color: muted)),
      if (inv.createdByName != null) Text(d.createdBy(inv.createdByName!), style: base.copyWith(color: muted)),
      Text(d.thanks, style: base.copyWith(color: muted)),
    ];

    return Container(
      constraints: BoxConstraints(maxWidth: receipt ? 300 : 560),
      padding: EdgeInsets.all(receipt ? AppSpace.md : AppSpace.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(receipt ? 4 : 8),
        border: Border.all(color: c.border),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Text(place.name(l10n.localeName),
                  style: base.copyWith(fontSize: base.fontSize! + 6, fontWeight: FontWeight.w800, color: const Color(0xFF0369A1))),
            ),
            Text('#${inv.number ?? '—'}', style: base.copyWith(fontSize: base.fontSize! + 4, fontWeight: FontWeight.w800)),
          ]),
          if (inv.number == null) Text(d.provisional, style: base.copyWith(color: muted)),
          const Divider(color: Color(0xFF0369A1), thickness: 2),
          Text('${d.customer}: ${inv.customerName}', style: base),
          if (inv.staffName != null) Text('${d.doctor}: ${inv.staffName}', style: base),
          Text(fmt.dateTime(inv.createdAt, place.timezone), style: base.copyWith(color: muted)),
          const SizedBox(height: AppSpace.md),
          for (final l in inv.lines)
            row('${l.description}${l.qty > 1 ? ' × ${fmt.number(l.qty)}' : ''}', fmt.money(l.amount, inv.currency)),
          const Divider(),
          row(d.subtotal, fmt.money(inv.subtotal, inv.currency)),
          if (inv.discount > 0) row(d.discount, '− ${fmt.money(inv.discount, inv.currency)}'),
          row(d.total, fmt.money(inv.total, inv.currency), bold: true),
          const SizedBox(height: AppSpace.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs),
              decoration: BoxDecoration(border: Border.all(color: stampColor, width: 2), borderRadius: BorderRadius.circular(8)),
              child: Text(stamp, style: base.copyWith(color: stampColor, fontWeight: FontWeight.w800)),
            ),
          ),
          if (inv.voidReason != null) Text(inv.voidReason!, style: base.copyWith(color: const Color(0xFFB91C1C))),
          const SizedBox(height: AppSpace.md),
          if (receipt)
            Column(children: [qr, const SizedBox(height: AppSpace.sm), ...notes])
          else
            Row(children: [
              qr,
              const SizedBox(width: AppSpace.md),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: notes)),
            ]),
        ],
      ),
    );
  }
}
