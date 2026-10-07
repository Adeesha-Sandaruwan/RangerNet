import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/incident_cloud_repository.dart';
import '../data/incident_local_store.dart';
import '../domain/incident_report.dart';
import 'incident_detail_page.dart';
import 'incident_report_page.dart';

class IncidentHomePage extends StatefulWidget {
  const IncidentHomePage({required this.ranger, super.key});
  final User ranger;

  @override
  State<IncidentHomePage> createState() => _IncidentHomePageState();
}

class _IncidentHomePageState extends State<IncidentHomePage> {
  final _store = IncidentLocalStore();
  final _cloud = IncidentCloudRepository();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  List<IncidentReport> _queue = const [];
  List<IncidentReport> _reportedReports = const [];
  bool _loading = true;
  bool _syncing = false;
  bool _draftAvailable = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _refreshQueue();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        unawaited(_syncPending());
      }
    });
    unawaited(_syncPending());
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshQueue() async {
    try {
      final queue = await _store.loadQueue(widget.ranger.uid);
      final draft = await _store.loadDraft(widget.ranger.uid);
      if (mounted) {
        setState(() {
          _queue = queue;
          _draftAvailable = draft != null;
        });
      }
      try {
        final reports = await _cloud.loadReportsForRanger(widget.ranger.uid);
        if (mounted) setState(() => _reportedReports = reports);
      } catch (error) {
        if (mounted) {
          setState(() => _message = 'Saved locally; cloud list unavailable: $error');
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Could not load saved reports: $error');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveLocally(IncidentReport report) async {
    await _store.enqueue(report);
    await _refreshQueue();
  }

  Future<void> _discardDraft() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard incident draft?'),
        content: const Text(
          'This removes the unfinished report and its photos from this device. '
          'It cannot be recovered afterward.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep draft'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard draft'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _store.clearDraft(widget.ranger.uid);
      await _refreshQueue();
      if (mounted) setState(() => _message = 'Unfinished incident draft discarded.');
    } catch (error) {
      if (mounted) setState(() => _message = 'Could not discard draft: $error');
    }
  }

  Future<void> _ensureNetworkAvailable() async {
    final results = await Connectivity().checkConnectivity();
    if (results.isEmpty ||
        results.every((result) => result == ConnectivityResult.none)) {
      throw StateError(
        'No network is available. The report remains Pending Sync.',
      );
    }
  }

  Future<void> _syncOne(IncidentReport report) async {
    await _ensureNetworkAvailable();
    await _cloud.publish(report).timeout(const Duration(seconds: 25));
    await _store.remove(widget.ranger.uid, report.id);
    await _refreshQueue();
  }

  Future<void> _syncPending() async {
    if (_syncing || !mounted) return;
    setState(() {
      _syncing = true;
      _message = 'Checking pending reports...';
    });
    var synced = 0;
    var failed = 0;
    try {
      await _ensureNetworkAvailable();
      final pending = await _store.loadQueue(widget.ranger.uid);
      for (final report in pending) {
        try {
          await _cloud.publish(report).timeout(const Duration(seconds: 25));
          await _store.remove(widget.ranger.uid, report.id);
          synced++;
        } catch (_) {
          failed++;
        }
      }
      if (mounted) {
        setState(() {
          _message = pending.isEmpty
              ? 'No pending incident reports.'
              : '$synced synced · $failed still pending.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _message = 'Pending Sync · $error');
    } finally {
      await _refreshQueue();
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _openReport() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => IncidentReportPage(
          ranger: widget.ranger,
          saveLocally: _saveLocally,
          syncNow: _syncOne,
        ),
      ),
    );
    await _refreshQueue();
  }

  Future<void> _signOut() => FirebaseAuth.instance.signOut();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F8F3),
        title: const Text('RangerNet'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: RefreshIndicator(
            onRefresh: _refreshQueue,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Field reports',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Signed in as ${widget.ranger.email ?? widget.ranger.uid}',
                ),
                const SizedBox(height: 18),
                Card(
                  color: const Color(0xFFE6F2E9),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.crisis_alert,
                          color: Color(0xFF17613F),
                          size: 32,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Wildlife / poaching incident',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Record details, GPS location and optional evidence. Your patrol can remain active while you report.',
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF17613F),
                          ),
                          onPressed: _openReport,
                          icon: const Icon(Icons.add),
                          label: Text(
                            _draftAvailable
                                ? 'Resume incident draft'
                                : 'Report incident',
                          ),
                        ),
                        if (_draftAvailable)
                          TextButton.icon(
                            onPressed: _discardDraft,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Discard saved draft'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pending sync (${_queue.length})',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _syncing ? null : _syncPending,
                      icon: _syncing
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: const Text('Sync now'),
                    ),
                  ],
                ),
                if (_message != null) ...[
                  const SizedBox(height: 4),
                  Text(_message!, style: Theme.of(context).textTheme.bodySmall),
                ],
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_queue.isEmpty)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.cloud_done_outlined),
                      title: Text('No pending reports'),
                      subtitle: Text(
                        'New reports will appear here if they need to sync.',
                      ),
                    ),
                  )
                else
                  ..._queue.map(_pendingCard),
                const SizedBox(height: 20),
                Text(
                  'My submitted reports (${_reportedReports.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_reportedReports.isEmpty)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.assignment_outlined),
                      title: Text('No submitted reports yet'),
                      subtitle: Text(
                        'Reports appear here after they reach Firestore.',
                      ),
                    ),
                  )
                else
                  ..._reportedReports.map(_reportedCard),
                const SizedBox(height: 16),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Patrol controls are not connected yet'),
                    subtitle: Text(
                      'A patrol ID can be added to an incident now. Pause, resume and early completion belong to the separate patrol workflow.',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pendingCard(IncidentReport report) => Card(
    child: ListTile(
      onTap: () => _openDetails(report),
      leading: const Icon(
        Icons.cloud_upload_outlined,
        color: Color(0xFFE18436),
      ),
      title: Text(report.title),
      subtitle: Text(
        '${report.type.label} · ${report.severity.label} · ${report.createdAt.toLocal().toString().substring(0, 16)}',
      ),
      trailing: IconButton(
        tooltip: 'Retry this report',
        onPressed: _syncing
            ? null
            : () => _syncOne(report).catchError((Object error) {
                if (mounted) setState(() => _message = 'Still pending: $error');
              }),
        icon: const Icon(Icons.sync),
      ),
    ),
  );

  Widget _reportedCard(IncidentReport report) => Card(
    child: ListTile(
      onTap: () => _openDetails(report),
      leading: const Icon(Icons.cloud_done, color: Color(0xFF21834D)),
      title: Text(report.title),
      subtitle: Text(
        '${report.type.label} · ${report.severity.label} · '
        '${report.createdAt.toLocal().toString().substring(0, 16)}',
      ),
      trailing: const Chip(label: Text('Reported')),
    ),
  );

  void _openDetails(IncidentReport report) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => IncidentDetailPage(report: report),
      ),
    );
  }
}

class RangerNetLoginPage extends StatefulWidget {
  const RangerNetLoginPage({super.key});

  @override
  State<RangerNetLoginPage> createState() => _RangerNetLoginPageState();
}

class _RangerNetLoginPageState extends State<RangerNetLoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _createAccount = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.length < 6) {
      setState(
        () => _error =
            'Enter an email and a password with at least 6 characters.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      if (_createAccount) {
        await auth.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      } else {
        await auth.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } on FirebaseAuthException catch (error) {
      setState(() => _error = error.message ?? error.code);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F8F3),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.forest, size: 58, color: Color(0xFF17613F)),
              const SizedBox(height: 12),
              Text(
                'RangerNet',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _busy ? null : _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF17613F),
                ),
                onPressed: _busy ? null : _submit,
                child: Text(
                  _busy
                      ? 'Please wait…'
                      : _createAccount
                      ? 'Create ranger account'
                      : 'Sign in',
                ),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() => _createAccount = !_createAccount),
                child: Text(
                  _createAccount
                      ? 'Already registered? Sign in'
                      : 'New ranger? Create account',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
