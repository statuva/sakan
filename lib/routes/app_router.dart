import 'package:go_router/go_router.dart';
import 'package:sakan/app/app_shell.dart';
import 'package:sakan/features/home/presentation/home_screen.dart';
import 'package:sakan/features/profile/presentation/profile_screen.dart';
import 'package:sakan/features/digital_twin/presentation/digital_twin_screen.dart';
import 'package:sakan/features/calendar/presentation/calendar_screen.dart';


final GoRouter appRouter = GoRouter(
  initialLocation: '/home',
  routes: [ 
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              name: 'home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/digital-twin',
              name: 'digitalTwin',
              builder: (context, state) => const DigitalTwinScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              name: 'profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/calendar',
              name: 'calendar',
              builder: (context, state) => const CalendarScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
