import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/place_visuals.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/place.dart';
import '../cubit/explore_cubit.dart';
import '../cubit/home_cubit.dart';
import '../widgets/place_tile.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key, this.autofocus = false});

  final bool autofocus;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  late final _search = TextEditingController(text: context.read<ExploreCubit>().state.query);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navExplore)),
      body: BlocBuilder<ExploreCubit, ExploreState>(
        builder: (context, state) {
          final cubit = context.read<ExploreCubit>();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                child: TextField(
                  controller: _search,
                  autofocus: widget.autofocus,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(hintText: l10n.searchHint, prefixIcon: const Icon(Icons.search)),
                  onChanged: cubit.setQuery,
                ),
              ),
              SizedBox(
                height: 64,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm),
                  children: [
                    _chip(context, l10n.allCategories, state.category == null, () => cubit.setCategory(null)),
                    for (final cat in PlaceCategory.values)
                      _chip(context, categoryLabel(l10n, cat), state.category == cat, () => cubit.setCategory(cat)),
                  ],
                ),
              ),
              Expanded(
                child: switch (state.status) {
                  LoadStatus.loading when state.places.isEmpty => const Padding(
                      padding: EdgeInsets.all(AppSpace.lg),
                      child: SkeletonList(),
                    ),
                  LoadStatus.failure => ErrorView(failure: state.failure!, onRetry: cubit.load),
                  _ when state.places.isEmpty => EmptyState(icon: Icons.search_off_outlined, title: l10n.noResults),
                  _ => ListView.separated(
                      padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.xxl),
                      itemCount: state.places.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpace.md),
                      itemBuilder: (context, i) => PlaceTile(
                        place: state.places[i],
                        onTap: () => context.push('/place/${state.places[i].id}'),
                      ),
                    ),
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(BuildContext context, String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsetsDirectional.only(end: AppSpace.sm),
        child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
      );
}
