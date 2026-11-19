import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'config/brand.dart';
import 'core/l10n/app_localizations.dart';
import 'core/locale/locale_cubit.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/cubit/session_cubit.dart';
import 'injection_container.dart';

class MawidApp extends StatefulWidget {
  const MawidApp({super.key, this.brand = Brand.mawid});

  final Brand brand;

  @override
  State<MawidApp> createState() => _MawidAppState();
}

class _MawidAppState extends State<MawidApp> {
  late final SessionCubit _session = sl<SessionCubit>()..restore();
  late final GoRouter _router = buildRouter(_session);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _session),
        BlocProvider.value(value: sl<LocaleCubit>()),
      ],
      child: BlocBuilder<LocaleCubit, Locale>(
        builder: (context, locale) => MaterialApp.router(
          onGenerateTitle: (_) => widget.brand.name(locale),
          debugShowCheckedModeBanner: false,
          routerConfig: _router,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(widget.brand, locale),
          darkTheme: AppTheme.dark(widget.brand, locale),
          themeMode: ThemeMode.system,
        ),
      ),
    );
  }
}
