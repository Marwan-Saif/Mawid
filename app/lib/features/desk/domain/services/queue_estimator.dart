/// When each waiting person will actually go in, per doctor or stylist.
///
/// The same rules as the API's `QueueEstimator.java`, so the offline demo backend shows the same
/// waits as the server:
/// * whoever is in the room finishes at startedAt + duration (if that has passed, a few more minutes);
/// * then people go in by their booked time, never before it;
/// * someone booked but not here and more than [noShowGrace] late doesn't hold up the people behind.
class QueueEstimator {
  const QueueEstimator._();

  static const noShowGrace = Duration(minutes: 15);
  static const overrunPadding = Duration(minutes: 5);

  static Map<int, QueueEstimate> estimate(List<QueueVisit> visits, DateTime nowUtc) {
    final result = <int, QueueEstimate>{};
    final byStaff = <int, List<QueueVisit>>{};
    for (final v in visits) {
      byStaff.putIfAbsent(v.staffId, () => []).add(v);
    }
    for (final list in byStaff.values) {
      list.sort((a, b) {
        final c = a.scheduledStart.compareTo(b.scheduledStart);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
      var cursor = nowUtc;
      var ahead = 0;
      for (final v in list.where((v) => v.state == VisitState.inRoom)) {
        final began = v.startedAt ?? v.scheduledStart;
        var end = began.add(Duration(minutes: v.durationMin));
        if (!end.isAfter(nowUtc)) end = nowUtc.add(overrunPadding);
        if (end.isAfter(cursor)) cursor = end;
        result[v.id] = QueueEstimate(v.id, began, _minutes(v.scheduledStart, began), 0, false);
        ahead++;
      }
      for (final v in list.where((v) => v.state != VisitState.inRoom)) {
        final late = v.state == VisitState.booked && v.scheduledStart.add(noShowGrace).isBefore(nowUtc);
        final expected = cursor.isAfter(v.scheduledStart) ? cursor : v.scheduledStart;
        result[v.id] = QueueEstimate(v.id, expected, _minutes(v.scheduledStart, expected), ahead, late);
        if (!late) {
          cursor = expected.add(Duration(minutes: v.durationMin));
          ahead++;
        }
      }
    }
    return result;
  }

  static int _minutes(DateTime scheduled, DateTime actual) {
    final m = actual.difference(scheduled).inMinutes;
    return m < 0 ? 0 : m;
  }
}

enum VisitState { booked, arrived, inRoom }

class QueueVisit {
  const QueueVisit(this.id, this.staffId, this.scheduledStart, this.durationMin, this.state, [this.startedAt]);

  final int id;
  final int staffId;
  final DateTime scheduledStart;
  final int durationMin;
  final VisitState state;
  final DateTime? startedAt;
}

class QueueEstimate {
  const QueueEstimate(this.id, this.expectedStart, this.delayMin, this.ahead, this.late);

  final int id;
  final DateTime expectedStart;
  final int delayMin;
  final int ahead;
  final bool late;
}
