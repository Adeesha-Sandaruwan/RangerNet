import 'package:flutter/material.dart';
import '../../domain/models/wildlife_alert.dart';
import '../services/alert_sound_service.dart';

class RiskLevelBadge extends StatelessWidget {
  const RiskLevelBadge({required this.riskLevel, this.isLarge = false, super.key});

  final AlertRiskLevel riskLevel;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;

    switch (riskLevel) {
      case AlertRiskLevel.high:
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFC62828);
        icon = Icons.warning_rounded;
        break;
      case AlertRiskLevel.medium:
        bg = const Color(0xFFFFF8E1);
        fg = const Color(0xFFE65100);
        icon = Icons.info_outline;
        break;
      case AlertRiskLevel.low:
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        icon = Icons.check_circle_outline;
        break;
    }

    final badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge ? 12 : 8,
        vertical: isLarge ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isLarge ? 16 : 13, color: fg),
          const SizedBox(width: 4),
          Text(
            '${riskLevel.label} RISK',
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.bold,
              fontSize: isLarge ? 12 : 10,
              letterSpacing: 0.5,
            ),
          ),
          if (riskLevel == AlertRiskLevel.high) ...[
            const SizedBox(width: 4),
            Icon(Icons.volume_up, size: isLarge ? 14 : 11, color: fg),
          ],
        ],
      ),
    );

    if (riskLevel == AlertRiskLevel.high) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: AlertSoundService.playHighRiskAlarm,
          child: badge,
        ),
      );
    }

    return badge;
  }
}

class AlertStatusBadge extends StatelessWidget {
  const AlertStatusBadge({required this.status, this.isLarge = false, super.key});

  final AlertStatus status;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;

    switch (status) {
      case AlertStatus.active:
        bg = const Color(0xFFFFE0B2);
        fg = const Color(0xFFD84315);
        icon = Icons.radio_button_checked;
        break;
      case AlertStatus.acknowledged:
        bg = const Color(0xFFE1F5FE);
        fg = const Color(0xFF0277BD);
        icon = Icons.visibility;
        break;
      case AlertStatus.resolved:
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        icon = Icons.done_all;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge ? 12 : 8,
        vertical: isLarge ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isLarge ? 15 : 12, color: fg),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: isLarge ? 12 : 10,
            ),
          ),
        ],
      ),
    );
  }
}
