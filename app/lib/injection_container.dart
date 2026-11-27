import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'core/fake/fake_backend.dart';
import 'core/locale/locale_cubit.dart';
import 'core/network/api_client.dart';
import 'core/session/booking_changes.dart';
import 'core/session/session.dart';
import 'core/storage/local_store.dart';
import 'features/auth/data/datasources/auth_data_source.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/auth_usecases.dart';
import 'features/auth/presentation/cubit/login_cubit.dart';
import 'features/auth/presentation/cubit/session_cubit.dart';
import 'features/booking/data/datasources/booking_data_source.dart';
import 'features/booking/data/repositories/booking_repository_impl.dart';
import 'features/booking/domain/repositories/booking_repository.dart';
import 'features/booking/domain/usecases/cancel_booking.dart';
import 'features/booking/domain/usecases/create_booking.dart';
import 'features/booking/domain/usecases/get_available_slots.dart';
import 'features/booking/domain/usecases/get_my_bookings.dart';
import 'features/booking/domain/usecases/reschedule_booking.dart';
import 'features/booking/presentation/bloc/booking_bloc.dart';
import 'features/booking/presentation/cubit/my_bookings_cubit.dart';
import 'features/desk/data/datasources/desk_data_source.dart';
import 'features/desk/data/repositories/desk_repository_impl.dart';
import 'features/desk/domain/repositories/desk_repository.dart';
import 'features/desk/domain/usecases/desk_usecases.dart';
import 'features/desk/presentation/cubit/audit_cubit.dart';
import 'features/desk/presentation/cubit/desk_cubit.dart';
import 'features/desk/presentation/cubit/invoices_cubit.dart';
import 'features/owner/data/datasources/owner_data_source.dart';
import 'features/owner/data/repositories/owner_repository_impl.dart';
import 'features/owner/domain/repositories/owner_repository.dart';
import 'features/owner/domain/usecases/owner_usecases.dart';
import 'features/owner/presentation/cubit/owner_dashboard_cubit.dart';
import 'features/owner/presentation/cubit/owner_services_cubit.dart';
import 'features/places/data/datasources/places_data_source.dart';
import 'features/places/data/repositories/places_repository_impl.dart';
import 'features/places/domain/repositories/places_repository.dart';
import 'features/places/domain/usecases/get_place_details.dart';
import 'features/places/domain/usecases/get_places.dart';
import 'features/places/presentation/cubit/home_cubit.dart';
import 'features/places/presentation/cubit/place_details_cubit.dart';

/// Service locator. Every class gets what it needs through its constructor; this file is the
/// only place that knows which implementation is used. Switching from the offline demo to
/// the Spring Boot API is the `backend` switch below, nothing else changes.
final sl = GetIt.instance;

Future<void> initDependencies({BackendKind? backend, SharedPreferences? prefs, FakeBackend? fakeBackend}) async {
  await sl.reset();
  final kind = backend ?? AppConfig.backend;

  // ---------------------------------------------------------------- core
  sl.registerSingleton<LocalStore>(LocalStore(prefs ?? await SharedPreferences.getInstance()));
  sl.registerSingleton<Session>(Session());
  sl.registerSingleton<BookingChanges>(BookingChanges());
  sl.registerLazySingleton<ApiClient>(() => ApiClient(baseUrl: AppConfig.apiUrl, tokenProvider: () => sl<Session>().token));
  sl.registerLazySingleton<FakeBackend>(() => fakeBackend ?? FakeBackend(sl<Session>()));
  sl.registerLazySingleton(() => LocaleCubit(sl()));

  // ---------------------------------------------------------------- data sources (the only switch)
  if (kind == BackendKind.api) {
    sl.registerLazySingleton<AuthDataSource>(() => AuthApiDataSource(sl()));
    sl.registerLazySingleton<PlacesDataSource>(() => PlacesApiDataSource(sl()));
    sl.registerLazySingleton<BookingDataSource>(() => BookingApiDataSource(sl()));
    sl.registerLazySingleton<OwnerDataSource>(() => OwnerApiDataSource(sl()));
    sl.registerLazySingleton<DeskDataSource>(() => DeskApiDataSource(sl()));
  } else {
    sl.registerLazySingleton<AuthDataSource>(() => AuthFakeDataSource(sl()));
    sl.registerLazySingleton<PlacesDataSource>(() => PlacesFakeDataSource(sl()));
    sl.registerLazySingleton<BookingDataSource>(() => BookingFakeDataSource(sl()));
    sl.registerLazySingleton<OwnerDataSource>(() => OwnerFakeDataSource(sl()));
    sl.registerLazySingleton<DeskDataSource>(() => DeskFakeDataSource(sl()));
  }

  // ---------------------------------------------------------------- repositories
  sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(remote: sl(), store: sl(), session: sl()));
  sl.registerLazySingleton<PlacesRepository>(() => PlacesRepositoryImpl(sl()));
  sl.registerLazySingleton<BookingRepository>(() => BookingRepositoryImpl(sl(), changes: sl()));
  sl.registerLazySingleton<OwnerRepository>(() => OwnerRepositoryImpl(sl()));
  // One instance for the whole run: it owns the offline queue and its retry timer.
  sl.registerLazySingleton<DeskRepository>(() => DeskRepositoryImpl(sl(), sl()));

  // ---------------------------------------------------------------- use cases
  sl.registerLazySingleton(() => RequestOtp(sl()));
  sl.registerLazySingleton(() => VerifyOtp(sl()));
  sl.registerLazySingleton(() => DemoLogin(sl()));
  sl.registerLazySingleton(() => SignOut(sl()));
  sl.registerLazySingleton(() => GetPlaces(sl()));
  sl.registerLazySingleton(() => GetPlaceDetails(sl()));
  sl.registerLazySingleton(() => GetAvailableSlots(sl()));
  sl.registerLazySingleton(() => CreateBooking(sl()));
  sl.registerLazySingleton(() => CancelBooking(sl()));
  sl.registerLazySingleton(() => RescheduleBooking(sl()));
  sl.registerLazySingleton(() => GetMyBookings(sl()));
  sl.registerLazySingleton(() => GetOwnerPlace(sl()));
  sl.registerLazySingleton(() => GetDaySchedule(sl()));
  sl.registerLazySingleton(() => UpdateBookingStatus(sl()));
  sl.registerLazySingleton(() => AddManualBooking(sl()));
  sl.registerLazySingleton(() => SaveService(sl()));
  sl.registerLazySingleton(() => CheckInByScan(sl()));
  sl.registerLazySingleton(() => AddWalkIn(sl()));
  sl.registerLazySingleton(() => IssueInvoice(sl()));
  sl.registerLazySingleton(() => EditInvoice(sl()));

  // ---------------------------------------------------------------- state
  sl.registerLazySingleton(() => SessionCubit(repository: sl(), signOutUseCase: sl()));
  sl.registerFactory(() => LoginCubit(requestOtp: sl(), verifyOtp: sl(), demoLogin: sl(), session: sl()));
  sl.registerFactory(() => HomeCubit(getPlaces: sl(), getMyBookings: sl(), changes: sl()));
  sl.registerFactory(() => MyBookingsCubit(sl(), changes: sl()));
  sl.registerFactoryParam<PlaceDetailsCubit, String, void>((placeId, _) => PlaceDetailsCubit(sl(), placeId));
  sl.registerFactory(() => BookingBloc(sl(), sl(), getPlaceDetails: sl(), rescheduleBooking: sl()));
  sl.registerFactory(() => OwnerDashboardCubit(getPlace: sl(), getDay: sl(), updateStatus: sl(), repository: sl()));
  sl.registerFactory(() => OwnerServicesCubit(getPlace: sl(), saveService: sl()));
  sl.registerFactory(() => DeskCubit(repository: sl(), checkInByScan: sl(), addWalkIn: sl()));
  sl.registerFactory(() => InvoicesCubit(repository: sl(), issueInvoice: sl(), editInvoice: sl()));
  sl.registerFactory(() => AuditCubit(sl()));
}
