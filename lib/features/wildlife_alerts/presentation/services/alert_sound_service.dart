import 'alert_sound_service_stub.dart'
    if (dart.library.js_interop) 'alert_sound_service_web.dart'
    as sound_impl;

/// Service for playing tactical audio alarms for high-risk wildlife alerts.
class AlertSoundService {
  AlertSoundService._();

  /// Plays an urgent acoustic alarm (dual-frequency siren pulse).
  static void playHighRiskAlarm() {
    sound_impl.playHighRiskAlarmImpl();
  }
}
