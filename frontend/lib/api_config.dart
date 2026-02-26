/// Centralized API configuration for AgriChain.
///
/// Toggle [useUsb] to switch between network modes:
///   - Wi-Fi / LAN:  connects via your machine's network IP
///   - USB (adb reverse): connects via localhost forwarded over USB
class ApiConfig {
  // ── Toggle this flag based on your connection method ──
  static const bool useUsb = false;

  // Your laptop's LAN IP (run `ip addr` or `ifconfig` to find it)
  static const String lanIp = '10.0.2.2';

  // Localhost via `adb reverse tcp:8080 tcp:8080`
  static const String usbIp = '127.0.0.1';

  // Android emulator special IP
  static const String emulatorIp = '10.0.2.2';

  static const int port = 8080;

  /// The resolved base URL depending on the connection mode.
  static String get baseUrl {
    final ip = useUsb ? usbIp : lanIp;
    return 'http://$ip:$port';
  }
}
