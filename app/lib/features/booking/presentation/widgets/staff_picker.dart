import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../places/domain/entities/place.dart';

/// "With whom?": anyone available, or a specific person who does this service.
class StaffPicker extends StatelessWidget {
  const StaffPicker({super.key, required this.staff, required this.selectedId, required this.onSelected});

  final List<StaffMember> staff;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: AppSpace.sm,
      runSpacing: AppSpace.sm,
      children: [
        ChoiceChip(
          label: Text(l10n.anyone),
          selected: selectedId == null,
          onSelected: (_) => onSelected(null),
        ),
        for (final s in staff)
          ChoiceChip(
            label: Text(s.name),
            selected: selectedId == s.id,
            onSelected: (_) => onSelected(s.id),
          ),
      ],
    );
  }
}
