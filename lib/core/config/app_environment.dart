abstract final class AppEnvironment {
  static const bool useDemoData = bool.fromEnvironment(
    'USE_DEMO_DATA',
    defaultValue: false,
  );
}
