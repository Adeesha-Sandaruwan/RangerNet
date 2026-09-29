import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RangerNet Setup Check',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.green)),
      home: const SetupCheckPage(),
    );
  }
}

class SetupCheckPage extends StatefulWidget {
  const SetupCheckPage({super.key});

  @override
  State<SetupCheckPage> createState() => _SetupCheckPageState();
}

class _SetupCheckPageState extends State<SetupCheckPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _status = 'Enter a test email and password.';
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _checkFirebase({required bool createAccount}) async {
    setState(() {
      _busy = true;
      _status = 'Connecting to Firebase...';
    });

    try {
      final credential = createAccount
          ? await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: _email.text.trim(),
              password: _password.text,
            )
          : await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: _email.text.trim(),
              password: _password.text,
            );

      final user = credential.user!;
      final document = FirebaseFirestore.instance
          .collection('setup_checks')
          .doc(user.uid);

      await document.set({
        'email': user.email,
        'checkedAt': FieldValue.serverTimestamp(),
        'message': 'RangerNet setup connection check',
      });

      final savedDocument = await document.get();

      setState(() {
        _status = savedDocument.exists
            ? 'Success! Auth is signed in and the Firestore record was saved.'
            : 'Signed in, but the Firestore record was not found.';
      });
    } on FirebaseAuthException catch (error) {
  debugPrint('Auth error code: ${error.code}');
  debugPrint('Auth error message: ${error.message}');
  setState(() {
    _status = 'Authentication error (${error.code}): '
        '${error.message ?? error.toString()}';
  });
    } on FirebaseException catch (error) {
      setState(() => _status = 'Firebase error: ${error.message}');
    } catch (error) {
      setState(() => _status = 'Error: $error');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RangerNet Setup Check')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Test email'),
            ),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Test password'),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                ElevatedButton(
                  onPressed: _busy
                      ? null
                      : () => _checkFirebase(createAccount: true),
                  child: const Text('Create test account'),
                ),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _checkFirebase(createAccount: false),
                  child: const Text('Sign in to test account'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(_status, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}