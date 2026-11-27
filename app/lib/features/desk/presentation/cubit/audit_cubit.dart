import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../places/presentation/cubit/home_cubit.dart';
import '../../domain/entities/audit_entry.dart';
import '../../domain/repositories/desk_repository.dart';

class AuditState extends Equatable {
  const AuditState({this.status = LoadStatus.loading, this.entries = const [], this.failure});

  final LoadStatus status;
  final List<AuditEntry> entries;
  final Failure? failure;

  @override
  List<Object?> get props => [status, entries, failure];
}

/// The place's log, or one invoice's history when [entityType] and [entityId] are given.
class AuditCubit extends Cubit<AuditState> {
  AuditCubit(this.repository, {this.entityType, this.entityId}) : super(const AuditState());

  final DeskRepository repository;
  final String? entityType;
  final String? entityId;

  Future<void> load() async {
    if (state.entries.isEmpty) emit(const AuditState());
    final result = await repository.audit(entityType: entityType, entityId: entityId);
    if (isClosed) return;
    result.fold(
      (f) => emit(AuditState(status: LoadStatus.failure, entries: state.entries, failure: f)),
      (list) => emit(AuditState(status: LoadStatus.ready, entries: list)),
    );
  }
}
