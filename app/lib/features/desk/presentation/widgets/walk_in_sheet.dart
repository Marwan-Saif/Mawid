import 'package:flutter/material.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/entities/desk_board.dart';
import '../cubit/desk_cubit.dart';
import '../l10n/desk_strings.dart';

/// Someone at the desk without a booking: name, phone, what for, and with whom (or whoever is free).
Future<void> showWalkInSheet(BuildContext context, DeskCubit cubit, DeskBoard board) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _WalkInSheet(cubit: cubit, board: board),
    );

class _WalkInSheet extends StatefulWidget {
  const _WalkInSheet({required this.cubit, required this.board});

  final DeskCubit cubit;
  final DeskBoard board;

  @override
  State<_WalkInSheet> createState() => _WalkInSheetState();
}

class _WalkInSheetState extends State<_WalkInSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String? _serviceId;
  String? _staffId;
  bool _busy = false;
  Failure? _failure;

  @override
  void initState() {
    super.initState();
    _serviceId = widget.board.services.firstOrNull?.id;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final service = _serviceId;
    if (service == null) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final f = await widget.cubit.walkIn(
      WalkInRequest(serviceId: service, staffId: _staffId, customerName: _name.text, customerPhone: _phone.text),
    );
    if (!mounted) return;
    if (f == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        _busy = false;
        _failure = f;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = context.desk;
    final l10n = context.l10n;
    final lang = l10n.localeName;
    final fmt = Fmt.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.xl),
        children: [
          Text(d.walkInTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpace.lg),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: l10n.customerName, prefixIcon: const Icon(Icons.person_outline)),
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: l10n.customerPhone,
              hintText: '+962 79 123 4567',
              prefixIcon: const Icon(Icons.phone_iphone_outlined),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          DropdownButtonFormField<String>(
            initialValue: _serviceId,
            decoration: InputDecoration(labelText: d.serviceLabel),
            items: [
              for (final s in widget.board.services)
                DropdownMenuItem(
                  value: s.id,
                  child: Text('${lang == 'ar' ? s.nameAr : s.nameEn} — ${fmt.money(s.price, widget.board.place.currency)}'),
                ),
            ],
            onChanged: (v) => setState(() => _serviceId = v),
          ),
          const SizedBox(height: AppSpace.md),
          Text(d.staffLabel, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpace.sm),
          Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
            ChoiceChip(label: Text(d.anyone), selected: _staffId == null, onSelected: (_) => setState(() => _staffId = null)),
            for (final s in widget.board.staff)
              ChoiceChip(label: Text(s.name), selected: _staffId == s.id, onSelected: (_) => setState(() => _staffId = s.id)),
          ]),
          if (_failure != null) ...[
            const SizedBox(height: AppSpace.md),
            Text(d.failure(_failure!, l10n),
                style: TextStyle(color: context.colors.danger, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: AppSpace.xl),
          PrimaryButton(label: d.add, icon: Icons.playlist_add, loading: _busy, onPressed: _submit),
        ],
      ),
    );
  }
}
