import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/incident_evidence_picker.dart';
import '../data/incident_location_service.dart';
import '../domain/incident_report.dart';

class IncidentReportPage extends StatefulWidget {
  const IncidentReportPage({
    required this.ranger,
    required this.saveLocally,
    required this.syncNow,
    super.key,
  });

  final User ranger;
  final Future<void> Function(IncidentReport report) saveLocally;
  final Future<void> Function(IncidentReport report) syncNow;

  @override
  State<IncidentReportPage> createState() => _IncidentReportPageState();
}

class _IncidentReportPageState extends State<IncidentReportPage> {
  static const _uuid = Uuid();
  static const _stepTitles = [
    'What are you reporting?',
    'Describe the incident',
    'Where did it happen?',
    'Add evidence photos',
    'Review and submit',
  ];

  final _title = TextEditingController();
  final _description = TextEditingController();
  final _parkOrBlock = TextEditingController();
  final _patrolId = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _locationService = IncidentLocationService();
  final _evidencePicker = IncidentEvidencePicker();

  int _step = 0;
  IncidentType? _type;
  IncidentSeverity _severity = IncidentSeverity.medium;
  bool _activeThreat = false;
  bool _manualLocation = false;
  bool _confirmDetails = false;
  bool _busy = false;
  double? _accuracy;
  List<IncidentEvidence> _evidence = [];
  String? _error;
  IncidentReport? _submittedReport;
  bool _synced = false;
  String? _syncMessage;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _parkOrBlock.dispose();
    _patrolId.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  double? get _parsedLatitude => double.tryParse(_latitude.text.trim());
  double? get _parsedLongitude => double.tryParse(_longitude.text.trim());

  bool get _hasValidLocation {
    final latitude = _parsedLatitude;
    final longitude = _parsedLongitude;
    return latitude != null &&
        longitude != null &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  Future<void> _captureGps() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final location = await _locationService.captureCurrentLocation();
      _latitude.text = location.latitude.toStringAsFixed(6);
      _longitude.text = location.longitude.toStringAsFixed(6);
      setState(() {
        _accuracy = location.accuracyMeters;
        _manualLocation = false;
      });
    } on IncidentLocationException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = 'Could not get GPS location: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addEvidence(EvidenceSource source) async {
    if (_evidence.length >= IncidentEvidencePicker.maxEvidenceCount) {
      setState(() => _error = 'You can attach up to 3 photos to this report.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final item = await _evidencePicker.pick(source);
      if (item != null && mounted) {
        setState(() => _evidence = [..._evidence, item]);
      }
    } on IncidentEvidenceException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = 'Could not attach that photo: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _next() {
    setState(() => _error = null);
    if (_step == 0 && _type == null) {
      setState(() => _error = 'Choose an incident type to continue.');
      return;
    }
    if (_step == 1) {
      if (_title.text.trim().isEmpty) {
        setState(() => _error = 'Enter a short title for the incident.');
        return;
      }
      if (_description.text.trim().length < 10) {
        setState(
          () => _error = 'Add at least 10 characters of incident detail.',
        );
        return;
      }
    }
    if (_step == 2 && !_hasValidLocation) {
      setState(
        () => _error = 'Capture GPS or enter valid latitude and longitude.',
      );
      return;
    }
    if (_step == 4 && !_confirmDetails) {
      setState(
        () => _error = 'Confirm that the incident details are accurate.',
      );
      return;
    }
    if (_step < _stepTitles.length - 1) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    final report = IncidentReport(
      id: _uuid.v4(),
      rangerId: widget.ranger.uid,
      rangerEmail: widget.ranger.email ?? '',
      type: _type!,
      title: _title.text.trim(),
      description: _description.text.trim(),
      severity: _severity,
      activeThreat: _activeThreat,
      latitude: _parsedLatitude,
      longitude: _parsedLongitude,
      locationAccuracyMeters: _accuracy,
      parkOrBlock: _parkOrBlock.text.trim(),
      createdAt: DateTime.now().toUtc(),
      status: IncidentStatus.pendingSync,
      evidence: List.unmodifiable(_evidence),
      patrolId: _patrolId.text.trim().isEmpty ? null : _patrolId.text.trim(),
      manualLocation: _manualLocation,
    );

    setState(() {
      _busy = true;
      _error = null;
      _syncMessage = null;
    });
    try {
      // Save to device before attempting any network request.
      await widget.saveLocally(report);
      if (!mounted) return;
      setState(() {
        _submittedReport = report;
        _step = _stepTitles.length;
      });
      try {
        await widget.syncNow(report);
        if (mounted) {
          setState(() {
            _synced = true;
            _syncMessage =
                'Incident ${report.id.substring(0, 8)} synced successfully.';
          });
        }
      } catch (error) {
        if (mounted) {
          setState(() {
            _synced = false;
            _syncMessage =
                'Saved on this device. Sync will retry when you have a connection.';
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not save this report: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retrySync() async {
    final report = _submittedReport;
    if (report == null) return;
    setState(() {
      _busy = true;
      _syncMessage = 'Trying to sync incident...';
    });
    try {
      await widget.syncNow(report);
      if (mounted) {
        setState(() {
          _synced = true;
          _syncMessage =
              'Incident ${report.id.substring(0, 8)} synced successfully.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _synced = false;
          _syncMessage =
              'Still offline. Your report remains safely on this device.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final complete = _submittedReport != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F8F3),
        title: Text(complete ? 'Incident saved' : 'Report an incident'),
        leading: IconButton(
          tooltip: complete ? 'Return to app' : 'Cancel report',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: complete
                  ? _buildSavedState(context)
                  : _buildWizard(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWizard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Step ${_step + 1} of ${_stepTitles.length}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (_step + 1) / _stepTitles.length,
            minHeight: 7,
            color: const Color(0xFF17613F),
            backgroundColor: const Color(0xFFD6E3D9),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _stepTitles[_step],
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          'Ranger: ${widget.ranger.email ?? widget.ranger.uid}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 14),
        if (_error != null) _message(_error!, isError: true),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 12),
            child: switch (_step) {
              0 => _buildTypeStep(),
              1 => _buildDetailsStep(),
              2 => _buildLocationStep(),
              3 => _buildEvidenceStep(),
              _ => _buildReviewStep(),
            },
          ),
        ),
        Row(
          children: [
            if (_step > 0)
              OutlinedButton(
                onPressed: _busy ? null : () => setState(() => _step--),
                child: const Text('Back'),
              )
            else
              const SizedBox.shrink(),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF17613F),
              ),
              onPressed: _busy ? null : _next,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_step == 4 ? 'Save incident' : 'Next'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeStep() => RadioGroup<IncidentType>(
    groupValue: _type,
    onChanged: (value) => setState(() => _type = value),
    child: Column(
      children: IncidentType.values.map((type) {
        final selected = _type == type;
        return Card(
          color: selected ? const Color(0xFFE6F2E9) : Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: selected
                  ? const Color(0xFF17613F)
                  : const Color(0xFFD9E2DB),
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: RadioListTile<IncidentType>(
            value: type,
            title: Text(
              type.label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(type.hint),
            activeColor: const Color(0xFF17613F),
          ),
        );
      }).toList(),
    ),
  );

  Widget _buildDetailsStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _field(_title, 'Short title', hint: 'Wire snare on game trail', max: 80),
      const SizedBox(height: 14),
      _field(
        _description,
        'Description',
        hint: 'Describe what you found...',
        maxLines: 4,
        max: 1000,
      ),
      const SizedBox(height: 16),
      const Text('Severity'),
      const SizedBox(height: 8),
      SegmentedButton<IncidentSeverity>(
        segments: IncidentSeverity.values
            .map(
              (severity) =>
                  ButtonSegment(value: severity, label: Text(severity.label)),
            )
            .toList(),
        selected: {_severity},
        onSelectionChanged: (value) => setState(() => _severity = value.first),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _activeThreat,
        onChanged: (value) => setState(() => _activeThreat = value ?? false),
        title: const Text('Active threat — prioritize response'),
        controlAffinity: ListTileControlAffinity.leading,
      ),
      _field(
        _patrolId,
        'Current Patrol ID (optional)',
        hint: 'Link this report to your active patrol',
      ),
    ],
  );

  Widget _buildLocationStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _field(_parkOrBlock, 'Park / block', hint: 'Yala East · Block B'),
      const SizedBox(height: 12),
      FilledButton.tonalIcon(
        onPressed: _busy ? null : _captureGps,
        icon: const Icon(Icons.my_location),
        label: const Text('Capture current GPS location'),
      ),
      if (_accuracy != null) ...[
        const SizedBox(height: 8),
        Text('GPS captured · ±${_accuracy!.toStringAsFixed(0)} m accuracy'),
      ],
      const SizedBox(height: 12),
      const Text('If GPS is unavailable, enter coordinates manually.'),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _field(
              _latitude,
              'Latitude',
              hint: '6.37214',
              keyboard: TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              onChanged: (_) => setState(() => _manualLocation = true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _field(
              _longitude,
              'Longitude',
              hint: '81.51840',
              keyboard: TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              onChanged: (_) => setState(() => _manualLocation = true),
            ),
          ),
        ],
      ),
      if (_hasValidLocation)
        _message(
          '${_parsedLatitude!.toStringAsFixed(5)}, ${_parsedLongitude!.toStringAsFixed(5)}${_manualLocation ? ' · entered manually' : ' · GPS'}',
        ),
    ],
  );

  Widget _buildEvidenceStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFE6F2E9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF92B69D)),
        ),
        child: const Column(
          children: [
            Icon(Icons.camera_alt, size: 34, color: Color(0xFF17613F)),
            SizedBox(height: 8),
            Text('Attach up to 3 evidence photos'),
            Text('Photos are compressed before saving on this device.'),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _addEvidence(EvidenceSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Camera'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _addEvidence(EvidenceSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Gallery'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (_evidence.isEmpty)
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('No photos attached'),
          subtitle: Text('Evidence photos are optional.'),
        ),
      ..._evidence.map(
        (photo) => Card(
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                base64Decode(photo.base64Data),
                width: 52,
                height: 52,
                fit: BoxFit.cover,
              ),
            ),
            title: Text(
              photo.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: const Text('Compressed and ready'),
            trailing: IconButton(
              tooltip: 'Remove photo',
              onPressed: () => setState(() => _evidence.remove(photo)),
              icon: const Icon(Icons.delete_outline),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _buildReviewStep() {
    final type = _type;
    return Column(
      children: [
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summary('Type', type?.label ?? 'Not selected'),
                _summary('Title', _title.text.trim()),
                _summary('Severity', _severity.label.toUpperCase()),
                _summary('Active threat', _activeThreat ? 'Yes' : 'No'),
                _summary(
                  'Park / block',
                  _parkOrBlock.text.trim().isEmpty
                      ? 'Not provided'
                      : _parkOrBlock.text.trim(),
                ),
                _summary(
                  'GPS',
                  '${_parsedLatitude?.toStringAsFixed(5)}, ${_parsedLongitude?.toStringAsFixed(5)}',
                ),
                _summary(
                  'Patrol',
                  _patrolId.text.trim().isEmpty
                      ? 'Not linked'
                      : _patrolId.text.trim(),
                ),
                _summary('Evidence', '${_evidence.length} photo(s)'),
                _summary('Ranger', widget.ranger.email ?? widget.ranger.uid),
                const Divider(),
                Text(_description.text.trim()),
              ],
            ),
          ),
        ),
        CheckboxListTile(
          value: _confirmDetails,
          onChanged: (value) =>
              setState(() => _confirmDetails = value ?? false),
          title: const Text('I confirm these incident details are accurate.'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        _message(
          'No network? The report will be saved on this device as Pending Sync.',
        ),
      ],
    );
  }

  Widget _buildSavedState(BuildContext context) {
    final report = _submittedReport!;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          _synced ? Icons.check_circle : Icons.cloud_off,
          size: 64,
          color: _synced ? const Color(0xFF21834D) : const Color(0xFFE18436),
        ),
        const SizedBox(height: 16),
        Text(
          _synced ? 'Sync complete' : 'Saved on this device',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(_syncMessage ?? 'Pending sync', textAlign: TextAlign.center),
        const SizedBox(height: 22),
        Card(
          child: ListTile(
            title: Text('${report.id.substring(0, 8)} created'),
            subtitle: Text('${report.type.label} · ${report.severity.label}'),
            trailing: Chip(
              label: Text(_synced ? 'Reported' : 'Pending Sync'),
              backgroundColor: _synced
                  ? const Color(0xFFDFF1E3)
                  : const Color(0xFFFFE8CC),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (!_synced) ...[
          OutlinedButton.icon(
            onPressed: _busy ? null : _retrySync,
            icon: const Icon(Icons.sync),
            label: const Text('Retry sync now'),
          ),
        ],
        const SizedBox(height: 8),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF17613F),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Return to patrol'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    int maxLines = 1,
    int? max,
    TextInputType? keyboard,
    ValueChanged<String>? onChanged,
  }) => TextField(
    controller: controller,
    maxLines: maxLines,
    maxLength: max,
    keyboardType: keyboard,
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
      filled: true,
      fillColor: Colors.white,
      counterText: max == null ? null : '',
    ),
  );

  Widget _summary(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Widget _message(String message, {bool isError = false}) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isError ? const Color(0xFFFFE9E5) : const Color(0xFFE7F1E8),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      message,
      style: TextStyle(
        color: isError ? const Color(0xFF9E2E25) : const Color(0xFF365C41),
      ),
    ),
  );
}
