import 'dart:async';

/// Fired after a booking is created, moved or cancelled, so Home and My bookings
/// refresh themselves without being rebuilt by the router.
class BookingChanges {
  final _controller = StreamController<void>.broadcast();

  Stream<void> get stream => _controller.stream;

  void notify() => _controller.add(null);
}
