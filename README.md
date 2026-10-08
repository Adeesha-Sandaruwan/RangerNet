# RangerNet

RangerNet is a Flutter app for wildlife conservation field work. This repository
currently focuses on **UC02: Report and Manage Wildlife / Poaching Incidents**.
It uses Firebase Authentication and Cloud Firestore.

The app supports two account roles:

- **Ranger:** report incidents, save reports offline, and respond to incidents
  assigned by a manager.
- **Park manager:** open the manager dashboard, review reports and evidence,
  assign responders, update incident status, and close resolved incidents.

Patrol recording, wildlife sensor alerts, and conservation analytics are outside
the current UC02 implementation.

## What you need

- Windows 10/11 (the commands below use PowerShell).
- Flutter installed. The project uses Dart 3.12.2 or newer.
- Android Studio with the Android SDK, or an Android phone with USB debugging
  enabled.
- Git.
- A Firebase account with access to the RangerNet project for Firebase setup.

VS Code is optional; Android Studio can also open the project.

## Get the project running

Open PowerShell and run:

```powershell
git clone https://github.com/Adeesha-Sandaruwan/RangerNet.git
cd RangerNet
flutter doctor
flutter pub get
flutter devices
flutter run
```

If there is more than one device, copy its ID from `flutter devices` and run:

```powershell
flutter run -d DEVICE_ID
```

For example, `flutter run -d R5CW10WYGRK` runs on a connected phone with that
device ID. On the phone, accept the USB debugging prompt. An Android emulator
also works.

## Firebase setup

The app is configured for the Firebase project **`rangernet`**. Android and Web
Firebase options are in `lib/firebase_options.dart`. Email/password sign-in and
Cloud Firestore must be enabled in the Firebase Console.

The Firestore rules are in `firestore.rules`. They are already deployed to the
`rangernet` project. If you change the rules, sign in to Firebase CLI using an
account with project access, then deploy only the rules:

```powershell
npm install -g firebase-tools
firebase login
firebase deploy --only firestore:rules --project rangernet
```

Do not replace the rules with open access such as `allow read, write: if true`.
See [the UC02 rules and account setup guide](docs/INCIDENT_FIRESTORE_RULES.md)
before changing roles or security rules.

### Ranger account

On the sign-in screen, choose **New ranger? Create account**. New accounts are
created as rangers automatically. The app creates a matching profile in
Firestore the first time the account signs in.

### Manager account

Managers use the same sign-in screen. First create or sign in to the manager's
Firebase Authentication account. In Firebase Console, open **Firestore
Database → Data → `users`** and set the document whose ID is the manager's
Firebase Auth UID to:

| Field | Value |
|---|---|
| `uid` | The same Firebase Auth UID as the document ID |
| `email` | Manager's sign-in email |
| `displayName` | Manager's name |
| `role` | `manager` |
| `active` | `true` |

If the app already created that profile as a ranger, update its `role` to
`manager`. Sign out and sign in again. The manager opens a dashboard first, then
selects **Go to incident management**.

## How incident reporting works

1. A ranger opens **Incidents** and starts a report.
2. The ranger enters the incident type, description, severity, and location;
   photos are optional.
3. The report is saved on the device. When internet is available, RangerNet
   uploads it to Firestore.
4. A manager reviews the report and its evidence, assigns one ranger or a team,
   and records follow-up actions.
5. Assigned rangers open **Assigned** and submit progress, notes, and optional
   evidence.
6. After a ranger submits a resolution, the manager can confirm it and close
   the incident. Closed incidents appear in the manager's **Closed** section.

More detail about the implemented workflow is in
[the UC02 guide](docs/UC02_RANGER_INCIDENT_REPORTING.md).

## Offline data and photos

- Unsent incident drafts and reports are kept on the device and can sync when
  connectivity returns.
- The offline queue holds up to eight reports at a time.
- Photos are compressed and stored as small Base64 values in Firestore. Up to
  three photos are supported per report or response update.
- Firebase Storage is not used by this project.
- Assignment and report notifications appear inside the app while it is open;
  operating-system push notifications are not configured.

## Run checks

Run the unit and widget tests:

```powershell
flutter test
```

Check code style and common errors:

```powershell
flutter analyze
```

Create a coverage report:

```powershell
flutter test --coverage
```

The report is written to `coverage/lcov.info`.

Build a debug Android APK:

```powershell
flutter build apk --debug
```

The APK is saved at `build/app/outputs/flutter-apk/app-debug.apk`.

## Project folders

```text
lib/
  main.dart                         App start and sign-in routing
  firebase_options.dart             Firebase project configuration
  features/
    incidents/domain/                Incident models and workflow rules
    incidents/data/                  Firebase, location, and offline storage
    incidents/presentation/          Ranger, responder, and manager screens
    home/presentation/                Ranger bottom navigation
test/                                Unit and widget tests
docs/                                UC02 workflow and Firebase rules guides
firestore.rules                      Rules deployed to Cloud Firestore
```

## Common fixes

- **No device found:** start an emulator or connect an Android phone, enable USB
  debugging, accept the phone prompt, then run `flutter devices` again.
- **Packages or imports are missing:** run `flutter pub get` from the project
  folder.
- **Firebase permission denied:** make sure the app is using project `rangernet`,
  the signed-in user has a valid `users/{uid}` profile, and the current rules
  have been deployed.
- **Manager still sees ranger screens:** verify the manager's `users/{uid}`
  document has `role: manager` and `active: true`, then sign out and back in.
- **FlutterFire command is not found:** run it through Dart instead:
  `dart pub global run flutterfire_cli:flutterfire configure --project=rangernet --platforms=android,web`.
