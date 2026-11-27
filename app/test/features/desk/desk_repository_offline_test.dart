import 'package:flutter_test/flutter_test.dart';
import 'package:mawid/core/fake/fake_backend.dart';
import 'package:mawid/core/session/session.dart';
import 'package:mawid/core/storage/local_store.dart';
import 'package:mawid/features/auth/data/models/user_model.dart';
import 'package:mawid/features/booking/domain/entities/booking.dart';
import 'package:mawid/features/desk/data/datasources/desk_data_source.dart';
import 'package:mawid/features/desk/data/repositories/desk_repository_impl.dart';
import 'package:mawid/features/desk/domain/entities/invoice.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_setup.dart';

/// The network drops at reception: work goes on, changes queue up, and reach the server later.
void main() {
  late FakeBackend backend;
  late DeskRepositoryImpl repo;

  setUpAll(initTestEnvironment);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final session = Session();
    // 12:07 in Amman: the seeded clinic day exists whatever time the tests run.
    backend = FakeBackend(session, latency: Duration.zero, clock: () => DateTime.utc(2026, 11, 26, 9, 7));
    final login = await backend.demoLogin('RECEPTION');
    session.set(login['token'] as String, UserModel(Map<String, dynamic>.from(login['user'] as Map)).toEntity());
    repo = DeskRepositoryImpl(DeskFakeDataSource(backend), LocalStore(await SharedPreferences.getInstance()),
        retryEvery: Duration.zero);
  });

  tearDown(() => repo.dispose());

  test('offline: the last board still shows, a check-in is queued and sent when back', () async {
    final online = (await repo.board()).getOrElse(() => throw StateError('no board'));
    final notHere = online.notArrived.first;

    backend.offline = true;
    final cached = (await repo.board()).getOrElse(() => throw StateError('no cached board'));
    expect(cached.isOffline, isTrue);

    final result = await repo.checkIn(notHere.booking);
    expect(result.getOrElse(() => throw StateError('failed')).status, BookingStatus.arrived);
    expect(repo.currentSync.pending, 1);
    expect(repo.currentSync.online, isFalse);

    // Reloading offline keeps the change on screen, marked as not sent yet.
    final again = (await repo.board()).getOrElse(() => throw StateError('no board'));
    final shown = again.queue.firstWhere((q) => q.id == notHere.id);
    expect(shown.booking.status, BookingStatus.arrived);
    expect(shown.pendingSync, isTrue);

    backend.offline = false;
    await repo.syncNow();
    expect(repo.currentSync.pending, 0);
    final fresh = (await repo.board()).getOrElse(() => throw StateError('no board'));
    final onServer = fresh.queue.firstWhere((q) => q.id == notHere.id);
    expect(onServer.booking.status, BookingStatus.arrived);
    expect(onServer.booking.ticketNo, isNotNull); // the server numbered it
    expect(onServer.pendingSync, isFalse);
  });

  test('an invoice made offline gets its number when it is sent, once', () async {
    final board = (await repo.board()).getOrElse(() => throw StateError('no board'));
    backend.offline = true;
    final draft = InvoiceDraft(
      customerName: 'زائر',
      lines: const [InvoiceLine(description: 'قياس ضغط', qty: 1, unitPrice: 5)],
      clientRef: newClientRef(),
    );
    final local = (await repo.createInvoice(draft)).getOrElse(() => throw StateError('failed'));
    expect(local.number, isNull);
    expect(local.pendingSync, isTrue);
    expect(local.currency, board.place.currency);

    // Paid while still offline: folded into the queued "create".
    await repo.payInvoice(local, PaymentMethod.cash);
    expect(repo.currentSync.pending, 1);

    backend.offline = false;
    await repo.syncNow();
    await repo.syncNow(); // a second send must not create a second invoice
    final list = (await repo.invoices()).getOrElse(() => throw StateError('no invoices'));
    final sent = list.where((i) => i.clientRef == draft.clientRef).toList();
    expect(sent, hasLength(1));
    expect(sent.single.number, isNotNull);
    expect(sent.single.status, InvoiceStatus.paid);
  });

  test('a change the server refuses later is dropped and reported', () async {
    final board = (await repo.board()).getOrElse(() => throw StateError('no board'));
    // Someone waiting for the doctor who is still busy: calling them will be refused.
    final waitingForBusyDoctor = board.waiting.firstWhere(
        (q) => board.inRoom.any((r) => r.booking.staffId == q.booking.staffId));
    backend.offline = true;
    await repo.call(waitingForBusyDoctor.booking);
    backend.offline = false;
    await repo.syncNow();
    expect(repo.currentSync.pending, 0);
    expect(repo.currentSync.rejected, ['STAFF_BUSY']);
  });
}
