import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mawid/core/error/failures.dart';
import 'package:mawid/features/booking/domain/entities/booking.dart';
import 'package:mawid/features/booking/domain/entities/time_slot.dart';
import 'package:mawid/features/booking/domain/usecases/create_booking.dart';
import 'package:mawid/features/booking/domain/usecases/get_available_slots.dart';
import 'package:mawid/features/booking/domain/usecases/reschedule_booking.dart';
import 'package:mawid/features/booking/presentation/bloc/booking_bloc.dart';
import 'package:mawid/features/places/domain/entities/place.dart';
import 'package:mawid/features/places/domain/usecases/get_place_details.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/test_setup.dart';

class MockGetSlots extends Mock implements GetAvailableSlots {}

class MockCreateBooking extends Mock implements CreateBooking {}

class MockGetPlaceDetails extends Mock implements GetPlaceDetails {}

class MockReschedule extends Mock implements RescheduleBooking {}

void main() {
  late MockGetSlots getSlots;
  late MockCreateBooking createBooking;
  late MockGetPlaceDetails getDetails;
  late MockReschedule reschedule;

  final now = DateTime.utc(2026, 11, 5, 4); // 08:00 in Dubai, Thursday
  final slot = TimeSlot(startAt: DateTime.utc(2026, 11, 5, 9), freeStaffIds: const ['7']);
  const details = PlaceDetails(
    place: Place(
      id: '1',
      slug: 'lamsa-salon',
      nameAr: 'صالون لمسة',
      nameEn: 'Lamsa Salon',
      category: PlaceCategory.salon,
      areaAr: '',
      areaEn: '',
      rating: 4.8,
      reviewsCount: 10,
      distanceKm: 1,
      timezone: 'Asia/Dubai',
      currency: 'AED',
      phone: null,
      openTime: TimeOfDayHM(10, 0),
      closeTime: TimeOfDayHM(22, 0),
      closedDays: {},
    ),
    services: [
      PlaceService(id: '2', placeId: '1', nameAr: 'قص', nameEn: 'Cut', durationMin: 45, price: 120, active: true),
    ],
    staff: [
      StaffMember(id: '7', name: 'نورا', titleAr: '', titleEn: '', serviceIds: {'2'}, daysOff: {}),
    ],
    reviews: [],
  );

  setUpAll(() async {
    await initTestEnvironment();
    registerFallbackValue(SlotsParams(placeId: '1', serviceId: '2', day: DateTime.utc(2026)));
    registerFallbackValue(BookingRequest(placeId: '1', serviceId: '2', startAt: DateTime.utc(2026)));
  });

  setUp(() {
    getSlots = MockGetSlots();
    createBooking = MockCreateBooking();
    getDetails = MockGetPlaceDetails();
    reschedule = MockReschedule();
    when(() => getSlots(any())).thenAnswer((_) async => Right([slot]));
  });

  BookingBloc build() => BookingBloc(getSlots, createBooking,
      getPlaceDetails: getDetails, rescheduleBooking: reschedule, now: () => now);

  blocTest<BookingBloc, BookingState>(
    'starts on the first open day at the place and loads its slots',
    build: build,
    act: (bloc) => bloc.add(const BookingStarted(placeId: '1', serviceId: '2', details: details)),
    verify: (bloc) {
      expect(bloc.state.status, Status.ready);
      expect(bloc.state.day, DateTime.utc(2026, 11, 5));
      expect(bloc.state.days, hasLength(14));
      expect(bloc.state.slots, [slot]);
    },
  );

  blocTest<BookingBloc, BookingState>(
    'emits submitting then success with the saved booking',
    build: () {
      when(() => createBooking(any())).thenAnswer((_) async => Right(tBooking()));
      return build();
    },
    seed: () => BookingState(status: Status.ready, details: details, service: details.services.first, selectedSlot: slot),
    act: (bloc) => bloc.add(const BookingConfirmed()),
    expect: () => [
      isA<BookingState>().having((s) => s.status, 'status', Status.submitting),
      isA<BookingState>()
          .having((s) => s.status, 'status', Status.success)
          .having((s) => s.booking, 'booking', tBooking()),
    ],
  );

  blocTest<BookingBloc, BookingState>(
    'emits failure when the slot is already taken, then refreshes the grid',
    build: () {
      when(() => createBooking(any())).thenAnswer((_) async => const Left(SlotTakenFailure()));
      return build();
    },
    seed: () => BookingState(
      status: Status.ready,
      details: details,
      service: details.services.first,
      day: DateTime.utc(2026, 11, 5),
      selectedSlot: slot,
    ),
    act: (bloc) => bloc.add(const BookingConfirmed()),
    expect: () => [
      isA<BookingState>().having((s) => s.status, 'status', Status.submitting),
      isA<BookingState>()
          .having((s) => s.failure, 'failure', isA<SlotTakenFailure>())
          .having((s) => s.selectedSlot, 'selection cleared', isNull),
      isA<BookingState>().having((s) => s.slotsLoading, 'reloading', isTrue),
      isA<BookingState>().having((s) => s.slotsLoading, 'reloaded', isFalse),
      isA<BookingState>().having((s) => s.status, 'status', Status.ready),
    ],
    verify: (_) => verify(() => getSlots(any())).called(1),
  );

  blocTest<BookingBloc, BookingState>(
    '"anyone available" sends no staff id',
    build: () {
      when(() => createBooking(any())).thenAnswer((_) async => Right(tBooking()));
      return build();
    },
    seed: () => BookingState(status: Status.ready, details: details, service: details.services.first, selectedSlot: slot),
    act: (bloc) => bloc.add(const BookingConfirmed()),
    verify: (_) {
      final req = verify(() => createBooking(captureAny())).captured.single as BookingRequest;
      expect(req.staffId, isNull);
      expect(req.startAt, slot.startAt);
    },
  );
}
