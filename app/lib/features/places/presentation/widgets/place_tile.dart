import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/place_visuals.dart';
import '../../domain/entities/place.dart';

bool isOpenToday(Place p, DateTime nowUtc) => !p.isClosedOn(Fmt.inZone(nowUtc, p.timezone).weekday);

class PlaceTile extends StatelessWidget {
  const PlaceTile({super.key, required this.place, required this.onTap});

  final Place place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final fmt = Fmt.of(context);
    final lang = l10n.localeName;
    final text = Theme.of(context).textTheme;
    final open = isOpenToday(place, DateTime.now().toUtc());

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(
        children: [
          PlaceAvatar(category: place.category),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place.name(lang), style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '${categoryLabel(l10n, place.category)} · ${place.area(lang)}',
                  style: text.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpace.xs),
                Row(
                  children: [
                    Icon(Icons.star_rounded, size: 18, color: c.warning),
                    const SizedBox(width: 2),
                    Text(fmt.number(place.rating, decimals: 1), style: text.bodyMedium),
                    const SizedBox(width: AppSpace.md),
                    Text(l10n.km(fmt.number(place.distanceKm, decimals: 1)), style: text.bodyMedium),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Container(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs),
            decoration: BoxDecoration(
              color: open ? c.successSoft : c.taken,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              open ? l10n.openToday : l10n.closedToday,
              style: text.labelSmall?.copyWith(color: open ? c.success : c.textSecondary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
