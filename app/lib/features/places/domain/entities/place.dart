import 'package:equatable/equatable.dart';

enum PlaceCategory { clinic, dental, salon, spa }

/// Wall-clock time of day at the place, e.g. opening at 10:00.
class TimeOfDayHM extends Equatable {
  const TimeOfDayHM(this.hour, this.minute);

  /// Parses "10:00" or "10:00:00".
  factory TimeOfDayHM.parse(String value) {
    final parts = value.split(':');
    return TimeOfDayHM(int.parse(parts[0]), int.parse(parts[1]));
  }

  final int hour;
  final int minute;

  int get minutesOfDay => hour * 60 + minute;

  String toHHmm() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  List<Object?> get props => [hour, minute];
}

class Place extends Equatable {
  const Place({
    required this.id,
    required this.slug,
    required this.nameAr,
    required this.nameEn,
    required this.category,
    required this.areaAr,
    required this.areaEn,
    required this.rating,
    required this.reviewsCount,
    required this.distanceKm,
    required this.timezone,
    required this.currency,
    required this.phone,
    required this.openTime,
    required this.closeTime,
    required this.closedDays,
  });

  final String id;
  final String slug;
  final String nameAr;
  final String nameEn;
  final PlaceCategory category;
  final String areaAr;
  final String areaEn;
  final double rating;
  final int reviewsCount;
  final double distanceKm;

  /// IANA zone, e.g. Asia/Dubai. All booking times are stored in UTC and shown in this zone.
  final String timezone;
  final String currency;
  final String? phone;
  final TimeOfDayHM openTime;
  final TimeOfDayHM closeTime;

  /// ISO weekday numbers (DateTime.monday = 1 ... DateTime.sunday = 7) the place is closed.
  final Set<int> closedDays;

  String name(String lang) => lang == 'ar' ? nameAr : nameEn;
  String area(String lang) => lang == 'ar' ? areaAr : areaEn;

  bool isClosedOn(int weekday) => closedDays.contains(weekday);

  @override
  List<Object?> get props => [id, slug, nameAr, nameEn, rating, closedDays];
}

class PlaceService extends Equatable {
  const PlaceService({
    required this.id,
    required this.placeId,
    required this.nameAr,
    required this.nameEn,
    required this.durationMin,
    required this.price,
    required this.active,
  });

  final String id;
  final String placeId;
  final String nameAr;
  final String nameEn;
  final int durationMin;
  final double price;
  final bool active;

  String name(String lang) => lang == 'ar' ? nameAr : nameEn;

  @override
  List<Object?> get props => [id, nameAr, nameEn, durationMin, price, active];
}

class StaffMember extends Equatable {
  const StaffMember({
    required this.id,
    required this.name,
    required this.titleAr,
    required this.titleEn,
    required this.serviceIds,
    required this.daysOff,
  });

  final String id;
  final String name;
  final String titleAr;
  final String titleEn;
  final Set<String> serviceIds;

  /// ISO weekday numbers.
  final Set<int> daysOff;

  String title(String lang) => lang == 'ar' ? titleAr : titleEn;

  bool doesService(String serviceId) => serviceIds.contains(serviceId);

  @override
  List<Object?> get props => [id, name, serviceIds, daysOff];
}

class Review extends Equatable {
  const Review({required this.id, required this.author, required this.rating, required this.text, required this.createdAt});

  final String id;
  final String author;
  final int rating;
  final String text;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id];
}

class PlaceDetails extends Equatable {
  const PlaceDetails({required this.place, required this.services, required this.staff, required this.reviews});

  final Place place;
  final List<PlaceService> services;
  final List<StaffMember> staff;
  final List<Review> reviews;

  List<StaffMember> staffFor(String serviceId) => staff.where((s) => s.doesService(serviceId)).toList();

  PlaceService? serviceById(String id) {
    for (final s in services) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  List<Object?> get props => [place, services, staff, reviews];
}
