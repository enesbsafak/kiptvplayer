/// The app version. Release builds pass it in (`--dart-define=KP_VERSION=1.2.0`,
/// see tools/release.ps1); development builds show the pubspec's base version.
const appVersion = String.fromEnvironment('KP_VERSION', defaultValue: '0.1.0');
