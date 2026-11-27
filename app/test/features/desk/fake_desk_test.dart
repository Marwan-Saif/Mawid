import 'package:flutter_test/flutter_test.dart';
import 'package:mawid/core/error/exceptions.dart';
import 'package:mawid/core/fake/fake_backend.dart';
import 'package:mawid/core/session/session.dart';
import 'package:mawid/features/auth/data/models/user_model.dart';

import '../../helpers/test_setup.dart';

/// The demo front desk must follow the same rules as the API's DeskService and InvoiceService.
void main() {
  late Session session;
  late FakeBackend backend;

  setUpAll(initTestEnvironment);

  setUp(() async {
    session = Session();
    // 12:07 in Amman: the seeded clinic day exists whatever time the tests run.
    backend = FakeBackend(session, latency: Duration.zero, clock: () => DateTime.utc(2026, 11, 26, 9, 7));
    final login = await backend.demoLogin('RECEPTION');
    session.set(login['token'] as String, UserModel(Map<String, dynamic>.from(login['user'] as Map)).toEntity());
  });

  Map<String, dynamic> entry(Map<String, dynamic> board, bool Function(Map b) test) =>
      (board['queue'] as List).cast<Map<String, dynamic>>().firstWhere((q) => test(q['booking'] as Map));

  test('reception sees a live clinic: someone in the room, people waiting with delays', () async {
    final board = await backend.deskBoard();
    expect(board['place']['slug'], 'nakheel-clinic');
    expect(board['counts']['inRoom'], greaterThanOrEqualTo(1));
    expect(board['counts']['waiting'], greaterThanOrEqualTo(2));
    final abuSami = entry(board, (b) => b['customerName'] == 'أبو سامي');
    expect(abuSami['booking']['status'], 'ARRIVED');
    expect(abuSami['delayMin'] as int, greaterThan(0)); // the doctor is running late
  });

  test('check in by QR link, call, busy doctor, finish, invoice, edit, audit', () async {
    var board = await backend.deskBoard();
    final mahmoud = entry(board, (b) => b['customerName'] == 'محمود الرواشدة')['booking'] as Map;

    final arrived = await backend.deskCheckInByCode('https://clinic.example/c/${mahmoud['checkInCode']}');
    expect(arrived['status'], 'ARRIVED');
    expect(arrived['ticketNo'], isNotNull);
    // Scanning twice changes nothing.
    expect((await backend.deskCheckInByCode(mahmoud['checkInCode'] as String))['ticketNo'], arrived['ticketNo']);

    // Dr Khaled is still with Yousef.
    await expectLater(backend.deskCall(arrived['id'] as int),
        throwsA(isA<ServerException>().having((e) => e.code, 'code', 'STAFF_BUSY')));

    board = await backend.deskBoard();
    final inRoom = entry(board, (b) => b['status'] == 'IN_PROGRESS' && b['staffName'] == 'د. خالد العمري');
    final done = await backend.deskFinish(inRoom['booking']['id'] as int);
    expect(done['status'], 'COMPLETED');

    final called = await backend.deskCall(entry(board, (b) => b['customerName'] == 'أبو سامي')['booking']['id'] as int);
    expect(called['status'], 'IN_PROGRESS');
    expect(called['room'], 'غرفة ١');
    final screen = await backend.display('nakheel-clinic');
    expect(screen['lastCall']['name'], 'أبو سامي');

    final body = {
      'bookingId': done['id'],
      'clientRef': 'test-1',
      'lines': [
        {'description': 'كشفية', 'qty': 1, 'unitPrice': 20},
        {'description': 'قياس ضغط', 'qty': 1, 'unitPrice': 5},
      ],
    };
    final inv = await backend.deskCreateInvoice(body);
    expect(inv['total'], 25);
    expect(inv['number'], greaterThan(1042));
    expect((await backend.deskCreateInvoice(body))['id'], inv['id']); // same clientRef = same invoice

    final edited = await backend.deskUpdateInvoice(inv['id'] as int, {
      'version': inv['version'],
      'lines': [
        {'description': 'كشفية', 'qty': 1, 'unitPrice': 20},
      ],
    });
    expect(edited['total'], 20);
    await expectLater(
      backend.deskUpdateInvoice(inv['id'] as int, {'version': inv['version'], 'lines': body['lines']}),
      throwsA(isA<ServerException>().having((e) => e.code, 'code', 'STALE_INVOICE')),
    );

    final log = await backend.deskAudit(entityType: 'INVOICE', entityId: inv['id'] as int);
    expect(log.first['action'], 'INVOICE_EDITED');
    expect(log.first['actorName'], 'سارة');
    expect(log.first['details']['removed'], isNotEmpty);
  });

  test('the seed has #1042 edited by reception, like a real day', () async {
    final invoices = await backend.deskInvoices();
    final second = invoices.firstWhere((i) => i['number'] == 1042);
    expect(second['total'], 25);
    expect(second['updatedAt'], isNotNull);
  });

  test('walk-ins are booked into the next free time and queued', () async {
    final board = await backend.deskBoard();
    final service = (board['services'] as List).cast<Map>().firstWhere((s) => s['nameEn'] == 'Blood pressure check');
    final b = await backend.deskWalkIn({
      'serviceId': service['id'],
      'staffId': null,
      'customerName': 'زائر',
      'customerPhone': '+962791110009',
    });
    expect(b['status'], 'ARRIVED');
    expect(b['source'], 'WALK_IN');
  });

  test('offline switch makes the desk fail like a dropped network', () async {
    backend.offline = true;
    await expectLater(backend.deskBoard(), throwsA(isA<NetworkException>()));
    backend.offline = false;
    expect(await backend.deskBoard(), isNotEmpty);
  });

  test('customers cannot use the desk', () async {
    final login = await backend.demoLogin('CUSTOMER');
    session.set(login['token'] as String, UserModel(Map<String, dynamic>.from(login['user'] as Map)).toEntity());
    await expectLater(backend.deskBoard(), throwsA(isA<ServerException>().having((e) => e.code, 'code', 'FORBIDDEN')));
  });
}
