import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/cubit/login_cubit.dart';
import '../../features/auth/presentation/cubit/session_cubit.dart';
import '../../features/auth/presentation/pages/otp_page.dart';
import '../../features/auth/presentation/pages/welcome_page.dart';
import '../../features/booking/domain/entities/booking.dart';
import '../../features/booking/presentation/bloc/booking_bloc.dart';
import '../../features/booking/presentation/cubit/my_bookings_cubit.dart';
import '../../features/booking/presentation/pages/booking_confirmed_page.dart';
import '../../features/booking/presentation/pages/my_bookings_page.dart';
import '../../features/booking/presentation/pages/select_slot_page.dart';
import '../../features/owner/presentation/cubit/owner_dashboard_cubit.dart';
import '../../features/owner/presentation/cubit/owner_services_cubit.dart';
import '../../features/owner/presentation/pages/owner_dashboard_page.dart';
import '../../features/owner/presentation/pages/owner_services_page.dart';
import '../../features/places/domain/entities/place.dart';
import '../../features/places/presentation/cubit/explore_cubit.dart';
import '../../features/places/presentation/cubit/home_cubit.dart';
import '../../features/places/presentation/cubit/place_details_cubit.dart';
import '../../features/places/presentation/pages/explore_page.dart';
import '../../features/places/presentation/pages/home_page.dart';
import '../../features/places/presentation/pages/place_details_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../injection_container.dart';
import '../l10n/app_localizations.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Routes and guards. Signed-out users only see /welcome; owners land on /owner, customers on /home.
GoRouter buildRouter(SessionCubit session) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/home',
    refreshListenable: _StreamListenable(session.stream),
    redirect: (context, state) {
      final s = session.state;
      final loc = state.matchedLocation;
      final inWelcome = loc.startsWith('/welcome');
      if (s.status != SessionStatus.signedIn) return inWelcome ? null : '/welcome';
      final isOwner = s.user!.isOwner;
      if (inWelcome) return isOwner ? '/owner' : '/home';
      if (isOwner && !loc.startsWith('/owner')) return '/owner';
      if (!isOwner && loc.startsWith('/owner')) return '/home';
      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => BlocProvider(create: (_) => sl<LoginCubit>(), child: child),
        routes: [
          GoRoute(
            path: '/welcome',
            builder: (_, __) => const WelcomePage(),
            routes: [GoRoute(path: 'otp', builder: (_, __) => const OtpPage())],
          ),
        ],
      ),

      // ------------------------------------------------------------ customer
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _CustomerShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (_, __) => BlocProvider(create: (_) => sl<HomeCubit>()..load(), child: const HomePage()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/explore',
              builder: (_, state) {
                final cat = state.uri.queryParameters['category'];
                final category = PlaceCategory.values.where((c) => c.name == cat).firstOrNull;
                return BlocProvider(
                  key: ValueKey(state.uri.toString()),
                  create: (_) => ExploreCubit(sl(), initialCategory: category)..load(),
                  child: ExplorePage(autofocus: state.uri.queryParameters['focus'] == '1'),
                );
              },
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/bookings',
              builder: (_, __) =>
                  BlocProvider(create: (_) => sl<MyBookingsCubit>()..load(), child: const MyBookingsPage()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
          ]),
        ],
      ),
      GoRoute(
        path: '/place/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) => BlocProvider(
          create: (_) => sl<PlaceDetailsCubit>(param1: state.pathParameters['id']!)..load(),
          child: const PlaceDetailsPage(),
        ),
        routes: [
          GoRoute(
            path: 'book',
            parentNavigatorKey: _rootKey,
            builder: (_, state) => BlocProvider(
              create: (_) => sl<BookingBloc>()
                ..add(BookingStarted(
                  placeId: state.pathParameters['id']!,
                  serviceId: state.uri.queryParameters['serviceId'],
                  details: state.extra is PlaceDetails ? state.extra! as PlaceDetails : null,
                )),
              child: const SelectSlotPage(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/bookings/:id/reschedule',
        parentNavigatorKey: _rootKey,
        redirect: (_, state) => state.extra is Booking ? null : '/bookings',
        builder: (_, state) {
          final booking = state.extra! as Booking;
          return BlocProvider(
            create: (_) => sl<BookingBloc>()..add(BookingStarted(placeId: booking.placeId, rescheduling: booking)),
            child: const SelectSlotPage(),
          );
        },
      ),
      GoRoute(
        path: '/booking/confirmed',
        parentNavigatorKey: _rootKey,
        redirect: (_, state) => state.extra is Booking ? null : '/home',
        builder: (_, state) => BookingConfirmedPage(booking: state.extra! as Booking),
      ),

      // ------------------------------------------------------------ owner
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _OwnerShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/owner',
              builder: (_, __) =>
                  BlocProvider(create: (_) => sl<OwnerDashboardCubit>()..load(), child: const OwnerDashboardPage()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/owner/services',
              builder: (_, __) =>
                  BlocProvider(create: (_) => sl<OwnerServicesCubit>()..load(), child: const OwnerServicesPage()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/owner/profile', builder: (_, __) => const ProfilePage()),
          ]),
        ],
      ),
    ],
  );
}

class _CustomerShell extends StatelessWidget {
  const _CustomerShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: l10n.navHome),
          NavigationDestination(icon: const Icon(Icons.search), label: l10n.navExplore),
          NavigationDestination(
              icon: const Icon(Icons.calendar_month_outlined),
              selectedIcon: const Icon(Icons.calendar_month),
              label: l10n.navBookings),
          NavigationDestination(
              icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: l10n.navProfile),
        ],
      ),
    );
  }
}

class _OwnerShell extends StatelessWidget {
  const _OwnerShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.calendar_today_outlined),
              selectedIcon: const Icon(Icons.calendar_today),
              label: l10n.navSchedule),
          NavigationDestination(
              icon: const Icon(Icons.design_services_outlined),
              selectedIcon: const Icon(Icons.design_services),
              label: l10n.navServices),
          NavigationDestination(
              icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: l10n.navProfile),
        ],
      ),
    );
  }
}

/// Lets GoRouter re-run redirects whenever the session changes.
class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
