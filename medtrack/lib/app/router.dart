import 'package:go_router/go_router.dart';

import '../features/alerts/presentation/screens/alerts_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/dashboard/presentation/screens/caregiver_dashboard_screen.dart';
import '../features/medication/presentation/screens/today_schedule_screen.dart';
import '../features/symptom_tracking/presentation/screens/log_symptom_screen.dart';
import 'home_shell.dart';

/// Route paths carry `patientId` explicitly rather than reading it from
/// a global session, so a caregiver can open any linked patient's
/// schedule/dashboard from the same routes a patient uses for themself.
final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/home',
      builder: (context, state) => HomeShell(
        patientId: state.uri.queryParameters['patientId'] ?? 'me',
      ),
    ),
    GoRoute(
      path: '/schedule',
      builder: (context, state) => TodayScheduleScreen(
        patientId: state.uri.queryParameters['patientId'] ?? 'me',
      ),
    ),
    GoRoute(
      path: '/symptoms/log',
      builder: (context, state) => LogSymptomScreen(
        patientId: state.uri.queryParameters['patientId'] ?? 'me',
      ),
    ),
    GoRoute(path: '/alerts', builder: (context, state) => const AlertsScreen()),
    GoRoute(
      path: '/dashboard/:patientId',
      builder: (context, state) => CaregiverDashboardScreen(
        patientId: state.pathParameters['patientId']!,
      ),
    ),
  ],
);
