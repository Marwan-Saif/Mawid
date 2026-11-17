import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/app_config.dart';
import '../../../../config/brand.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/l10n/failure_messages.dart';
import '../../../../core/locale/locale_cubit.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/entities/app_user.dart';
import '../cubit/login_cubit.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final _phone = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context);

    return BlocConsumer<LoginCubit, LoginState>(
      listener: (context, state) {
        // Only from this screen: a "resend" on the OTP screen must not push a second one.
        if (state.status == LoginStatus.codeSent && (ModalRoute.of(context)?.isCurrent ?? false)) {
          context.push('/welcome/otp');
        }
      },
      builder: (context, state) {
        final error = state.status == LoginStatus.failure && state.phone == null ? state.failure : null;
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.xl),
              children: [
                Row(
                  children: [
                    Text(Brand.mawid.name(locale),
                        style: text.titleLarge?.copyWith(color: c.primary, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: () => context.read<LocaleCubit>().toggle(),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(AppSpace.touch, AppSpace.touch)),
                      child: Text(locale.languageCode == 'ar' ? 'EN' : 'ع'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.xxl),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(AppRadius.lg)),
                  child: Icon(Icons.event_available_outlined, color: c.onPrimary, size: 36),
                ),
                const SizedBox(height: AppSpace.xl),
                Text(l10n.welcomeTitle, style: text.headlineSmall),
                const SizedBox(height: AppSpace.sm),
                Text(l10n.welcomeSubtitle, style: text.bodyLarge?.copyWith(color: c.textSecondary)),
                const SizedBox(height: AppSpace.xxl),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  decoration: InputDecoration(
                    labelText: l10n.phoneLabel,
                    hintText: '+971 50 123 4567',
                    prefixIcon: const Icon(Icons.phone_iphone_outlined),
                    errorText: error?.message(l10n),
                  ),
                  onSubmitted: (v) => context.read<LoginCubit>().sendCode(v),
                ),
                const SizedBox(height: AppSpace.lg),
                PrimaryButton(
                  label: l10n.continueLabel,
                  loading: state.isLoading && state.busyRole == null,
                  onPressed: () => context.read<LoginCubit>().sendCode(_phone.text),
                ),
                if (AppConfig.demoMode) ...[
                  const SizedBox(height: AppSpace.xl),
                  Row(children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                      child: Text(l10n.or, style: text.bodyMedium),
                    ),
                    const Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: AppSpace.xl),
                  _DemoButton(
                    icon: Icons.person_outline,
                    label: l10n.tryAsCustomer,
                    busy: state.isLoading && state.busyRole == UserRole.customer,
                    onPressed: () => context.read<LoginCubit>().tryDemo(UserRole.customer),
                  ),
                  const SizedBox(height: AppSpace.md),
                  _DemoButton(
                    icon: Icons.storefront_outlined,
                    label: l10n.tryAsOwner,
                    busy: state.isLoading && state.busyRole == UserRole.owner,
                    onPressed: () => context.read<LoginCubit>().tryDemo(UserRole.owner),
                  ),
                  const SizedBox(height: AppSpace.md),
                  Text(l10n.demoHint, style: text.bodyMedium, textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DemoButton extends StatelessWidget {
  const _DemoButton({required this.icon, required this.label, required this.busy, required this.onPressed});

  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(icon),
      label: Text(label),
    );
  }
}
