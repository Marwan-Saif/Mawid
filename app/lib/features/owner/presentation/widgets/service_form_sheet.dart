import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/l10n/failure_messages.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../places/domain/entities/place.dart';
import '../../domain/repositories/owner_repository.dart';

/// Add or edit a service. [onSave] returns a failure to show, or null when saved.
Future<void> showServiceForm(
  BuildContext context, {
  PlaceService? existing,
  required Future<Failure?> Function(ServiceDraft draft) onSave,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ServiceForm(existing: existing, onSave: onSave),
    );

class _ServiceForm extends StatefulWidget {
  const _ServiceForm({required this.existing, required this.onSave});

  final PlaceService? existing;
  final Future<Failure?> Function(ServiceDraft draft) onSave;

  @override
  State<_ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends State<_ServiceForm> {
  final _form = GlobalKey<FormState>();
  late final _nameAr = TextEditingController(text: widget.existing?.nameAr);
  late final _nameEn = TextEditingController(text: widget.existing?.nameEn);
  late final _duration = TextEditingController(text: '${widget.existing?.durationMin ?? 30}');
  late final _price = TextEditingController(text: widget.existing == null ? '' : _plain(widget.existing!.price));
  late bool _active = widget.existing?.active ?? true;
  bool _saving = false;
  Failure? _failure;

  static String _plain(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _nameAr.dispose();
    _nameEn.dispose();
    _duration.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _failure = null;
    });
    final failure = await widget.onSave(ServiceDraft(
      nameAr: _nameAr.text,
      nameEn: _nameEn.text,
      durationMin: int.parse(_duration.text),
      price: double.parse(_price.text),
      active: _active,
    ));
    if (!mounted) return;
    if (failure == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = false;
        _failure = failure;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String? requiredField(String? v) => (v == null || v.trim().isEmpty) ? l10n.errRequired : null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.xl),
          children: [
            Text(widget.existing == null ? l10n.addService : l10n.editService,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpace.lg),
            TextFormField(
              controller: _nameAr,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(labelText: l10n.nameAr),
              validator: requiredField,
            ),
            const SizedBox(height: AppSpace.md),
            TextFormField(
              controller: _nameEn,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(labelText: l10n.nameEn),
              validator: requiredField,
            ),
            const SizedBox(height: AppSpace.md),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _duration,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: l10n.durationMin),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return n == null || n < 15 || n > 480 || n % 15 != 0 ? l10n.errInvalidDuration : null;
                  },
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: TextFormField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: InputDecoration(labelText: l10n.price),
                  validator: (v) => double.tryParse(v ?? '') == null ? l10n.errRequired : null,
                ),
              ),
            ]),
            const SizedBox(height: AppSpace.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.activeService),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            if (_failure != null)
              Text(_failure!.message(l10n), style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: AppSpace.md),
            PrimaryButton(label: l10n.save, loading: _saving, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
