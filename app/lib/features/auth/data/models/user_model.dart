import '../../domain/entities/app_user.dart';

/// Adapter between the API's JSON and the domain entity.
class UserModel {
  const UserModel(this.json);

  final Map<String, dynamic> json;

  static String roleCode(UserRole role) => switch (role) {
        UserRole.owner => 'OWNER',
        UserRole.reception => 'RECEPTION',
        UserRole.customer => 'CUSTOMER',
      };

  factory UserModel.fromEntity(AppUser u) => UserModel({
        'id': int.tryParse(u.id) ?? u.id,
        'phone': u.phone,
        'name': u.name,
        'role': roleCode(u.role),
        'placeId': u.placeId == null ? null : (int.tryParse(u.placeId!) ?? u.placeId),
        'lang': u.lang,
      });

  AppUser toEntity() => AppUser(
        id: json['id'].toString(),
        phone: json['phone'] as String,
        name: json['name'] as String?,
        role: switch (json['role']) {
          'OWNER' => UserRole.owner,
          'RECEPTION' => UserRole.reception,
          _ => UserRole.customer,
        },
        placeId: json['placeId']?.toString(),
        lang: (json['lang'] as String?) ?? 'ar',
      );
}
