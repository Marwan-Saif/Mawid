import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/locale/locale_cubit.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/cubit/session_cubit.dart';
import '../../../booking/presentation/widgets/booking_details_sheet.dart';
import '../cubit/home_cubit.dart';
import '../widgets/category_row.dart';
import '../widgets/next_appointment_card.dart';
import '../widgets/place_tile.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final user = context.select((SessionCubit s) => s.state.user);
    final hour = DateTime.now().hour;

    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<HomeCubit, HomeState>(
          builder: (context, state) {
            return RefreshIndicator(
              onRefresh: () => context.read<HomeCubit>().load(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.xxl),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(hour < 12 ? l10n.goodMorning : l10n.goodEvening, style: text.bodyMedium),
                            Text(user?.name ?? l10n.guest, style: text.headlineSmall),
                          ],
                        ),
                      ),
                      _RoundIconButton(
                        tooltip: l10n.language,
                        onPressed: () => context.read<LocaleCubit>().toggle(),
                        child: Text(l10n.localeName == 'ar' ? 'EN' : 'ع',
                            style: text.labelLarge?.copyWith(color: c.textPrimary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Semantics(
                    button: true,
                    label: l10n.searchHint,
                    child: Material(
                      color: c.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                        side: BorderSide(color: c.border, width: 1.5),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                        onTap: () => context.go('/explore?focus=1'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: 14),
                          child: Row(
                            children: [
                              Icon(Icons.search, color: c.textSecondary),
                              const SizedBox(width: AppSpace.md),
                              Expanded(child: Text(l10n.searchHint, style: text.bodyMedium)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (state.next != null) ...[
                    const SizedBox(height: AppSpace.lg),
                    NextAppointmentCard(
                      booking: state.next!,
                      onDetails: () => showBookingDetails(context, state.next!)
                          .then((_) => context.mounted ? context.read<HomeCubit>().load() : null),
                      onReschedule: state.next!.canChange(DateTime.now())
                          ? () => context.push('/bookings/${state.next!.id}/reschedule', extra: state.next)
                              .then((_) => context.mounted ? context.read<HomeCubit>().load() : null)
                          : null,
                    ),
                  ],
                  SectionHeader(title: l10n.categories),
                  CategoryRow(onSelected: (cat) => context.go('/explore?category=${cat.name}')),
                  SectionHeader(
                    title: l10n.nearYou,
                    actionLabel: l10n.seeAll,
                    onAction: () => context.go('/explore'),
                  ),
                  switch (state.status) {
                    LoadStatus.loading when state.places.isEmpty => const SkeletonList(count: 3),
                    LoadStatus.failure => ErrorView(
                        failure: state.failure!,
                        onRetry: () => context.read<HomeCubit>().load(),
                      ),
                    _ => Column(
                        children: [
                          for (final p in state.places.take(4))
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpace.md),
                              child: PlaceTile(place: p, onTap: () => context.push('/place/${p.id}')),
                            ),
                        ],
                      ),
                  },
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.child, required this.onPressed, required this.tooltip});

  final Widget child;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(color: c.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: onPressed,
          child: SizedBox.square(dimension: AppSpace.touch, child: Center(child: child)),
        ),
      ),
    );
  }
}
