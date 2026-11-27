import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../booking/domain/entities/booking.dart';
import '../../../places/presentation/cubit/home_cubit.dart';
import '../../domain/entities/desk_board.dart';
import '../../domain/repositories/desk_repository.dart';
import '../../domain/usecases/desk_usecases.dart';

/// A one-off thing to tell the person at the desk (a snackbar), with a counter so the same
/// message twice still shows twice.
class DeskNotice extends Equatable {
  const DeskNotice(this.seq, {this.checkedIn, this.called, this.failure});

  final int seq;
  final Booking? checkedIn;
  final Booking? called;
  final Failure? failure;

  @override
  List<Object?> get props => [seq];
}

class DeskState extends Equatable {
  const DeskState({
    this.status = LoadStatus.loading,
    this.board,
    this.failure,
    this.busyId,
    this.sync = const SyncStatus(),
    this.notice,
    this.simulatingOffline = false,
  });

  final LoadStatus status;
  final DeskBoard? board;
  final Failure? failure;

  /// Booking or staff id with a request in flight (its buttons show a spinner).
  final String? busyId;
  final SyncStatus sync;
  final DeskNotice? notice;
  final bool simulatingOffline;

  DeskState copyWith({
    LoadStatus? status,
    DeskBoard? board,
    Failure? Function()? failure,
    String? Function()? busyId,
    SyncStatus? sync,
    DeskNotice? notice,
    bool? simulatingOffline,
  }) =>
      DeskState(
        status: status ?? this.status,
        board: board ?? this.board,
        failure: failure != null ? failure() : this.failure,
        busyId: busyId != null ? busyId() : this.busyId,
        sync: sync ?? this.sync,
        notice: notice ?? this.notice,
        simulatingOffline: simulatingOffline ?? this.simulatingOffline,
      );

  @override
  List<Object?> get props => [status, board, failure, busyId, sync, notice, simulatingOffline];
}

/// The live front desk. Reloads every few seconds (other desks, the customer's own check-in and
/// the doctor all change the queue), and after every action.
class DeskCubit extends Cubit<DeskState> {
  DeskCubit({
    required this.repository,
    required this.checkInByScan,
    required this.addWalkIn,
    this.refreshEvery = const Duration(seconds: 10),
  }) : super(DeskState(sync: repository.currentSync)) {
    _syncSub = repository.syncStatus.listen(_onSync);
    if (refreshEvery > Duration.zero) {
      _timer = Timer.periodic(refreshEvery, (_) => load(silent: true));
    }
  }

  final DeskRepository repository;
  final CheckInByScan checkInByScan;
  final AddWalkIn addWalkIn;
  final Duration refreshEvery;
  late final StreamSubscription<SyncStatus> _syncSub;
  Timer? _timer;
  int _seq = 0;
  bool _loading = false;

  Future<void> load({bool silent = false}) async {
    if (_loading) return;
    _loading = true;
    if (!silent || state.board == null) emit(state.copyWith(status: LoadStatus.loading));
    final result = await repository.board();
    _loading = false;
    if (isClosed) return;
    result.fold(
      (f) => emit(state.copyWith(status: LoadStatus.failure, failure: () => f)),
      (b) => emit(state.copyWith(status: LoadStatus.ready, board: b, failure: () => null)),
    );
  }

  Future<void> checkIn(QueueEntry e) => _act(e.id, () => repository.checkIn(e.booking), checkedIn: true);

  Future<void> call(QueueEntry e) {
    final room = state.board?.staffById(e.booking.staffId)?.room;
    return _act(e.id, () => repository.call(e.booking, room: room), called: true);
  }

  Future<void> finish(QueueEntry e) => _act(e.id, () => repository.finish(e.booking));

  Future<void> noShow(QueueEntry e) => _act(e.id, () => repository.noShow(e.booking));

  Future<void> setPresence(DeskStaff s, StaffPresence p) async {
    emit(state.copyWith(busyId: () => s.id));
    final result = await repository.setPresence(s, p);
    if (isClosed) return;
    result.fold(
      (f) => emit(state.copyWith(busyId: () => null, notice: DeskNotice(++_seq, failure: f))),
      (updated) {
        final board = state.board;
        emit(state.copyWith(
          busyId: () => null,
          board: board?.copyWith(
              staff: [for (final x in board.staff) x.id == updated.id ? x.copyWith(presence: updated.presence) : x]),
        ));
      },
    );
    await load(silent: true);
  }

  /// Returns null on success so the scan page can close itself.
  Future<Failure?> scan(String code) async {
    final result = await checkInByScan(code);
    if (isClosed) return null;
    return result.fold((f) => f, (b) {
      emit(state.copyWith(notice: DeskNotice(++_seq, checkedIn: b)));
      load(silent: true);
      return null;
    });
  }

  Future<Failure?> walkIn(WalkInRequest r) async {
    final result = await addWalkIn(r);
    if (isClosed) return null;
    return result.fold((f) => f, (b) {
      emit(state.copyWith(notice: DeskNotice(++_seq, checkedIn: b)));
      load(silent: true);
      return null;
    });
  }

  void toggleSimulatedOffline() {
    final next = !state.simulatingOffline;
    repository.simulateOffline(next);
    emit(state.copyWith(simulatingOffline: next));
    load(silent: true);
  }

  Future<void> _act(String id, Future<Either<Failure, Booking>> Function() run,
      {bool checkedIn = false, bool called = false}) async {
    emit(state.copyWith(busyId: () => id));
    final result = await run();
    if (isClosed) return;
    result.fold(
      (f) => emit(state.copyWith(busyId: () => null, notice: DeskNotice(++_seq, failure: f))),
      (b) {
        final board = state.board;
        emit(state.copyWith(
          busyId: () => null,
          board: board?.copyWith(queue: [for (final q in board.queue) q.id == b.id ? q.copyWith(booking: b) : q]),
          notice: checkedIn || called
              ? DeskNotice(++_seq, checkedIn: checkedIn ? b : null, called: called ? b : null)
              : null,
        ));
      },
    );
    await load(silent: true);
  }

  void _onSync(SyncStatus s) {
    if (isClosed) return;
    final cameBack = !state.sync.online && s.online;
    emit(state.copyWith(sync: s));
    if (cameBack) load(silent: true);
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _syncSub.cancel();
    return super.close();
  }
}
