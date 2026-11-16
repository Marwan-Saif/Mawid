import 'package:equatable/equatable.dart';

enum UserRole { customer, owner }

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

  @override
  List<Object?> get props => [id, phone, name, role, placeId, lang];
}
