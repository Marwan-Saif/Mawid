import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/place_visuals.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/place.dart';
import '../cubit/home_cubit.dart';
import '../cubit/place_details_cubit.dart';
import '../widgets/place_tile.dart';

class PlaceDetailsPage extends StatefulWidget {
  const PlaceDetailsPage({super.key});

  @override
  State<PlaceDetailsPage> createState() => _PlaceDetailsPageState();
}

enum _Tab { services, team, reviews }

class _PlaceDetailsPageState extends State<PlaceDetailsPage> {
  _Tab _tab = _Tab.services;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaceDetailsCubit, PlaceDetailsState>(
      builder: (context, state) {
        final details = state.details;
        if (state.status == LoadStatus.failure) {
          return Scaffold(
            appBar: AppBar(),
            body: ErrorView(failure: state.failure!, onRetry: () => context.read<PlaceDetailsCubit>().load()),
          );
        }
        if (details == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Padding(padding: EdgeInsets.all(AppSpace.lg), child: SkeletonList()),
          );
        }
        return _content(context, details);
      },
    );
  }

  void _book(BuildContext context, PlaceDetails d, PlaceService s) =>
      context.push('/place/${d.place.id}/book?serviceId=${s.id}', extra: d);

  Widget _content(BuildContext context, PlaceDetails d) {
    final l10n = context.l10n;
    final c = context.colors;
    final fmt = Fmt.of(context);
    final text = Theme.of(context).textTheme;
    final lang = l10n.localeName;
    final p = d.place;
    final open = isOpenToday(p, DateTime.now().toUtc());

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 180,
            backgroundColor: c.primarySoft,
            foregroundColor: c.textPrimary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: c.primarySoft,
                alignment: Alignment.center,
                child: Icon(categoryIcon(p.category), size: 72, color: c.primary.withValues(alpha: 0.5)),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(p.name(lang), style: text.headlineSmall)),
                      Container(
                        padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpace.md, vertical: 6),
                        decoration: BoxDecoration(
                          color: open ? c.successSoft : c.taken,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(open ? l10n.openToday : l10n.closedToday,
                            style: text.labelMedium?.copyWith(
                                color: open ? c.success : c.textSecondary, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Wrap(
                    spacing: AppSpace.md,
                    runSpacing: AppSpace.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.star_rounded, size: 18, color: c.warning),
                        const SizedBox(width: 2),
                        Text('${fmt.number(p.rating, decimals: 1)} ${l10n.reviewsCount(fmt.number(p.reviewsCount))}',
                            style: text.bodyMedium),
                      ]),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.place_outlined, size: 18, color: c.textSecondary),
                        const SizedBox(width: 2),
                        Text(p.area(lang), style: text.bodyMedium),
                      ]),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.schedule_outlined, size: 18, color: c.textSecondary),
                        const SizedBox(width: 2),
                        Text(
                          l10n.hours(fmt.wallTime(p.openTime.hour, p.openTime.minute),
                              fmt.wallTime(p.closeTime.hour, p.closeTime.minute)),
                          style: text.bodyMedium,
                        ),
                      ]),
                    ],
                  ),
                  const SizedBox(height: AppSpace.lg),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<_Tab>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(value: _Tab.services, label: Text(l10n.servicesTab)),
                        ButtonSegment(value: _Tab.team, label: Text(l10n.teamTab)),
                        ButtonSegment(value: _Tab.reviews, label: Text(l10n.reviewsTab)),
                      ],
                      selected: {_tab},
                      onSelectionChanged: (s) => setState(() => _tab = s.first),
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, 120),
            sliver: SliverList.list(
              children: switch (_tab) {
                _Tab.services => [
                    for (final s in d.services)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.md),
                        child: AppCard(
                          onTap: () => _book(context, d, s),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.name(lang), style: text.titleMedium),
                                    const SizedBox(height: AppSpace.xs),
                                    Row(children: [
                                      Icon(Icons.schedule_outlined, size: 16, color: c.textSecondary),
                                      const SizedBox(width: AppSpace.xs),
                                      Text(l10n.minutes(fmt.number(s.durationMin)), style: text.bodyMedium),
                                    ]),
                                  ],
                                ),
                              ),
                              Text(fmt.money(s.price, p.currency),
                                  style: text.titleMedium?.copyWith(color: c.primary)),
                              const SizedBox(width: AppSpace.md),
                              FilledButton.tonal(
                                onPressed: () => _book(context, d, s),
                                style: FilledButton.styleFrom(minimumSize: const Size(64, AppSpace.touch)),
                                child: Text(l10n.book),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                _Tab.team => [
                    for (final m in d.staff)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.md),
                        child: AppCard(
                          child: Row(children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: c.primarySoft,
                              child: Text(m.name.characters.first, style: text.titleMedium?.copyWith(color: c.primary)),
                            ),
                            const SizedBox(width: AppSpace.md),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(m.name, style: text.titleMedium),
                                Text(m.title(lang), style: text.bodyMedium),
                              ]),
                            ),
                          ]),
                        ),
                      ),
                  ],
                _Tab.reviews => d.reviews.isEmpty
                    ? [EmptyState(icon: Icons.rate_review_outlined, title: l10n.noReviews)]
                    : [
                        for (final r in d.reviews)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpace.md),
                            child: AppCard(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Expanded(child: Text(r.author, style: text.titleMedium)),
                                  Semantics(
                                    label: '${r.rating}/5',
                                    child: ExcludeSemantics(
                                      child: Row(children: [
                                        for (var i = 0; i < 5; i++)
                                          Icon(i < r.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                              size: 16, color: c.warning),
                                      ]),
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: AppSpace.xs),
                                Text(r.text, style: text.bodyLarge),
                              ]),
                            ),
                          ),
                      ],
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: d.services.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: FilledButton(
                  onPressed: () => _book(context, d, d.services.first),
                  child: Text(l10n.bookAppointment),
                ),
              ),
            ),
    );
  }
}
