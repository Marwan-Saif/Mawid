import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../places/domain/entities/place.dart';
import '../../domain/entities/desk_board.dart';
import '../../domain/entities/invoice.dart';
import '../cubit/invoices_cubit.dart';
import '../l10n/desk_strings.dart';

/// New invoice for a finished visit (or a counter sale), or edits to an existing one.
/// Returns the saved invoice.
Future<Invoice?> showInvoiceEditor(
  BuildContext context, {
  required InvoicesCubit cubit,
  required List<PlaceService> services,
  required String currency,
  QueueEntry? visit,
  Invoice? editing,
}) =>
    showModalBottomSheet<Invoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _InvoiceEditor(cubit: cubit, services: services, currency: currency, visit: visit, editing: editing),
    );

class _InvoiceEditor extends StatefulWidget {
  const _InvoiceEditor({required this.cubit, required this.services, required this.currency, this.visit, this.editing});

  final InvoicesCubit cubit;
  final List<PlaceService> services;
  final String currency;
  final QueueEntry? visit;
  final Invoice? editing;

  @override
  State<_InvoiceEditor> createState() => _InvoiceEditorState();
}

class _InvoiceEditorState extends State<_InvoiceEditor> {
  late List<InvoiceLine> _lines;
  late final TextEditingController _discount;
  final _customer = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  PaymentMethod? _paidWith;
  bool _saving = false;
  Failure? _failure;
  late final String _clientRef = newClientRef();

  @override
  void initState() {
    super.initState();
    final inv = widget.editing;
    if (inv != null) {
      _lines = [...inv.lines];
      _discount = TextEditingController(text: inv.discount == 0 ? '' : _plain(inv.discount));
    } else {
      final b = widget.visit?.booking;
      _lines = b == null ? [] : [InvoiceLine(description: b.serviceNameAr, qty: 1, unitPrice: b.price, serviceId: b.serviceId)];
      _discount = TextEditingController();
    }
  }

  @override
  void dispose() {
    _discount.dispose();
    _customer.dispose();
    _desc.dispose();
    _price.dispose();
    super.dispose();
  }

  static String _plain(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  double get _discountValue => double.tryParse(_discount.text.trim().replaceAll(',', '.')) ?? 0;

  double get _subtotal => _lines.fold(0, (s, l) => s + l.amount);

  void _addService(PlaceService s, String lang) {
    setState(() {
      final i = _lines.indexWhere((l) => l.serviceId == s.id);
      if (i >= 0) {
        _lines[i] = _lines[i].copyWith(qty: _lines[i].qty + 1);
      } else {
        _lines.add(InvoiceLine(description: lang == 'ar' ? s.nameAr : s.nameEn, qty: 1, unitPrice: s.price, serviceId: s.id));
      }
    });
  }

  void _addCustom() {
    final price = double.tryParse(_price.text.trim().replaceAll(',', '.'));
    if (_desc.text.trim().isEmpty || price == null) return;
    setState(() {
      _lines.add(InvoiceLine(description: _desc.text.trim(), qty: 1, unitPrice: price));
      _desc.clear();
      _price.clear();
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _failure = null;
    });
    final inv = widget.editing;
    final (saved, failure) = inv != null
        ? await widget.cubit.edit(inv, _lines, _discountValue)
        : await widget.cubit.issue(InvoiceDraft(
            bookingId: widget.visit?.booking.id,
            customerName: widget.visit?.booking.customerName ?? _customer.text.trim(),
            customerPhone: widget.visit?.booking.customerPhone,
            staffName: widget.visit?.booking.staffName,
            lines: _lines,
            discount: _discountValue,
            paidWith: _paidWith,
            clientRef: _clientRef,
          ));
    if (!mounted) return;
    if (saved != null) {
      Navigator.pop(context, saved);
    } else {
      setState(() {
        _saving = false;
        _failure = failure;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = context.desk;
    final l10n = context.l10n;
    final c = context.colors;
    final fmt = Fmt.of(context);
    final text = Theme.of(context).textTheme;
    final lang = l10n.localeName;
    final total = (_subtotal - _discountValue).clamp(0, double.infinity);
    final editing = widget.editing;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.xl),
        children: [
          Text(
            editing != null
                ? d.invoiceNo(editing.number?.toString() ?? d.provisional)
                : d.newInvoice,
            style: text.titleLarge,
          ),
          if (widget.visit != null)
            Text('${widget.visit!.booking.customerName ?? ''} · ${widget.visit!.booking.staffName}', style: text.bodyMedium)
          else if (editing != null)
            Text(editing.customerName, style: text.bodyMedium)
          else ...[
            const SizedBox(height: AppSpace.md),
            TextField(
              controller: _customer,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: d.customer),
            ),
          ],
          const SizedBox(height: AppSpace.lg),
          for (var i = 0; i < _lines.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: Row(
                children: [
                  Expanded(child: Text(_lines[i].description, style: text.bodyLarge)),
                  IconButton(
                    tooltip: '−',
                    onPressed: () => setState(() {
                      if (_lines[i].qty > 1) {
                        _lines[i] = _lines[i].copyWith(qty: _lines[i].qty - 1);
                      } else {
                        _lines.removeAt(i);
                      }
                    }),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(fmt.number(_lines[i].qty), style: text.titleSmall),
                  IconButton(
                    tooltip: '+',
                    onPressed: () => setState(() => _lines[i] = _lines[i].copyWith(qty: _lines[i].qty + 1)),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  SizedBox(
                    width: 84,
                    child: Text(fmt.money(_lines[i].amount, widget.currency), textAlign: TextAlign.end, style: text.titleSmall),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpace.sm),
          Text(d.quickAdd, style: text.labelLarge),
          const SizedBox(height: AppSpace.sm),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              for (final s in widget.services)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text('${lang == 'ar' ? s.nameAr : s.nameEn} — ${fmt.money(s.price, widget.currency)}'),
                  onPressed: () => _addService(s, lang),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(controller: _desc, decoration: InputDecoration(labelText: d.otherItem, isDense: true)),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: InputDecoration(labelText: d.price, isDense: true),
                  onSubmitted: (_) => _addCustom(),
                ),
              ),
              IconButton.filledTonal(onPressed: _addCustom, icon: const Icon(Icons.add)),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: _discount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: InputDecoration(labelText: d.discount, isDense: true),
            onChanged: (_) => setState(() {}),
          ),
          const Divider(height: AppSpace.xl),
          _Total(label: d.subtotal, value: fmt.money(_subtotal, widget.currency)),
          if (_discountValue > 0) _Total(label: d.discount, value: '− ${fmt.money(_discountValue, widget.currency)}'),
          _Total(label: d.total, value: fmt.money(total, widget.currency), big: true),
          if (editing == null) ...[
            const SizedBox(height: AppSpace.md),
            Text(d.paidNow, style: text.labelLarge),
            const SizedBox(height: AppSpace.sm),
            Wrap(spacing: AppSpace.sm, children: [
              for (final m in PaymentMethod.values)
                ChoiceChip(
                  label: Text(d.method(m)),
                  selected: _paidWith == m,
                  onSelected: (v) => setState(() => _paidWith = v ? m : null),
                ),
            ]),
          ],
          if (_failure != null) ...[
            const SizedBox(height: AppSpace.md),
            Text(d.failure(_failure!, l10n), style: TextStyle(color: c.danger, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: AppSpace.lg),
          PrimaryButton(
            label: editing != null ? d.saveChanges : d.newInvoice,
            icon: Icons.receipt_long_outlined,
            loading: _saving,
            onPressed: _lines.isEmpty ? null : _save,
          ),
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value, this.big = false});

  final String label;
  final String value;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final style = big
        ? Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)
        : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [Expanded(child: Text(label, style: style)), Text(value, style: style)]),
    );
  }
}
