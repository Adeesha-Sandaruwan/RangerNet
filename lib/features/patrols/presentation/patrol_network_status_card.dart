import 'package:flutter/material.dart';

/// Shows online, offline, or checking status and an optional refresh action.
/// SRP: presents connectivity without performing network checks itself.
class PatrolNetworkStatusCard extends StatelessWidget {
  const PatrolNetworkStatusCard({
    required this.online,
    this.onRefresh,
    super.key,
  });

  /// Connectivity state; null means that the initial check is unresolved.
  final bool? online;
  /// Optional callback that asks the owner to refresh connectivity.
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final label = switch (online) {
      true => 'Online',
      false => 'Offline · patrol data stays on this device',
      null => 'Checking network status',
    };
    return Card(
      child: ListTile(
        dense: false,
        leading: Icon(
          online == true
              ? Icons.wifi
              : online == false
              ? Icons.wifi_off
              : Icons.wifi_find,
          semanticLabel: label,
        ),
        title: Text(label, style: Theme.of(context).textTheme.titleSmall),
        trailing: onRefresh == null
            ? null
            : IconButton(
                tooltip: 'Refresh network status',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
              ),
      ),
    );
  }
}
