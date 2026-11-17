import 'package:flutter/material.dart';

import '../../features/places/domain/entities/place.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

IconData categoryIcon(PlaceCategory c) => switch (c) {
      PlaceCategory.clinic => Icons.medical_services_outlined,
      PlaceCategory.dental => Icons.health_and_safety_outlined,
      PlaceCategory.salon => Icons.content_cut,
      PlaceCategory.spa => Icons.spa_outlined,
    };

String categoryLabel(AppLocalizations l10n, PlaceCategory c) => switch (c) {
      PlaceCategory.clinic => l10n.categoryClinic,
      PlaceCategory.dental => l10n.categoryDental,
      PlaceCategory.salon => l10n.categorySalon,
      PlaceCategory.spa => l10n.categorySpa,
    };

/// Square badge with the category icon; stands in for a photo until owners upload one.
class PlaceAvatar extends StatelessWidget {
  const PlaceAvatar({super.key, required this.category, this.size = 64});

  final PlaceCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: c.primarySoft, borderRadius: BorderRadius.circular(AppRadius.sm)),
        child: Icon(categoryIcon(category), color: c.primary, size: size * 0.42),
      ),
    );
  }
}
