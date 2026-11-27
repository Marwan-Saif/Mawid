import 'dart:math';

import 'package:equatable/equatable.dart';

final _random = Random();

/// Made on the device for every new invoice, so sending it twice (offline replay, double tap)
/// returns the same invoice instead of a second one.
String newClientRef([DateTime? nowUtc]) =>
    '${(nowUtc ?? DateTime.now().toUtc()).microsecondsSinceEpoch.toRadixString(36)}-'
    '${_random.nextInt(0x7fffffff).toRadixString(36)}';

enum InvoiceStatus { issued, paid, voided }

enum PaymentMethod { cash, card, transfer }

class InvoiceLine extends Equatable {
  const InvoiceLine({required this.description, required this.qty, required this.unitPrice, this.serviceId});

  final String description;
  final int qty;
  final double unitPrice;
  final String? serviceId;

  double get amount => unitPrice * qty;

  InvoiceLine copyWith({int? qty}) =>
      InvoiceLine(description: description, qty: qty ?? this.qty, unitPrice: unitPrice, serviceId: serviceId);

  @override
  List<Object?> get props => [description, qty, unitPrice, serviceId];
}

class Invoice extends Equatable {
  const Invoice({
    required this.id,
    required this.number,
    required this.customerName,
    required this.lines,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.version,
    this.bookingId,
    this.customerPhone,
    this.staffName,
    this.paymentMethod,
    this.updatedAt,
    this.paidAt,
    this.createdByName,
    this.voidReason,
    this.printUrl,
    this.clientRef,
    this.pendingSync = false,
  });

  final String id;

  /// Null until the server gives it one (created offline).
  final int? number;
  final String? bookingId;
  final String customerName;
  final String? customerPhone;
  final String? staffName;
  final List<InvoiceLine> lines;
  final double subtotal;
  final double discount;
  final double total;
  final String currency;
  final InvoiceStatus status;
  final PaymentMethod? paymentMethod;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? paidAt;
  final String? createdByName;
  final String? voidReason;

  /// Server version for edits: a newer one on the server means someone else saved first.
  final int version;

  /// The printable page (A4 or receipt) with its QR, when the server is real.
  final String? printUrl;
  final String? clientRef;
  final bool pendingSync;

  bool get edited => updatedAt != null;

  Invoice copyWith({InvoiceStatus? status, PaymentMethod? paymentMethod, DateTime? paidAt, bool? pendingSync}) => Invoice(
        id: id,
        number: number,
        bookingId: bookingId,
        customerName: customerName,
        customerPhone: customerPhone,
        staffName: staffName,
        lines: lines,
        subtotal: subtotal,
        discount: discount,
        total: total,
        currency: currency,
        status: status ?? this.status,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        createdAt: createdAt,
        updatedAt: updatedAt,
        paidAt: paidAt ?? this.paidAt,
        createdByName: createdByName,
        voidReason: voidReason,
        version: version,
        printUrl: printUrl,
        clientRef: clientRef,
        pendingSync: pendingSync ?? this.pendingSync,
      );

  @override
  List<Object?> get props => [id, number, status, total, version, pendingSync, lines, discount];
}

/// A new invoice. [clientRef] is made on the device so sending it twice (offline replay) is safe.
class InvoiceDraft extends Equatable {
  const InvoiceDraft({
    required this.customerName,
    required this.lines,
    required this.clientRef,
    this.bookingId,
    this.customerPhone,
    this.discount = 0,
    this.paidWith,
    this.staffName,
  });

  final String? bookingId;
  final String customerName;
  final String? customerPhone;
  final String? staffName;
  final List<InvoiceLine> lines;
  final double discount;
  final PaymentMethod? paidWith;
  final String clientRef;

  double get subtotal => lines.fold(0, (sum, l) => sum + l.amount);

  double get total => (subtotal - discount).clamp(0, double.infinity).toDouble();

  @override
  List<Object?> get props => [bookingId, customerName, customerPhone, lines, discount, paidWith, clientRef];
}
