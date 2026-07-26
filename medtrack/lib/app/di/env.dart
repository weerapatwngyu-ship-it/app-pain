/// Build-time configuration. Override per environment with:
/// `flutter run --dart-define=API_BASE_URL=https://api.medtrack.example.com`
class Env {
  const Env._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.medtrack.local',
  );
}
