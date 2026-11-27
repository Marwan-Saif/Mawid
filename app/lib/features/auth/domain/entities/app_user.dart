import 'package:equatable/equatable.dart';

/// Customer books; owner runs the place; reception runs the front desk of one place.
enum UserRole { customer, owner, reception }

class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.phone,
    required this.role,
    this.name,
    this.placeId,
    this.lang = 'ar',
  });

  final String id;
  final String phone;
  final String? name;
  final UserRole role;

  /// For owners: the place they manage.
  final String? placeId;
  final String lang;

  bool get isOwner => role == UserRole.owner;

  bool get isReception => role == UserRole.reception;

  /// Works at a place (owner or front desk): sees the desk, not the customer app.
  bool get isStaff => isOwner || isReception;

  @override
  List<Object?> get props => [id, phone, name, role, placeId, lang];
}
