import 'package:flutter/widgets.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/l10n/failure_messages.dart';
import '../../domain/entities/desk_board.dart';
import '../../domain/entities/invoice.dart';

/// Front-desk text in Arabic and English. Kept next to the feature so the main strings file
/// stays readable; same rule: widgets never hold literal text.
abstract class DeskStrings {
  const DeskStrings();

  static DeskStrings of(BuildContext context) =>
      context.l10n.localeName == 'en' ? const _En() : const _Ar();

  String get title;
  String get tabQueue;
  String get tabInvoices;
  String get tabLog;
  String get scan;
  String get walkIn;
  String get waitingScreen;
  String get simulateOffline;
  String get endSimulation;

  // queue
  String get inRoom;
  String get waiting;
  String get notArrived;
  String get finished;
  String get nobodyHere;
  String get checkIn;
  String get call;
  String get callAgain;
  String get finish;
  String get noShow;
  String get makeInvoice;
  String ticket(String n);
  String ahead(int n);
  String goesInAt(String time);
  String delay(String minutes);
  String get late;
  String get onTime;
  String get withPatient;
  String nowServing(String n);
  String waitingFor(String n);
  String get arrival;
  String get doctor;
  String get invoiceStep;
  String get countBooked;
  String get countWaiting;
  String get countInRoom;
  String get countDone;
  String presence(StaffPresence p);
  String get changePresence;
  String calledTo(String room);
  String get calledToast;
  String checkedIn(String name, String ticket);

  // offline
  String offline(int pending);
  String lastUpdate(String time);
  String get backOnline;
  String rejected(int n);
  String get notSentYet;

  // scan & walk-in
  String get scanTitle;
  String get scanHint;
  String get typeCode;
  String get codeLabel;
  String get noCamera;
  String get walkInTitle;
  String get serviceLabel;
  String get staffLabel;
  String get anyone;
  String get add;

  // invoices
  String invoiceNo(String n);
  String get provisional;
  String get newInvoice;
  String get noInvoices;
  String get item;
  String get qty;
  String get price;
  String get amount;
  String get quickAdd;
  String get otherItem;
  String get description;
  String get subtotal;
  String get discount;
  String get total;
  String get paidNow;
  String method(PaymentMethod m);
  String get markPaid;
  String status(InvoiceStatus s);
  String get voidInvoice;
  String get voidReason;
  String get edit;
  String get saveChanges;
  String get printA4;
  String get printReceipt;
  String get history;
  String editedAt(String time);
  String createdBy(String name);
  String get customer;
  String get editNeedsNetwork;
  String get previewNote;
  String get scanToVerify;
  String get thanks;

  // log
  String get logEmpty;
  String role(String code);
  String action(String code);

  // waiting screen
  String get nowCalling;
  String get idleCall;
  String get doctors;
  String get nobodyWaiting;
  String get soundOn;
  String get soundOff;
  String etaMinutes(String n);
  String get now;
  String get displayHint;
  String spokenCall(String ticket, String name, String? room);
  String get ttsLanguage;

  // errors that only the desk has
  String? error(String code);

  /// The desk's own words for its errors, falling back to the app's general messages.
  String failure(Failure f, AppLocalizations l10n) => error(f.code) ?? f.message(l10n);
}

class _Ar extends DeskStrings {
  const _Ar();

  @override
  String get title => 'الاستقبال';
  @override
  String get tabQueue => 'الدور';
  @override
  String get tabInvoices => 'الفواتير';
  @override
  String get tabLog => 'السجل';
  @override
  String get scan => 'امسح QR';
  @override
  String get walkIn => 'بدون موعد';
  @override
  String get waitingScreen => 'شاشة الانتظار';
  @override
  String get simulateOffline => 'جرّب من غير نت (ديمو)';
  @override
  String get endSimulation => 'رجّع النت';

  @override
  String get inRoom => 'في الغرفة';
  @override
  String get waiting => 'بالانتظار';
  @override
  String get notArrived => 'لسه ما وصلوش';
  @override
  String get finished => 'خلصوا';
  @override
  String get nobodyHere => 'مفيش حد هنا';
  @override
  String get checkIn => 'وصل';
  @override
  String get call => 'نادِه';
  @override
  String get callAgain => 'نادِه تاني';
  @override
  String get finish => 'خلّص';
  @override
  String get noShow => 'محضرش';
  @override
  String get makeInvoice => 'اعمل فاتورة';
  @override
  String ticket(String n) => 'رقم $n';
  @override
  String ahead(int n) => n == 0 ? 'هو اللي عليه الدور' : 'قدامه $n';
  @override
  String goesInAt(String time) => 'يدخل حوالي $time';
  @override
  String delay(String minutes) => 'متأخر $minutes د';
  @override
  String get late => 'فات ميعاده ولسه ما وصلش';
  @override
  String get onTime => 'في ميعاده';
  @override
  String get withPatient => 'مع مريض';
  @override
  String nowServing(String n) => 'جوه دلوقتي: رقم $n';
  @override
  String waitingFor(String n) => '$n بالانتظار';
  @override
  String get arrival => 'الوصول';
  @override
  String get doctor => 'الدكتور';
  @override
  String get invoiceStep => 'الفاتورة';
  @override
  String get countBooked => 'جايين';
  @override
  String get countWaiting => 'بالانتظار';
  @override
  String get countInRoom => 'جوه';
  @override
  String get countDone => 'خلصوا';
  @override
  String presence(StaffPresence p) => switch (p) {
        StaffPresence.available => 'متاح',
        StaffPresence.busy => 'مع مريض',
        StaffPresence.onBreak => 'استراحة',
        StaffPresence.away => 'مش موجود',
      };
  @override
  String get changePresence => 'غيّر الحالة';
  @override
  String calledTo(String room) => 'اتنادى على $room';
  @override
  String get calledToast => 'اتنادى عليه، والشاشة هتعلن';
  @override
  String checkedIn(String name, String ticket) => '$name وصل · رقم $ticket';

  @override
  String offline(int pending) =>
      pending == 0 ? 'مفيش نت. بتشوف آخر نسخة.' : 'مفيش نت. $pending تغيير هيتبعت أول ما النت يرجع.';
  @override
  String lastUpdate(String time) => 'آخر تحديث $time';
  @override
  String get backOnline => 'النت رجع واتبعت كل حاجة';
  @override
  String rejected(int n) => 'السيرفر رفض $n تغيير اتعمل وانت أوفلاين (مثلًا الدكتور كان مشغول)';
  @override
  String get notSentYet => 'لسه ما اتبعتش';

  @override
  String get scanTitle => 'تسجيل وصول';
  @override
  String get scanHint => 'وجّه الكاميرا على الكود اللي على حجز العميل';
  @override
  String get typeCode => 'أو اكتب الكود';
  @override
  String get codeLabel => 'كود الحجز';
  @override
  String get noCamera => 'الكاميرا مش متاحة هنا. اكتب الكود بدلها.';
  @override
  String get walkInTitle => 'عميل من غير موعد';
  @override
  String get serviceLabel => 'الخدمة';
  @override
  String get staffLabel => 'عند مين';
  @override
  String get anyone => 'أي حد فاضي';
  @override
  String get add => 'ضيفه للدور';

  @override
  String invoiceNo(String n) => 'فاتورة #$n';
  @override
  String get provisional => 'رقم مؤقت';
  @override
  String get newInvoice => 'فاتورة جديدة';
  @override
  String get noInvoices => 'مفيش فواتير النهارده لسه';
  @override
  String get item => 'البند';
  @override
  String get qty => 'الكمية';
  @override
  String get price => 'السعر';
  @override
  String get amount => 'المبلغ';
  @override
  String get quickAdd => 'ضيف بسرعة';
  @override
  String get otherItem => 'بند تاني';
  @override
  String get description => 'الوصف';
  @override
  String get subtotal => 'المجموع';
  @override
  String get discount => 'الخصم';
  @override
  String get total => 'الإجمالي';
  @override
  String get paidNow => 'اتدفعت دلوقتي';
  @override
  String method(PaymentMethod m) => switch (m) {
        PaymentMethod.cash => 'كاش',
        PaymentMethod.card => 'كارت',
        PaymentMethod.transfer => 'تحويل',
      };
  @override
  String get markPaid => 'اتدفعت';
  @override
  String status(InvoiceStatus s) => switch (s) {
        InvoiceStatus.issued => 'مش مدفوعة',
        InvoiceStatus.paid => 'مدفوعة',
        InvoiceStatus.voided => 'ملغية',
      };
  @override
  String get voidInvoice => 'إلغاء الفاتورة';
  @override
  String get voidReason => 'سبب الإلغاء';
  @override
  String get edit => 'تعديل';
  @override
  String get saveChanges => 'احفظ التعديل';
  @override
  String get printA4 => 'طباعة A4';
  @override
  String get printReceipt => 'إيصال صغير';
  @override
  String get history => 'سجل الفاتورة';
  @override
  String editedAt(String time) => 'اتعدّلت $time';
  @override
  String createdBy(String name) => 'عملها $name';
  @override
  String get customer => 'العميل';
  @override
  String get editNeedsNetwork => 'التعديل محتاج نت، عشان ما يحصلش تعارض مع جهاز تاني.';
  @override
  String get previewNote => 'دي معاينة. نسخة السيرفر بتفتح صفحة طباعة A4 أو إيصال ٨٠ مم.';
  @override
  String get scanToVerify => 'امسح الكود للتأكد من الفاتورة';
  @override
  String get thanks => 'شكرًا لزيارتكم';

  @override
  String get logEmpty => 'لسه مفيش حاجة اتعملت النهارده';
  @override
  String role(String code) => switch (code) {
        'OWNER' => 'صاحب المكان',
        'RECEPTION' => 'الاستقبال',
        'CUSTOMER' => 'العميل',
        'PATIENT' => 'العميل من موبايله',
        _ => 'النظام',
      };
  @override
  String action(String code) => switch (code) {
        'BOOKING_CREATED' => 'سجّل حجز',
        'WALK_IN_ADDED' => 'ضاف عميل من غير موعد',
        'BOOKING_STATUS' => 'غيّر حالة حجز',
        'BOOKING_CANCELLED' => 'لغى حجز',
        'BOOKING_MOVED' => 'غيّر ميعاد حجز',
        'CHECKED_IN' => 'سجّل وصول',
        'CALLED' => 'نادى',
        'VISIT_FINISHED' => 'خلّص زيارة',
        'NO_SHOW' => 'سجّل محضرش',
        'PRESENCE_CHANGED' => 'غيّر حالة',
        'INVOICE_CREATED' => 'عمل فاتورة',
        'INVOICE_EDITED' => 'عدّل فاتورة',
        'INVOICE_PAID' => 'استلم فلوس فاتورة',
        'INVOICE_VOIDED' => 'لغى فاتورة',
        'SERVICE_SAVED' => 'عدّل خدمة',
        _ => code,
      };

  @override
  String get nowCalling => 'يتفضّل دلوقتي';
  @override
  String get idleCall => 'مستنيين أول نداء';
  @override
  String get doctors => 'الأطباء';
  @override
  String get nobodyWaiting => 'مفيش حد بالانتظار';
  @override
  String get soundOn => 'شغّل الصوت';
  @override
  String get soundOff => 'اقفل الصوت';
  @override
  String etaMinutes(String n) => '~ $n د';
  @override
  String get now => 'دلوقتي';
  @override
  String get displayHint => 'وصلت؟ اعرض الكود اللي على حجزك في الاستقبال.';
  @override
  String spokenCall(String ticket, String name, String? room) =>
      'رقم $ticket، $name، اتفضل ${room == null ? 'للدخول' : 'على $room'}';
  @override
  String get ttsLanguage => 'ar-SA';

  @override
  String? error(String code) => switch (code) {
        'STAFF_BUSY' => 'الدكتور لسه مع مريض. خلّص الزيارة دي الأول.',
        'NOT_CHECKED_IN' => 'سجّل وصوله الأول.',
        'NOT_CALLABLE' || 'NOT_IN_ROOM' || 'NOT_CHANGEABLE' => 'الحالة دي ما ينفعش يتعمل فيها كده.',
        'NOT_TODAY' => 'الحجز ده مش النهارده.',
        'NO_FREE_TIME' => 'مفيش حد فاضي للخدمة دي النهارده.',
        'INVALID_CODE' => 'ده مش كود حجز.',
        'NOT_FOUND' => 'مفيش حجز بالكود ده هنا.',
        'BOOKING_CANCELLED' => 'الحجز ده اتلغى.',
        'STALE_INVOICE' || 'STALE' => 'حد تاني عدّل الفاتورة دي. حمّلناها تاني، جرّب كمان مرة.',
        'ALREADY_INVOICED' => 'الزيارة دي ليها فاتورة خلاص.',
        'INVOICE_VOID' => 'الفاتورة دي ملغية.',
        'INVALID_DISCOUNT' => 'الخصم لازم يكون بين صفر والمجموع.',
        'NO_LINES' => 'ضيف بند واحد على الأقل.',
        'CUSTOMER_REQUIRED' => 'اكتب اسم العميل.',
        _ => null,
      };
}

class _En extends DeskStrings {
  const _En();

  @override
  String get title => 'Front desk';
  @override
  String get tabQueue => 'Queue';
  @override
  String get tabInvoices => 'Invoices';
  @override
  String get tabLog => 'Log';
  @override
  String get scan => 'Scan QR';
  @override
  String get walkIn => 'Walk-in';
  @override
  String get waitingScreen => 'Waiting screen';
  @override
  String get simulateOffline => 'Try offline (demo)';
  @override
  String get endSimulation => 'Back online';

  @override
  String get inRoom => 'In the room';
  @override
  String get waiting => 'Waiting';
  @override
  String get notArrived => 'Not here yet';
  @override
  String get finished => 'Done';
  @override
  String get nobodyHere => 'Nobody here';
  @override
  String get checkIn => 'Arrived';
  @override
  String get call => 'Call in';
  @override
  String get callAgain => 'Call again';
  @override
  String get finish => 'Finish';
  @override
  String get noShow => 'No-show';
  @override
  String get makeInvoice => 'Invoice';
  @override
  String ticket(String n) => 'No. $n';
  @override
  String ahead(int n) => n == 0 ? 'Next in' : '$n ahead';
  @override
  String goesInAt(String time) => 'In at about $time';
  @override
  String delay(String minutes) => '$minutes min late';
  @override
  String get late => 'Past their time, not here';
  @override
  String get onTime => 'On time';
  @override
  String get withPatient => 'With a patient';
  @override
  String nowServing(String n) => 'In now: no. $n';
  @override
  String waitingFor(String n) => '$n waiting';
  @override
  String get arrival => 'Arrive';
  @override
  String get doctor => 'Doctor';
  @override
  String get invoiceStep => 'Invoice';
  @override
  String get countBooked => 'Coming';
  @override
  String get countWaiting => 'Waiting';
  @override
  String get countInRoom => 'In';
  @override
  String get countDone => 'Done';
  @override
  String presence(StaffPresence p) => switch (p) {
        StaffPresence.available => 'Available',
        StaffPresence.busy => 'With a patient',
        StaffPresence.onBreak => 'On a break',
        StaffPresence.away => 'Away',
      };
  @override
  String get changePresence => 'Change status';
  @override
  String calledTo(String room) => 'Called to $room';
  @override
  String get calledToast => 'Called in; the screen will announce it';
  @override
  String checkedIn(String name, String ticket) => '$name arrived · no. $ticket';

  @override
  String offline(int pending) => pending == 0
      ? 'Offline. Showing the last copy.'
      : 'Offline. $pending change${pending == 1 ? '' : 's'} will be sent when the network is back.';
  @override
  String lastUpdate(String time) => 'Last update $time';
  @override
  String get backOnline => 'Back online, everything sent';
  @override
  String rejected(int n) => 'The server refused $n change${n == 1 ? '' : 's'} made offline (e.g. the doctor was busy)';
  @override
  String get notSentYet => 'Not sent yet';

  @override
  String get scanTitle => 'Check in';
  @override
  String get scanHint => "Point the camera at the code on the customer's booking";
  @override
  String get typeCode => 'or type the code';
  @override
  String get codeLabel => 'Booking code';
  @override
  String get noCamera => 'No camera here. Type the code instead.';
  @override
  String get walkInTitle => 'Walk-in';
  @override
  String get serviceLabel => 'Service';
  @override
  String get staffLabel => 'With';
  @override
  String get anyone => 'Whoever is free';
  @override
  String get add => 'Add to the queue';

  @override
  String invoiceNo(String n) => 'Invoice #$n';
  @override
  String get provisional => 'Number pending';
  @override
  String get newInvoice => 'New invoice';
  @override
  String get noInvoices => 'No invoices today yet';
  @override
  String get item => 'Item';
  @override
  String get qty => 'Qty';
  @override
  String get price => 'Price';
  @override
  String get amount => 'Amount';
  @override
  String get quickAdd => 'Quick add';
  @override
  String get otherItem => 'Other item';
  @override
  String get description => 'Description';
  @override
  String get subtotal => 'Subtotal';
  @override
  String get discount => 'Discount';
  @override
  String get total => 'Total';
  @override
  String get paidNow => 'Paid now';
  @override
  String method(PaymentMethod m) => switch (m) {
        PaymentMethod.cash => 'Cash',
        PaymentMethod.card => 'Card',
        PaymentMethod.transfer => 'Transfer',
      };
  @override
  String get markPaid => 'Mark paid';
  @override
  String status(InvoiceStatus s) => switch (s) {
        InvoiceStatus.issued => 'Not paid',
        InvoiceStatus.paid => 'Paid',
        InvoiceStatus.voided => 'Void',
      };
  @override
  String get voidInvoice => 'Void invoice';
  @override
  String get voidReason => 'Reason';
  @override
  String get edit => 'Edit';
  @override
  String get saveChanges => 'Save changes';
  @override
  String get printA4 => 'Print A4';
  @override
  String get printReceipt => 'Receipt';
  @override
  String get history => 'History';
  @override
  String editedAt(String time) => 'Edited $time';
  @override
  String createdBy(String name) => 'By $name';
  @override
  String get customer => 'Customer';
  @override
  String get editNeedsNetwork => 'Editing needs the network, so two desks never overwrite each other.';
  @override
  String get previewNote => 'Preview. With the server, this opens a print page for A4 or an 80 mm receipt.';
  @override
  String get scanToVerify => 'Scan to verify this invoice';
  @override
  String get thanks => 'Thank you for your visit';

  @override
  String get logEmpty => 'Nothing has happened today yet';
  @override
  String role(String code) => switch (code) {
        'OWNER' => 'owner',
        'RECEPTION' => 'reception',
        'CUSTOMER' => 'customer',
        'PATIENT' => 'customer, from their phone',
        _ => 'system',
      };
  @override
  String action(String code) => switch (code) {
        'BOOKING_CREATED' => 'added a booking for',
        'WALK_IN_ADDED' => 'added a walk-in:',
        'BOOKING_STATUS' => 'changed the status of',
        'BOOKING_CANCELLED' => 'cancelled',
        'BOOKING_MOVED' => 'moved',
        'CHECKED_IN' => 'checked in',
        'CALLED' => 'called in',
        'VISIT_FINISHED' => 'finished the visit of',
        'NO_SHOW' => 'marked as no-show:',
        'PRESENCE_CHANGED' => 'changed the status of',
        'INVOICE_CREATED' => 'issued invoice',
        'INVOICE_EDITED' => 'edited invoice',
        'INVOICE_PAID' => 'took payment for invoice',
        'INVOICE_VOIDED' => 'voided invoice',
        'SERVICE_SAVED' => 'edited the service',
        _ => code,
      };

  @override
  String get nowCalling => 'Now calling';
  @override
  String get idleCall => 'Waiting for the first call';
  @override
  String get doctors => 'Doctors';
  @override
  String get nobodyWaiting => 'Nobody waiting';
  @override
  String get soundOn => 'Sound on';
  @override
  String get soundOff => 'Sound off';
  @override
  String etaMinutes(String n) => '~ $n min';
  @override
  String get now => 'now';
  @override
  String get displayHint => 'Just arrived? Show the code on your booking at reception.';
  @override
  String spokenCall(String ticket, String name, String? room) =>
      'Number $ticket, $name, please go to ${room ?? 'the room'}';
  @override
  String get ttsLanguage => 'en-US';

  @override
  String? error(String code) => switch (code) {
        'STAFF_BUSY' => 'Still with another patient. Finish that visit first.',
        'NOT_CHECKED_IN' => 'Check them in first.',
        'NOT_CALLABLE' || 'NOT_IN_ROOM' || 'NOT_CHANGEABLE' => "That can't be done at this stage.",
        'NOT_TODAY' => 'That booking is for another day.',
        'NO_FREE_TIME' => 'Nobody is free for this service today.',
        'INVALID_CODE' => "That isn't a booking code.",
        'NOT_FOUND' => 'No booking with that code here.',
        'BOOKING_CANCELLED' => 'That booking was cancelled.',
        'STALE_INVOICE' || 'STALE' => 'Someone else changed this invoice. It was reloaded; try again.',
        'ALREADY_INVOICED' => 'This visit already has an invoice.',
        'INVOICE_VOID' => 'This invoice is void.',
        'INVALID_DISCOUNT' => 'Discount must be between zero and the subtotal.',
        'NO_LINES' => 'Add at least one item.',
        'CUSTOMER_REQUIRED' => "Enter the customer's name.",
        _ => null,
      };
}

extension DeskStringsX on BuildContext {
  DeskStrings get desk => DeskStrings.of(this);
}
