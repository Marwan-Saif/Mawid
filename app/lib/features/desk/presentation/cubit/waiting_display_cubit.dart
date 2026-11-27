import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/waiting_display.dart';
import '../../domain/repositories/desk_repository.dart';

class WaitingDisplayState extends Equatable {
  const WaitingDisplayState({this.display, this.online = true, this.lastUpdate, this.announce});

  final WaitingDisplay? display;
  final bool online;
  final DateTime? lastUpdate;

  /// A call to speak out loud now (set once per new call or repeat).
  final DisplayCall? announce;

  @override
  List<Object?> get props => [display, online, lastUpdate, announce];
}

/// Polls the public waiting-room data every few seconds. Keeps the last screen when the
/// network drops, and flags each new call (or repeat) once so the page speaks it.
class WaitingDisplayCubit extends Cubit<WaitingDisplayState> {
  WaitingDisplayCubit(this.repository, this.slug, {this.every = const Duration(seconds: 3), DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(const WaitingDisplayState());

  final DeskRepository repository;
  final String slug;
  final Duration every;
  final DateTime Function() _now;
  Timer? _timer;
  String? _lastSeq;
  bool _first = true;

  Future<void> start() async {
    await poll();
    if (every > Duration.zero) _timer = Timer.periodic(every, (_) => poll());
  }

  Future<void> poll() async {
    final result = await repository.display(slug);
    if (isClosed) return;
    result.fold(
      (_) => emit(WaitingDisplayState(display: state.display, online: false, lastUpdate: state.lastUpdate)),
      (d) {
        final call = d.lastCall;
        DisplayCall? speak;
        if (call != null && call.seq != _lastSeq) {
          // On first load only speak a call that just happened, not one from an hour ago.
          final fresh = !_first || _now().toUtc().difference(call.at).inSeconds.abs() < 20;
          if (fresh) speak = call;
          _lastSeq = call.seq;
        }
        _first = false;
        emit(WaitingDisplayState(display: d, online: true, lastUpdate: _now().toUtc(), announce: speak));
      },
    );
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
