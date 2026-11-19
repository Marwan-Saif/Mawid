import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/app_config.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../places/presentation/cubit/home_cubit.dart';
import '../cubit/owner_services_cubit.dart';
import '../widgets/service_form_sheet.dart';

class OwnerServicesPage extends StatelessWidget {
  const OwnerServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final fmt = Fmt.of(context);
    final text = Theme.of(context).textTheme;
    final lang = l10n.localeName;

    return BlocBuilder<OwnerServicesCubit, OwnerServicesState>(
      builder: (context, state) {
        final cubit = context.read<OwnerServicesCubit>();
        final place = state.place?.place;
        return Scaffold(
          appBar: AppBar(title: Text(l10n.navServices)),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => showServiceForm(context, onSave: (d) => cubit.save(d)),
            icon: const Icon(Icons.add),
            label: Text(l10n.addService),
          ),
          body: switch (state.status) {
            LoadStatus.failure => ErrorView(failure: state.failure!, onRetry: cubit.load),
            LoadStatus.loading when state.place == null =>
              const Padding(padding: EdgeInsets.all(AppSpace.lg), child: SkeletonList()),
            _ => ListView(
                padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, 96),
                children: [
                  if (place != null) ...[
                    AppCard(
                      color: c.primarySoft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.link, color: c.primary),
                            const SizedBox(width: AppSpace.sm),
                            Text(l10n.bookingLink, style: text.titleMedium),
                          ]),
                          const SizedBox(height: AppSpace.xs),
                          Text(l10n.bookingLinkHint, style: text.bodyMedium),
                          const SizedBox(height: AppSpace.sm),
                          Row(children: [
                            Expanded(
                              child: SelectableText(
                                '${AppConfig.apiUrl}/b/${place.slug}',
                                style: text.bodyMedium?.copyWith(color: c.primary),
                                textDirection: TextDirection.ltr,
                              ),
                            ),
                            IconButton(
                              tooltip: l10n.copied,
                              icon: const Icon(Icons.copy_outlined),
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(text: '${AppConfig.apiUrl}/b/${place.slug}'));
                                if (context.mounted) showMessage(context, l10n.copied);
                              },
                            ),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.lg),
                  ],
                  for (final s in state.services)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.md),
                      child: AppCard(
                        onTap: () => showServiceForm(context, existing: s, onSave: (d) => cubit.save(d, id: s.id)),
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(s.name(lang), style: text.titleMedium),
                              Text(
                                '${l10n.minutes(fmt.number(s.durationMin))} · '
                                '${s.active ? l10n.activeService : l10n.hiddenService}',
                                style: text.bodyMedium?.copyWith(color: s.active ? null : c.warning),
                              ),
                            ]),
                          ),
                          Text(fmt.money(s.price, place?.currency ?? ''),
                              style: text.titleMedium?.copyWith(color: c.primary)),
                          const SizedBox(width: AppSpace.sm),
                          Icon(Icons.edit_outlined, color: c.textSecondary),
                        ]),
                      ),
                    ),
                ],
              ),
          },
        );
      },
    );
  }
}
