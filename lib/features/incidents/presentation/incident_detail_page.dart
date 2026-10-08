import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../domain/incident_report.dart';

/// Read-only detail view for a ranger's own locally saved or submitted report.
class IncidentDetailPage extends StatefulWidget {
  const IncidentDetailPage({required this.report, super.key});

  final IncidentReport report;

  @override
  State<IncidentDetailPage> createState() => _IncidentDetailPageState();
}

class _IncidentDetailPageState extends State<IncidentDetailPage> {
  late Future<List<IncidentEvidence>> _evidenceFuture;

  @override
  void initState() {
    super.initState();
    _evidenceFuture = _loadEvidence();
  }

  Future<List<IncidentEvidence>> _loadEvidence() async {
    if (widget.report.evidence.isNotEmpty ||
        widget.report.status != IncidentStatus.reported) {
      return widget.report.evidence;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('incidents')
        .doc(widget.report.id)
        .collection('evidence')
        .get();
    return snapshot.docs
        .map((doc) {
          final data = doc.data();
          return IncidentEvidence(
            id: doc.id,
            fileName: data['fileName']?.toString() ?? 'Evidence photo',
            base64Data: data['base64Data']?.toString() ?? '',
            contentType: data['contentType']?.toString() ?? 'image/jpeg',
          );
        })
        .where((photo) => photo.base64Data.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final hasLocation = report.latitude != null && report.longitude != null;
    final status = switch (report.status) {
      IncidentStatus.reported => 'Reported',
      IncidentStatus.pendingSync => 'Pending Sync',
      IncidentStatus.syncFailed => 'Sync needs attention',
      IncidentStatus.draft => 'Draft',
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F3),
      appBar: AppBar(title: const Text('Incident details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          report.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Chip(label: Text(status)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _detail('Type', report.type.label),
                  _detail('Severity', report.severity.label),
                  _detail('Active threat', report.activeThreat ? 'Yes' : 'No'),
                  _detail('Incident status', report.workflowStatus.label),
                  _detail('Reported', _formatDate(report.createdAt)),
                  _detail(
                    'Ranger',
                    report.rangerEmail.isEmpty
                        ? report.rangerId
                        : report.rangerEmail,
                  ),
                  _detail(
                    'Park / block',
                    report.parkOrBlock.isEmpty
                        ? 'Not provided'
                        : report.parkOrBlock,
                  ),
                  _detail(
                    'Patrol ID',
                    report.patrolId?.isNotEmpty == true
                        ? report.patrolId!
                        : 'Not linked',
                  ),
                  const Divider(height: 24),
                  const Text(
                    'Description',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    report.description.isEmpty
                        ? 'No description provided.'
                        : report.description,
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Incident location'),
              subtitle: Text(
                hasLocation
                    ? '${report.latitude!.toStringAsFixed(6)}, '
                          '${report.longitude!.toStringAsFixed(6)}\n'
                          '${report.manualLocation ? 'Entered manually' : 'Captured by GPS'}'
                    : 'Location was not recorded',
              ),
              isThreeLine: hasLocation,
            ),
          ),
          const SizedBox(height: 8),
          Text('Evidence', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          FutureBuilder<List<IncidentEvidence>>(
            future: _evidenceFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.cloud_off_outlined),
                    title: const Text('Evidence could not be loaded'),
                    subtitle: Text(snapshot.error.toString()),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final photos = snapshot.data!;
              if (photos.isEmpty) {
                return const Card(
                  child: ListTile(
                    leading: Icon(Icons.photo_outlined),
                    title: Text('No evidence photos attached'),
                  ),
                );
              }
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: photos.map(_evidenceTile).toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          SelectableText(
            'Report ID: ${report.id}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _evidenceTile(IncidentEvidence photo) {
    final bytes = base64Decode(photo.base64Data);
    return InkWell(
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.memory(bytes, fit: BoxFit.contain),
                const SizedBox(height: 8),
                Text(photo.fileName),
              ],
            ),
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(bytes, width: 104, height: 104, fit: BoxFit.cover),
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 116,
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );

  String _formatDate(DateTime date) =>
      date.toLocal().toString().substring(0, 16);
}
