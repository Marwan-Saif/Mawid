import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../storage/local_store.dart';

/// The app language. Arabic (RTL) by default; the choice is remembered.
class LocaleCubit extends Cubit<Locale> {
  LocaleCubit(this._store) : super(Locale(_store.localeCode ?? 'ar'));

  final LocalStore _store;

  bool get isArabic => state.languageCode == 'ar';

  Future<void> setLocale(String code) async {
    if (code == state.languageCode) return;
    emit(Locale(code));
    await _store.saveLocale(code);
  }

  Future<void> toggle() => setLocale(isArabic ? 'en' : 'ar');
}
