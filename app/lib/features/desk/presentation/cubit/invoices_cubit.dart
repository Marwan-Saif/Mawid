import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../places/presentation/cubit/home_cubit.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/repositories/desk_repository.dart';
import '../../domain/usecases/desk_usecases.dart';

class InvoicesState extends Equatable {
  const InvoicesState({this.status = LoadStatus.loading, this.invoices = const [], this.failure, this.busy = false});

  final LoadStatus status;
  final List<Invoice> invoices;
  final Failure? failure;
  final bool busy;

  InvoicesState copyWith({LoadStatus? status, List<Invoice>? invoices, Failure? Function()? failure, bool? busy}) =>
      InvoicesState(
        status: status ?? this.status,
        invoices: invoices ?? this.invoices,
        failure: failure != null ? failure() : this.failure,
        busy: busy ?? this.busy,
      );

  @override
  List<Object?> get props => [status, invoices, failure, busy];
}

class InvoicesCubit extends Cubit<InvoicesState> {
  InvoicesCubit({required this.repository, required this.issueInvoice, required this.editInvoice})
      : super(const InvoicesState());

  final DeskRepository repository;
  final IssueInvoice issueInvoice;
  final EditInvoice editInvoice;

  Future<void> load() async {
    if (state.invoices.isEmpty) emit(state.copyWith(status: LoadStatus.loading));
    final result = await repository.invoices();
    if (isClosed) return;
    result.fold(
      (f) => emit(state.copyWith(status: LoadStatus.failure, failure: () => f)),
      (list) => emit(state.copyWith(status: LoadStatus.ready, invoices: list, failure: () => null)),
    );
  }

  Future<(Invoice?, Failure?)> issue(InvoiceDraft draft) =>
      _run(() => issueInvoice(draft), (inv) => [inv, ...state.invoices.where((i) => i.id != inv.id)]);

  Future<(Invoice?, Failure?)> edit(Invoice inv, List<InvoiceLine> lines, double discount) async {
    final result = await _run(() => editInvoice(EditInvoiceParams(inv, lines, discount)), _replace);
    if (result.$2?.code == 'STALE_INVOICE' || result.$2?.code == 'STALE') await load();
    return result;
  }

  Future<(Invoice?, Failure?)> pay(Invoice inv, PaymentMethod m) => _run(() => repository.payInvoice(inv, m), _replace);

  Future<(Invoice?, Failure?)> voidIt(Invoice inv, String reason) =>
      _run(() => repository.voidInvoice(inv, reason), _replace);

  List<Invoice> _replace(Invoice inv) => [for (final i in state.invoices) i.id == inv.id ? inv : i];

  /// (the saved invoice, null) or (null, why not).
  Future<(Invoice?, Failure?)> _run(
    Future<Either<Failure, Invoice>> Function() call,
    List<Invoice> Function(Invoice) apply,
  ) async {
    emit(state.copyWith(busy: true));
    final result = await call();
    if (isClosed) return (null, null);
    return result.fold<(Invoice?, Failure?)>(
      (f) {
        emit(state.copyWith(busy: false));
        return (null, f);
      },
      (inv) {
        emit(state.copyWith(busy: false, invoices: apply(inv), status: LoadStatus.ready));
        return (inv, null);
      },
    );
  }
}
