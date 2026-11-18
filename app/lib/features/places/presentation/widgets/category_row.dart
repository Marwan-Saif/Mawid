import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/place_visuals.dart';
import '../../domain/entities/place.dart';

class CategoryRow extends StatelessWidget {
  const CategoryRow({super.key, required this.onSelected});

  final ValueChanged<PlaceCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = context.l10n;
    return Row(
      children: [
        for (final (i, cat) in PlaceCategory.values.indexed) ...[
          if (i > 0) const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Material(
              color: c.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                side: BorderSide(color: c.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onSelected(cat),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                  child: Column(
                    children: [
                      Icon(categoryIcon(cat), color: c.primary),
                      const SizedBox(height: AppSpace.xs),
                      Text(categoryLabel(l10n, cat),
                          style: Theme.of(context).textTheme.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
