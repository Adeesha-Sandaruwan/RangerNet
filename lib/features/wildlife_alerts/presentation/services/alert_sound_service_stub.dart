import 'package:flutter/services.dart';

void playHighRiskAlarmImpl() {
  SystemSound.play(SystemSoundType.alert);
  HapticFeedback.heavyImpact();
}
