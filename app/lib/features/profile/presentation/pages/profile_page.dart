import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/app_config.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/locale/locale_cubit.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../auth/presentation/cubit/session_cubit.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final user = context.select((SessionCubit s) => s.state.user);
    final locale = context.watch<LocaleCubit>().state;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profile)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.lg),
        children: [
          AppCard(
            child: Row(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: c.primarySoft,
                child: Icon(user?.isOwner == true ? Icons.storefront_outlined : Icons.person_outline, color: c.primary),
              ),
              const SizedBox(width: AppSpace.lg),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user?.name ?? '—', style: text.titleMedium),
                  Text(user?.phone ?? '', style: text.bodyMedium, textDirection: TextDirection.ltr),
                  Text(
                      user?.isOwner == true
                          ? l10n.roleOwner
                          : user?.isReception == true
                              ? l10n.roleReception
                              : l10n.roleCustomer,
                      style: text.bodyMedium),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: AppSpace.xl),
          Text(l10n.language, style: text.titleMedium),
          const SizedBox(height: AppSpace.sm),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'ar', label: Text('العربية')),
              ButtonSegment(value: 'en', label: Text('English')),
            ],
            selected: {locale.languageCode},
            onSelectionChanged: (s) => context.read<LocaleCubit>().setLocale(s.first),
          ),
          const SizedBox(height: AppSpace.xl),
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.dns_outlined),
              title: Text(l10n.dataSource),
              subtitle: Text(
                AppConfig.backend == BackendKind.api ? '${l10n.dataSourceApi} · ${AppConfig.apiUrl}' : l10n.dataSourceFake,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          OutlinedButton.icon(
            onPressed: () => context.read<SessionCubit>().signOut(),
            style: OutlinedButton.styleFrom(foregroundColor: c.danger),
            icon: const Icon(Icons.logout),
            label: Text(l10n.logout),
          ),
        ],
      ),
    );
  }
}
