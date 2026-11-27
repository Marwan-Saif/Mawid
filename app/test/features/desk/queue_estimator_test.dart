import 'package:flutter_test/flutter_test.dart';
import 'package:mawid/features/desk/domain/services/display_names.dart';
import 'package:mawid/features/desk/domain/services/queue_estimator.dart';

/// Same cases as the API's QueueEstimatorTest, so the demo and the server agree.
void main() {
  final noon = DateTime.utc(2026, 11, 26, 10);
  DateTime at(int minutes) => noon.add(Duration(minutes: minutes));

  test('an overrun in the room pushes everyone behind', () {
    final e = QueueEstimator.estimate([
      QueueVisit(1, 7, at(-30), 30, VisitState.inRoom, at(-10)),
      QueueVisit(2, 7, at(0), 30, VisitState.arrived),
      QueueVisit(3, 7, at(30), 30, VisitState.booked),
    ], noon);
    expect(e[2]!.expectedStart, at(20));
    expect(e[2]!.delayMin, 20);
    expect(e[2]!.ahead, 1);
    expect(e[3]!.expectedStart, at(50));
    expect(e[3]!.ahead, 2);
  });

  test('nobody goes in before their booked time', () {
    final e = QueueEstimator.estimate([QueueVisit(1, 7, at(45), 15, VisitState.arrived)], noon);
    expect(e[1]!.expectedStart, at(45));
    expect(e[1]!.delayMin, 0);
  });

  test('a visit that should have ended gets a few more minutes', () {
    final e = QueueEstimator.estimate([
      QueueVisit(1, 7, at(-60), 30, VisitState.inRoom, at(-50)),
      QueueVisit(2, 7, at(-15), 15, VisitState.arrived),
    ], noon);
    expect(e[2]!.expectedStart, noon.add(QueueEstimator.overrunPadding));
  });

  test("a late no-show doesn't hold up the people behind them", () {
    final e = QueueEstimator.estimate([
      QueueVisit(1, 7, at(-20), 30, VisitState.booked),
      QueueVisit(2, 7, at(0), 30, VisitState.arrived),
    ], noon);
    expect(e[1]!.late, isTrue);
    expect(e[2]!.expectedStart, noon);
    expect(e[2]!.ahead, 0);
  });

  test('each doctor has their own queue', () {
    final e = QueueEstimator.estimate([
      QueueVisit(1, 7, at(-10), 30, VisitState.inRoom, at(-10)),
      QueueVisit(2, 7, at(0), 30, VisitState.arrived),
      QueueVisit(3, 8, at(0), 30, VisitState.arrived),
    ], noon);
    expect(e[2]!.delayMin, 20);
    expect(e[3]!.delayMin, 0);
  });

  test('public screens shorten names but keep kunyas', () {
    expect(screenName('يوسف النجار'), 'يوسف ن.');
    expect(screenName('Omar Saleh Haddad'), 'Omar S.');
    expect(screenName('أبو سامي'), 'أبو سامي');
    expect(screenName('مريم ع.'), 'مريم ع.');
    expect(screenName('  '), isNull);
  });

  test('check-in codes are read from links and raw text', () {
    expect(checkInCodeFrom('https://mawid.app/c/k7q2m9xw3a'), 'K7Q2M9XW3A');
    expect(checkInCodeFrom('mawid:K7Q2M9XW3A'), 'K7Q2M9XW3A');
    expect(checkInCodeFrom('  '), isNull);
  });
}
