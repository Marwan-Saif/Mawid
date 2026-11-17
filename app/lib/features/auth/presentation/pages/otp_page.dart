import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/app_config.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/l10n/failure_messages.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/primary_button.dart';
import '../cubit/login_cubit.dart';

class OtpPage extends StatefulWidget {
  const OtpPage({super.key});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final _code = TextEditingController();
  final _name = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  void _submit() => context.read<LoginCubit>().verify(_code.text, name: _name.text.trim().isEmpty ? null : _name.text);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return BlocBuilder<LoginCubit, LoginState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.xl),
              children: [
                Text(l10n.otpTitle, style: text.headlineSmall),
                const SizedBox(height: AppSpace.sm),
                Text(
                  l10n.otpSentTo('\u2066${state.phone ?? ''}\u2069'), // keep the number LTR inside Arabic text
                  style: text.bodyLarge,
                ),
                const SizedBox(height: AppSpace.xl),
                TextField(
                  controller: _code,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: text.headlineSmall?.copyWith(letterSpacing: 12),
                  decoration: InputDecoration(
                    labelText: l10n.otpLabel,
                    counterText: '',
                    helperText: AppConfig.demoMode ? l10n.demoHint : null,
                    errorText: state.status == LoginStatus.failure ? state.failure?.message(l10n) : null,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpace.lg),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  decoration: InputDecoration(labelText: l10n.yourName),
                ),
                const SizedBox(height: AppSpace.xl),
                PrimaryButton(label: l10n.verify, loading: state.isLoading, onPressed: _submit),
                const SizedBox(height: AppSpace.sm),
                TextButton(
                  onPressed: state.isLoading || state.phone == null
                      ? null
                      : () => context.read<LoginCubit>().sendCode(state.phone!),
                  child: Text(l10n.resend),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
