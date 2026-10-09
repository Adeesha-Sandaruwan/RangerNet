import 'package:flutter/material.dart';

class PatrolNetworkStatusCard extends StatelessWidget {
  const PatrolNetworkStatusCard({
    required this.online,
    this.onRefresh,
    super.key,
  });

  final bool? online;
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
