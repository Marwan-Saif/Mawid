import 'package:flutter/material.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/l10n/failure_messages.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../injection_container.dart';
import '../../../booking/domain/entities/time_slot.dart';
import '../../../booking/domain/usecases/get_available_slots.dart';
import '../../../booking/presentation/widgets/slots_grid.dart';
import '../../../booking/presentation/widgets/staff_picker.dart';
import '../../../places/domain/entities/place.dart';
import '../../domain/repositories/owner_repository.dart';
import '../../domain/usecases/owner_usecases.dart';

/// Walk-in / phone booking. Uses the same availability and locks as customer bookings,
/// so the owner can never double-book either.
Future<bool?> showManualBookingSheet(BuildContext context, PlaceDetails place, DateTime? day) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ManualBookingSheet(place: place, initialDay: day),
    );

class _ManualBookingSheet extends StatefulWidget {
  const _ManualBookingSheet({required this.place, required this.initialDay});

  final PlaceDetails place;
  final DateTime? initialDay;

  @override
  State<_ManualBookingSheet> createState() => _ManualBookingSheetState();
}

class _ManualBookingSheetState extends State<_ManualBookingSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  late PlaceService _service = widget.place.services.firstWhere((s) => s.active, orElse: () => widget.place.services.first);
  String? _staffId;
  late DateTime _day;
  late DateTime _today;
  List<TimeSlot> _slots = const [];
  TimeSlot? _slot;
  bool _loading = false;
  bool _saving = false;
  Failure? _failure;

  @override
  void initState() {
    super.initState();
    final today = Fmt.inZone(DateTime.now().toUtc(), widget.place.place.timezone);
    _today = DateTime.utc(today.year, today.month, today.day);
    final initial = widget.initialDay;
    _day = initial == null || initial.isBefore(_today) ? _today : initial;
    _loadSlots();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _loadSlots() async {
    setState(() {
      _loading = true;
      _slot = null;
    });
    final result = await sl<GetAvailableSlots>()(SlotsParams(
      placeId: widget.place.place.id,
      serviceId: _service.id,
      day: _day,
      staffId: _staffId,
    ));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _slots = result.getOrElse(() => const []);
    });
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (_slot == null || _name.text.trim().isEmpty) {
      setState(() => _failure = const ValidationFailure('VALIDATION'));
      showMessage(context, l10n.errRequired);
      return;
    }
    setState(() {
      _saving = true;
      _failure = null;
    });
    final result = await sl<AddManualBooking>()(ManualBookingRequest(
      serviceId: _service.id,
      staffId: _staffId,
      startAt: _slot!.startAt,
      customerName: _name.text,
      customerPhone: _phone.text,
    ));
    if (!mounted) return;
    result.fold(
      (f) {
        setState(() {
          _saving = false;
          _failure = f;
        });
        if (f is SlotTakenFailure) _loadSlots();
      },
      (_) {
        showMessage(context, l10n.saved);
        Navigator.pop(context, true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = Fmt.of(context);
    final text = Theme.of(context).textTheme;
    final lang = l10n.localeName;
    final days = List.generate(14, (i) => DateTime.utc(_today.year, _today.month, _today.day + i));
    final staff = widget.place.staffFor(_service.id);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.xl),
        children: [
          Text(l10n.manualBooking, style: text.titleLarge),
          const SizedBox(height: AppSpace.lg),
          DropdownButtonFormField<String>(
            initialValue: _service.id,
            decoration: InputDecoration(labelText: l10n.serviceLabel),
            items: [
              for (final s in widget.place.services.where((s) => s.active))
                DropdownMenuItem(value: s.id, child: Text('${s.name(lang)} · ${l10n.minutes(fmt.number(s.durationMin))}')),
            ],
            onChanged: (id) {
              if (id == null) return;
              setState(() {
                _service = widget.place.serviceById(id)!;
                _staffId = null;
              });
              _loadSlots();
            },
          ),
          if (staff.length > 1) ...[
            const SizedBox(height: AppSpace.lg),
            StaffPicker(
              staff: staff,
              selectedId: _staffId,
              onSelected: (id) {
                setState(() => _staffId = id);
                _loadSlots();
              },
            ),
          ],
          const SizedBox(height: AppSpace.lg),
          SizedBox(
            height: AppSpace.touch,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final d in days)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: AppSpace.sm),
                    child: ChoiceChip(
                      label: Text('${fmt.weekdayShort(d)} ${fmt.dayNumber(d)}'),
                      selected: d == _day,
                      onSelected: widget.place.place.isClosedOn(d.weekday)
                          ? null
                          : (_) {
                              setState(() => _day = d);
                              _loadSlots();
                            },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          if (_loading)
            const SkeletonList(count: 2, height: 48)
          else if (_slots.where((s) => s.available).isEmpty)
            Text(l10n.noSlots, style: text.bodyMedium)
          else
            SlotsGrid(
              slots: _slots,
              selected: _slot,
              timezone: widget.place.place.timezone,
              onSelected: (s) => setState(() => _slot = s),
            ),
          const SizedBox(height: AppSpace.lg),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: l10n.customerName),
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: l10n.customerPhone, hintText: '+971 50 123 4567'),
          ),
          if (_failure != null && _failure!.code != 'VALIDATION')
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.md),
              child: Text(_failure!.message(l10n), style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: AppSpace.lg),
          PrimaryButton(label: l10n.save, loading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}
