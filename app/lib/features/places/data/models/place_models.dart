import '../../domain/entities/place.dart';

/// JSON ⇄ entity adapters for the places API. One factory per shape keeps parsing in one spot.
class PlaceModels {
  const PlaceModels._();

  static const _days = {
    'MONDAY': DateTime.monday,
    'TUESDAY': DateTime.tuesday,
    'WEDNESDAY': DateTime.wednesday,
    'THURSDAY': DateTime.thursday,
    'FRIDAY': DateTime.friday,
    'SATURDAY': DateTime.saturday,
    'SUNDAY': DateTime.sunday,
  };

  static Set<int> days(dynamic list) =>
      (list as List? ?? const []).map((d) => _days[d.toString()]).whereType<int>().toSet();

  static PlaceCategory category(String value) => switch (value) {
        'CLINIC' => PlaceCategory.clinic,
        'DENTAL' => PlaceCategory.dental,
        'SPA' => PlaceCategory.spa,
        _ => PlaceCategory.salon,
      };

  static String categoryCode(PlaceCategory c) => c.name.toUpperCase();

  static Place place(Map<String, dynamic> j) => Place(
        id: j['id'].toString(),
        slug: j['slug'] as String,
        nameAr: j['nameAr'] as String,
        nameEn: j['nameEn'] as String,
        category: category(j['category'] as String),
        areaAr: (j['areaAr'] as String?) ?? '',
        areaEn: (j['areaEn'] as String?) ?? '',
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
        reviewsCount: (j['reviewsCount'] as num?)?.toInt() ?? 0,
        distanceKm: (j['distanceKm'] as num?)?.toDouble() ?? 0,
        timezone: j['timezone'] as String,
        currency: j['currency'] as String,
        phone: j['phone'] as String?,
        openTime: TimeOfDayHM.parse(j['openTime'] as String),
        closeTime: TimeOfDayHM.parse(j['closeTime'] as String),
        closedDays: days(j['closedDays']),
      );

  static PlaceService service(Map<String, dynamic> j) => PlaceService(
        id: j['id'].toString(),
        placeId: j['placeId'].toString(),
        nameAr: j['nameAr'] as String,
        nameEn: j['nameEn'] as String,
        durationMin: (j['durationMin'] as num).toInt(),
        price: (j['price'] as num).toDouble(),
        active: (j['active'] as bool?) ?? true,
      );

  static StaffMember staff(Map<String, dynamic> j) => StaffMember(
        id: j['id'].toString(),
        name: j['name'] as String,
        titleAr: (j['titleAr'] as String?) ?? '',
        titleEn: (j['titleEn'] as String?) ?? '',
        serviceIds: (j['serviceIds'] as List? ?? const []).map((e) => e.toString()).toSet(),
        daysOff: days(j['daysOff']),
      );

  static Review review(Map<String, dynamic> j) => Review(
        id: j['id'].toString(),
        author: j['authorName'] as String,
        rating: (j['rating'] as num).toInt(),
        text: (j['text'] as String?) ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  static PlaceDetails details(Map<String, dynamic> j) => PlaceDetails(
        place: place(Map<String, dynamic>.from(j['place'] as Map)),
        services: _list(j['services']).map(service).toList(),
        staff: _list(j['staff']).map(staff).toList(),
        reviews: _list(j['reviews']).map(review).toList(),
      );

  static List<Map<String, dynamic>> _list(dynamic v) =>
      (v as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
}
