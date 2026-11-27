import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/phone.dart';
import '../../../booking/domain/entities/booking.dart';
import '../entities/desk_board.dart';
import '../entities/invoice.dart';
import '../repositories/desk_repository.dart';
import '../services/display_names.dart';

/// Reception scanned a QR or typed a code.
class CheckInByScan implements UseCase<Booking, String> {
  CheckInByScan(this.repository);
  final DeskRepository repository;

  @override
  Future<Either<Failure, Booking>> call(String scanned) {
    final code = checkInCodeFrom(scanned);
    if (code == null) return Future.value(const Left(ValidationFailure('INVALID_CODE')));
    return repository.checkInByCode(code);
  }
}

class AddWalkIn implements UseCase<Booking, WalkInRequest> {
  AddWalkIn(this.repository);
  final DeskRepository repository;

  @override
  Future<Either<Failure, Booking>> call(WalkInRequest r) {
    final phone = normalizePhone(r.customerPhone);
    if (phone == null) return Future.value(const Left(ValidationFailure('INVALID_PHONE')));
    if (r.customerName.trim().isEmpty) return Future.value(const Left(ValidationFailure('VALIDATION')));
    return repository.walkIn(WalkInRequest(
      serviceId: r.serviceId,
      staffId: r.staffId,
      customerName: r.customerName.trim(),
      customerPhone: phone,
    ));
  }
}

/// Same rules as the server, checked first so the desk gets an answer even offline.
class IssueInvoice implements UseCase<Invoice, InvoiceDraft> {
  IssueInvoice(this.repository);
  final DeskRepository repository;

  @override
  Future<Either<Failure, Invoice>> call(InvoiceDraft d) {
    final invalid = validateLines(d.lines, d.discount);
    if (invalid != null) return Future.value(Left(invalid));
    if (d.customerName.trim().isEmpty) return Future.value(const Left(ValidationFailure('CUSTOMER_REQUIRED')));
    return repository.createInvoice(d);
  }
}

class EditInvoiceParams {
  const EditInvoiceParams(this.invoice, this.lines, this.discount);
  final Invoice invoice;
  final List<InvoiceLine> lines;
  final double discount;
}

class EditInvoice implements UseCase<Invoice, EditInvoiceParams> {
  EditInvoice(this.repository);
  final DeskRepository repository;

  @override
  Future<Either<Failure, Invoice>> call(EditInvoiceParams p) {
    if (p.invoice.status == InvoiceStatus.voided) return Future.value(const Left(ValidationFailure('INVOICE_VOID')));
    final invalid = validateLines(p.lines, p.discount);
    if (invalid != null) return Future.value(Left(invalid));
    return repository.updateInvoice(p.invoice, p.lines, p.discount);
  }
}

Failure? validateLines(List<InvoiceLine> lines, double discount) {
  if (lines.isEmpty) return const ValidationFailure('NO_LINES');
  for (final l in lines) {
    if (l.description.trim().isEmpty || l.qty < 1 || l.qty > 99 || l.unitPrice < 0) {
      return const ValidationFailure('VALIDATION');
    }
  }
  final subtotal = lines.fold<double>(0, (s, l) => s + l.amount);
  if (discount < 0 || discount > subtotal) return const ValidationFailure('INVALID_DISCOUNT');
  return null;
}
