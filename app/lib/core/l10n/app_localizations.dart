import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// All UI text, in Arabic and English. Hand-written instead of generated .arb code so the
/// project builds with no code generation step; every string is still checked by the compiler.
///
/// Widgets never contain literal text: they use `context.l10n.something`.
abstract class AppLocalizations {
  const AppLocalizations();

  static const supportedLocales = [Locale('ar'), Locale('en')];

  static const LocalizationsDelegate<AppLocalizations> delegate = _Delegate();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static AppLocalizations forLocale(Locale locale) =>
      locale.languageCode == 'en' ? const EnStrings() : const ArStrings();

  String get localeName;

  // ---------------------------------------------------------------- auth
  String get welcomeTitle;
  String get welcomeSubtitle;
  String get phoneLabel;
  String get continueLabel;
  String get or;
  String get tryAsCustomer;
  String get tryAsOwner;
  String get tryAsReception;
  String get demoHint;
  String get otpTitle;
  String otpSentTo(String phone);
  String get otpLabel;
  String get verify;
  String get resend;
  String get yourName;

  // ---------------------------------------------------------------- navigation
  String get navHome;
  String get navExplore;
  String get navBookings;
  String get navProfile;
  String get navSchedule;
  String get navServices;
  String get navDesk;

  // ---------------------------------------------------------------- home & places
  String get goodMorning;
  String get goodEvening;
  String get guest;
  String get searchHint;
  String get nextAppointment;
  String inTime(int minutes);
  String get details;
  String get reschedule;
  String get categories;
  String get categoryClinic;
  String get categoryDental;
  String get categorySalon;
  String get categorySpa;
  String get allCategories;
  String get nearYou;
  String get seeAll;
  String get openToday;
  String get closedToday;
  String km(String value);
  String get noResults;
  String get servicesTab;
  String get teamTab;
  String get reviewsTab;
  String reviewsCount(String n);
  String get book;
  String get bookAppointment;
  String minutes(String n);
  String get noReviews;
  String hours(String from, String to);

  // ---------------------------------------------------------------- booking
  String get chooseTime;
  String get availableTimes;
  String get available;
  String get booked;
  String get withWhom;
  String get anyone;
  String get yourAppointment;
  String get confirm;
  String get noSlots;
  String get closedDay;
  String get bookingConfirmed;
  String get bookingConfirmedSub;
  String get rescheduled;
  String get placeLabel;
  String get serviceLabel;
  String get dateTimeLabel;
  String get staffLabel;
  String get paymentLabel;
  String get payAtPlace;
  String get total;
  String get directions;
  String get whatsapp;
  String get backHome;

  // ---------------------------------------------------------------- my bookings
  String get myBookings;
  String get upcoming;
  String get past;
  String get noBookings;
  String get noBookingsHint;
  String get cancel;
  String get cancelTitle;
  String get cancelBody;
  String get keepIt;
  String get yesCancel;
  String get changeLocked;
  String get bookingCancelled;

  // ---------------------------------------------------------------- statuses
  String get statusPending;
  String get statusConfirmed;
  String get statusInProgress;
  String get statusCompleted;
  String get statusCancelled;
  String get statusNoShow;
  String get statusArrived;
  String get showAtReception;
  String yourTicket(String n);

  // ---------------------------------------------------------------- owner
  String dashboardOf(String place);
  String get todaysAppointments;
  String get bookingsCount;
  String get completedCount;
  String get newCount;
  String get schedule;
  String get manualBooking;
  String get emptyDay;
  String get markInProgress;
  String get markCompleted;
  String get markNoShow;
  String get confirmBooking;
  String get customerName;
  String get customerPhone;
  String get save;
  String get addService;
  String get editService;
  String get nameAr;
  String get nameEn;
  String get durationMin;
  String get price;
  String get activeService;
  String get hiddenService;
  String get saved;
  String newBookingFrom(String name);
  String get bookingLink;
  String get bookingLinkHint;
  String get copied;
  String get changeStatus;

  // ---------------------------------------------------------------- profile
  String get profile;
  String get language;
  String get logout;
  String get dataSource;
  String get dataSourceFake;
  String get dataSourceApi;
  String get roleCustomer;
  String get roleOwner;
  String get roleReception;

  // ---------------------------------------------------------------- errors
  String get errSlotTaken;
  String get errOffline;
  String get errServer;
  String get errUnauthorized;
  String get errTooLate;
  String get errInvalidPhone;
  String get errOtp;
  String get errPast;
  String get errInvalidDuration;
  String get errRequired;
  String get retry;
}

class ArStrings extends AppLocalizations {
  const ArStrings();

  @override
  String get localeName => 'ar';

  @override
  String get welcomeTitle => 'احجز موعدك في ثواني';
  @override
  String get welcomeSubtitle => 'عيادات وصالونات قريبة منك، من غير مكالمات ولا انتظار.';
  @override
  String get phoneLabel => 'رقم الموبايل';
  @override
  String get continueLabel => 'متابعة';
  @override
  String get or => 'أو';
  @override
  String get tryAsCustomer => 'جرّب كعميل';
  @override
  String get tryAsOwner => 'جرّب كصاحب مكان';
  @override
  String get tryAsReception => 'جرّب كاستقبال عيادة';
  @override
  String get demoHint => 'نسخة تجريبية: الكود دايمًا 123456';
  @override
  String get otpTitle => 'اكتب الكود';
  @override
  String otpSentTo(String phone) => 'بعتنا كود من ٦ أرقام على $phone';
  @override
  String get otpLabel => 'الكود';
  @override
  String get verify => 'تأكيد';
  @override
  String get resend => 'ابعت الكود تاني';
  @override
  String get yourName => 'اسمك';

  @override
  String get navHome => 'الرئيسية';
  @override
  String get navExplore => 'استكشف';
  @override
  String get navBookings => 'مواعيدي';
  @override
  String get navProfile => 'حسابي';
  @override
  String get navSchedule => 'الجدول';
  @override
  String get navServices => 'الخدمات';
  @override
  String get navDesk => 'الاستقبال';

  @override
  String get goodMorning => 'صباح الخير';
  @override
  String get goodEvening => 'مساء الخير';
  @override
  String get guest => 'ضيفنا';
  @override
  String get searchHint => 'ابحث عن عيادة، صالون أو خدمة';
  @override
  String get nextAppointment => 'موعدك القادم';
  @override
  String inTime(int minutes) {
    if (minutes < 60) return 'بعد $minutes دقيقة';
    final h = (minutes / 60).round();
    if (h == 1) return 'بعد ساعة';
    if (h == 2) return 'بعد ساعتين';
    if (h < 24) return 'بعد $h ساعات';
    final d = (minutes / 1440).round();
    if (d == 1) return 'بكرة';
    if (d == 2) return 'بعد يومين';
    return 'بعد $d أيام';
  }

  @override
  String get details => 'التفاصيل';
  @override
  String get reschedule => 'تغيير الموعد';
  @override
  String get categories => 'التصنيفات';
  @override
  String get categoryClinic => 'عيادات';
  @override
  String get categoryDental => 'أسنان';
  @override
  String get categorySalon => 'صالونات';
  @override
  String get categorySpa => 'سبا';
  @override
  String get allCategories => 'الكل';
  @override
  String get nearYou => 'قريب منك';
  @override
  String get seeAll => 'عرض الكل';
  @override
  String get openToday => 'متاح اليوم';
  @override
  String get closedToday => 'مقفول النهارده';
  @override
  String km(String value) => '$value كم';
  @override
  String get noResults => 'مفيش نتايج. جرّب كلمة تانية.';
  @override
  String get servicesTab => 'الخدمات';
  @override
  String get teamTab => 'الفريق';
  @override
  String get reviewsTab => 'التقييمات';
  @override
  String reviewsCount(String n) => '($n تقييم)';
  @override
  String get book => 'احجز';
  @override
  String get bookAppointment => 'احجز موعد';
  @override
  String minutes(String n) => '$n دقيقة';
  @override
  String get noReviews => 'لسه مفيش تقييمات.';
  @override
  String hours(String from, String to) => 'مفتوح من $from لـ $to';

  @override
  String get chooseTime => 'اختار الموعد';
  @override
  String get availableTimes => 'المواعيد المتاحة';
  @override
  String get available => 'متاح';
  @override
  String get booked => 'محجوز';
  @override
  String get withWhom => 'مع مين؟';
  @override
  String get anyone => 'أي حد متاح';
  @override
  String get yourAppointment => 'موعدك';
  @override
  String get confirm => 'تأكيد';
  @override
  String get noSlots => 'مفيش مواعيد متاحة في اليوم ده، جرّب يوم تاني.';
  @override
  String get closedDay => 'مقفول';
  @override
  String get bookingConfirmed => 'تم تأكيد حجزك';
  @override
  String get bookingConfirmedSub => 'هيوصلك تذكير قبل الموعد بساعة. تقدر تعدّل أو تلغي لحد ٣ ساعات قبله.';
  @override
  String get rescheduled => 'تم تغيير الموعد';
  @override
  String get placeLabel => 'المكان';
  @override
  String get serviceLabel => 'الخدمة';
  @override
  String get dateTimeLabel => 'الموعد';
  @override
  String get staffLabel => 'مع';
  @override
  String get paymentLabel => 'الدفع';
  @override
  String get payAtPlace => 'في المكان';
  @override
  String get total => 'الإجمالي';
  @override
  String get directions => 'الاتجاهات';
  @override
  String get whatsapp => 'واتساب';
  @override
  String get backHome => 'رجوع للرئيسية';

  @override
  String get myBookings => 'مواعيدي';
  @override
  String get upcoming => 'الجاية';
  @override
  String get past => 'السابقة';
  @override
  String get noBookings => 'لسه معندكش مواعيد';
  @override
  String get noBookingsHint => 'احجز أول موعد من الرئيسية.';
  @override
  String get cancel => 'إلغاء';
  @override
  String get cancelTitle => 'تلغي الموعد؟';
  @override
  String get cancelBody => 'الوقت هيرجع متاح لحد تاني.';
  @override
  String get keepIt => 'لا، خليه';
  @override
  String get yesCancel => 'أيوه، إلغاء';
  @override
  String get changeLocked => 'التعديل والإلغاء متاحين لحد ٣ ساعات قبل الموعد.';
  @override
  String get bookingCancelled => 'اتلغى الموعد';

  @override
  String get statusPending => 'حجز جديد';
  @override
  String get statusConfirmed => 'جاي';
  @override
  String get statusInProgress => 'دلوقتي';
  @override
  String get statusCompleted => 'خلص';
  @override
  String get statusCancelled => 'اتلغى';
  @override
  String get statusNoShow => 'محضرش';
  @override
  String get statusArrived => 'وصل';
  @override
  String get showAtReception => 'أول ما توصل، اعرض الكود ده في الاستقبال';
  @override
  String yourTicket(String n) => 'وصلت · رقمك $n';

  @override
  String dashboardOf(String place) => 'لوحة التحكم · $place';
  @override
  String get todaysAppointments => 'مواعيد النهارده';
  @override
  String get bookingsCount => 'حجوزات';
  @override
  String get completedCount => 'خلصت';
  @override
  String get newCount => 'جديدة';
  @override
  String get schedule => 'الجدول';
  @override
  String get manualBooking => 'حجز يدوي';
  @override
  String get emptyDay => 'مفيش حجوزات في اليوم ده.';
  @override
  String get markInProgress => 'بدأ';
  @override
  String get markCompleted => 'خلص';
  @override
  String get markNoShow => 'محضرش';
  @override
  String get confirmBooking => 'تأكيد الحجز';
  @override
  String get customerName => 'اسم العميل';
  @override
  String get customerPhone => 'موبايل العميل';
  @override
  String get save => 'حفظ';
  @override
  String get addService => 'إضافة خدمة';
  @override
  String get editService => 'تعديل الخدمة';
  @override
  String get nameAr => 'الاسم بالعربي';
  @override
  String get nameEn => 'الاسم بالإنجليزي';
  @override
  String get durationMin => 'المدة بالدقايق';
  @override
  String get price => 'السعر';
  @override
  String get activeService => 'متاحة للحجز';
  @override
  String get hiddenService => 'مخفية';
  @override
  String get saved => 'اتحفظ';
  @override
  String newBookingFrom(String name) => 'حجز جديد من $name';
  @override
  String get bookingLink => 'رابط الحجز';
  @override
  String get bookingLinkHint => 'حطه في بايو إنستجرام أو حالة واتساب، والعميل يحجز من غير ما ينزّل التطبيق.';
  @override
  String get copied => 'اتنسخ';
  @override
  String get changeStatus => 'تغيير الحالة';

  @override
  String get profile => 'حسابي';
  @override
  String get language => 'اللغة';
  @override
  String get logout => 'تسجيل خروج';
  @override
  String get dataSource => 'مصدر البيانات';
  @override
  String get dataSourceFake => 'تجريبي على الجهاز';
  @override
  String get dataSourceApi => 'Spring Boot API';
  @override
  String get roleCustomer => 'عميل';
  @override
  String get roleOwner => 'صاحب مكان';
  @override
  String get roleReception => 'الاستقبال';

  @override
  String get errSlotTaken => 'الموعد ده لسه اتحجز. اختار وقت تاني.';
  @override
  String get errOffline => 'مفيش اتصال بالإنترنت.';
  @override
  String get errServer => 'حصلت مشكلة، حاول تاني.';
  @override
  String get errUnauthorized => 'سجّل دخول تاني.';
  @override
  String get errTooLate => 'التعديل والإلغاء متاحين لحد ٣ ساعات قبل الموعد.';
  @override
  String get errInvalidPhone => 'اكتب الرقم بالصيغة الدولية، مثلًا ‎+971501234567';
  @override
  String get errOtp => 'الكود غلط أو انتهى.';
  @override
  String get errPast => 'الوقت ده عدّى.';
  @override
  String get errInvalidDuration => 'المدة من ١٥ لـ ٤٨٠ دقيقة، بفرق ١٥.';
  @override
  String get errRequired => 'مطلوب';
  @override
  String get retry => 'حاول تاني';
}

class EnStrings extends AppLocalizations {
  const EnStrings();

  @override
  String get localeName => 'en';

  @override
  String get welcomeTitle => 'Book in seconds';
  @override
  String get welcomeSubtitle => 'Clinics and salons near you. No calls, no waiting.';
  @override
  String get phoneLabel => 'Mobile number';
  @override
  String get continueLabel => 'Continue';
  @override
  String get or => 'or';
  @override
  String get tryAsCustomer => 'Try as customer';
  @override
  String get tryAsOwner => 'Try as owner';
  @override
  String get tryAsReception => 'Try as clinic reception';
  @override
  String get demoHint => 'Demo build: the code is always 123456';
  @override
  String get otpTitle => 'Enter the code';
  @override
  String otpSentTo(String phone) => 'We sent a 6-digit code to $phone';
  @override
  String get otpLabel => 'Code';
  @override
  String get verify => 'Verify';
  @override
  String get resend => 'Resend code';
  @override
  String get yourName => 'Your name';

  @override
  String get navHome => 'Home';
  @override
  String get navExplore => 'Explore';
  @override
  String get navBookings => 'Bookings';
  @override
  String get navProfile => 'Profile';
  @override
  String get navSchedule => 'Schedule';
  @override
  String get navServices => 'Services';
  @override
  String get navDesk => 'Front desk';

  @override
  String get goodMorning => 'Good morning';
  @override
  String get goodEvening => 'Good evening';
  @override
  String get guest => 'there';
  @override
  String get searchHint => 'Search clinics, salons or services';
  @override
  String get nextAppointment => 'Next appointment';
  @override
  String inTime(int minutes) {
    if (minutes < 60) return 'In $minutes min';
    final h = (minutes / 60).round();
    if (h < 24) return h == 1 ? 'In 1 hour' : 'In $h hours';
    final d = (minutes / 1440).round();
    return d == 1 ? 'Tomorrow' : 'In $d days';
  }

  @override
  String get details => 'Details';
  @override
  String get reschedule => 'Reschedule';
  @override
  String get categories => 'Categories';
  @override
  String get categoryClinic => 'Clinics';
  @override
  String get categoryDental => 'Dental';
  @override
  String get categorySalon => 'Salons';
  @override
  String get categorySpa => 'Spa';
  @override
  String get allCategories => 'All';
  @override
  String get nearYou => 'Near you';
  @override
  String get seeAll => 'See all';
  @override
  String get openToday => 'Open today';
  @override
  String get closedToday => 'Closed today';
  @override
  String km(String value) => '$value km';
  @override
  String get noResults => 'Nothing found. Try another word.';
  @override
  String get servicesTab => 'Services';
  @override
  String get teamTab => 'Team';
  @override
  String get reviewsTab => 'Reviews';
  @override
  String reviewsCount(String n) => '($n reviews)';
  @override
  String get book => 'Book';
  @override
  String get bookAppointment => 'Book an appointment';
  @override
  String minutes(String n) => '$n min';
  @override
  String get noReviews => 'No reviews yet.';
  @override
  String hours(String from, String to) => 'Open $from to $to';

  @override
  String get chooseTime => 'Choose a time';
  @override
  String get availableTimes => 'Available times';
  @override
  String get available => 'Available';
  @override
  String get booked => 'Booked';
  @override
  String get withWhom => 'With whom?';
  @override
  String get anyone => 'Anyone available';
  @override
  String get yourAppointment => 'Your appointment';
  @override
  String get confirm => 'Confirm';
  @override
  String get noSlots => 'No times left that day. Try another day.';
  @override
  String get closedDay => 'Closed';
  @override
  String get bookingConfirmed => 'Your booking is confirmed';
  @override
  String get bookingConfirmedSub =>
      "You'll get a reminder an hour before. You can change or cancel up to 3 hours before.";
  @override
  String get rescheduled => 'Appointment moved';
  @override
  String get placeLabel => 'Place';
  @override
  String get serviceLabel => 'Service';
  @override
  String get dateTimeLabel => 'When';
  @override
  String get staffLabel => 'With';
  @override
  String get paymentLabel => 'Payment';
  @override
  String get payAtPlace => 'At the place';
  @override
  String get total => 'Total';
  @override
  String get directions => 'Directions';
  @override
  String get whatsapp => 'WhatsApp';
  @override
  String get backHome => 'Back to home';

  @override
  String get myBookings => 'My bookings';
  @override
  String get upcoming => 'Upcoming';
  @override
  String get past => 'Past';
  @override
  String get noBookings => 'No bookings yet';
  @override
  String get noBookingsHint => 'Book your first appointment from Home.';
  @override
  String get cancel => 'Cancel';
  @override
  String get cancelTitle => 'Cancel this appointment?';
  @override
  String get cancelBody => 'The time becomes available for someone else.';
  @override
  String get keepIt => 'Keep it';
  @override
  String get yesCancel => 'Yes, cancel';
  @override
  String get changeLocked => 'You can change or cancel up to 3 hours before.';
  @override
  String get bookingCancelled => 'Appointment cancelled';

  @override
  String get statusPending => 'New';
  @override
  String get statusConfirmed => 'Upcoming';
  @override
  String get statusInProgress => 'Now';
  @override
  String get statusCompleted => 'Done';
  @override
  String get statusCancelled => 'Cancelled';
  @override
  String get statusNoShow => 'No-show';
  @override
  String get statusArrived => 'Arrived';
  @override
  String get showAtReception => 'When you arrive, show this code at reception';
  @override
  String yourTicket(String n) => "You're checked in · your number is $n";

  @override
  String dashboardOf(String place) => 'Dashboard · $place';
  @override
  String get todaysAppointments => "Today's appointments";
  @override
  String get bookingsCount => 'Bookings';
  @override
  String get completedCount => 'Done';
  @override
  String get newCount => 'New';
  @override
  String get schedule => 'Schedule';
  @override
  String get manualBooking => 'Walk-in';
  @override
  String get emptyDay => 'No bookings on this day.';
  @override
  String get markInProgress => 'Started';
  @override
  String get markCompleted => 'Done';
  @override
  String get markNoShow => 'No-show';
  @override
  String get confirmBooking => 'Confirm booking';
  @override
  String get customerName => 'Customer name';
  @override
  String get customerPhone => 'Customer mobile';
  @override
  String get save => 'Save';
  @override
  String get addService => 'Add service';
  @override
  String get editService => 'Edit service';
  @override
  String get nameAr => 'Name (Arabic)';
  @override
  String get nameEn => 'Name (English)';
  @override
  String get durationMin => 'Duration (minutes)';
  @override
  String get price => 'Price';
  @override
  String get activeService => 'Bookable';
  @override
  String get hiddenService => 'Hidden';
  @override
  String get saved => 'Saved';
  @override
  String newBookingFrom(String name) => 'New booking from $name';
  @override
  String get bookingLink => 'Booking link';
  @override
  String get bookingLinkHint =>
      'Put it in your Instagram bio or WhatsApp status. Customers book without installing anything.';
  @override
  String get copied => 'Copied';
  @override
  String get changeStatus => 'Change status';

  @override
  String get profile => 'Profile';
  @override
  String get language => 'Language';
  @override
  String get logout => 'Sign out';
  @override
  String get dataSource => 'Data source';
  @override
  String get dataSourceFake => 'On-device demo';
  @override
  String get dataSourceApi => 'Spring Boot API';
  @override
  String get roleCustomer => 'Customer';
  @override
  String get roleOwner => 'Business owner';
  @override
  String get roleReception => 'Front desk';

  @override
  String get errSlotTaken => 'That time was just booked. Pick another one.';
  @override
  String get errOffline => 'No internet connection.';
  @override
  String get errServer => 'Something went wrong. Please try again.';
  @override
  String get errUnauthorized => 'Please sign in again.';
  @override
  String get errTooLate => 'You can change or cancel up to 3 hours before.';
  @override
  String get errInvalidPhone => 'Use international format, e.g. +971501234567';
  @override
  String get errOtp => 'Wrong or expired code.';
  @override
  String get errPast => 'That time has passed.';
  @override
  String get errInvalidDuration => 'Duration must be 15 to 480 minutes, in steps of 15.';
  @override
  String get errRequired => 'Required';
  @override
  String get retry => 'Try again';
}

class _Delegate extends LocalizationsDelegate<AppLocalizations> {
  const _Delegate();

  @override
  bool isSupported(Locale locale) => const ['ar', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(AppLocalizations.forLocale(locale));

  @override
  bool shouldReload(_Delegate old) => false;
}

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
