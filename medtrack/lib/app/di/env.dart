/// Build-time configuration. Override per environment with:
/// `flutter run --dart-define=API_BASE_URL=https://api.medtrack.example.com`
class Env {
  const Env._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.medtrack.local',
  );

  /// No backend exists yet, so repositories default to in-memory mock
  /// data. Once a real API is deployed, run with
  /// `flutter run --dart-define=USE_MOCK_BACKEND=false --dart-define=API_BASE_URL=...`
  static const useMockBackend = bool.fromEnvironment(
    'USE_MOCK_BACKEND',
    defaultValue: true,
  );
}
