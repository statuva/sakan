import 'package:go_router/go_router.dart';
import 'package:sakan/app/app_shell.dart';
import 'package:sakan/features/home/presentation/home_screen.dart';
import 'package:sakan/features/profile/presentation/profile_screen.dart';
import 'package:sakan/features/digital_twin/presentation/digital_twin_screen.dart';
import 'package:sakan/features/calendar/presentation/calendar_screen.dart';

import 'package:sakan/features/authentication/presentation/forgot_password_screen.dart';
import 'package:sakan/features/authentication/presentation/sign_in_Screen.dart';
import 'package:sakan/features/authentication/presentation/sign_up_screen.dart';
import 'package:sakan/features/authentication/presentation/startup_screen.dart';

import 'package:sakan/features/family_setup/presentation/create_family_screen.dart';
import 'package:sakan/features/family_setup/presentation/family_access_screen.dart';
import 'package:sakan/features/family_setup/presentation/family_created_screen.dart';
import 'package:sakan/features/family_setup/presentation/family_setup_screen.dart';
import 'package:sakan/features/family_setup/presentation/join_family_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/startup',
  routes: [
    GoRoute(
      path: '/startup',
      builder: (context, state) => const StartupScreen(),
    ),

    GoRoute(
      path: '/sign-in',
      builder: (context, state) => const SignInScreen(),
    ),

    GoRoute(
      path: '/sign-up',
      builder: (context, state) => const SignUpScreen(),
    ),

    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),

    GoRoute(
      path: '/family-access',
      builder: (context, state) => const FamilyAccessScreen(),
    ),

    GoRoute(
      path: '/create-family',
      builder: (context, state) => const CreateFamilyScreen(),
    ),

    GoRoute(
      path: '/family-created',
      builder: (context, state) {
        final code = state.uri.queryParameters['code'] ?? '';

        return FamilyCreatedScreen(invitationCode: code);
      },
    ),

    GoRoute(
      path: '/join-family',
      builder: (context, state) => const JoinFamilyScreen(),
    ),

    GoRoute(
      path: '/family-setup',
      builder: (context, state) => const FamilySetupScreen(),
    ),

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
