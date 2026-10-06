# RangerNet incident Firestore rules

The Flutter app creates a parent document at `incidents/{incidentId}` and
compressed evidence documents at `incidents/{incidentId}/evidence/{evidenceId}`.
Before cloud submission can succeed, replace the temporary `setup_checks`
rules in Firebase Console → Firestore Database → Rules with the following
owner-only rules and publish them:

```text
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /incidents/{incidentId} {
      allow create: if request.auth != null
                    && request.resource.data.rangerId == request.auth.uid;
      allow get, list, update, delete: if request.auth != null
                    && resource.data.rangerId == request.auth.uid;

      match /evidence/{evidenceId} {
        allow create, get, list, update, delete: if request.auth != null
          && get(/databases/$(database)/documents/incidents/$(incidentId))
                 .data.rangerId == request.auth.uid;
      }
    }
  }
}
```

These initial rules let a ranger access only reports they own. Park-manager
access requires a verified role/assignment model and must be added before using
manager dashboards. Do not use open (`allow read, write: if true`) rules.

## Data shape

- Incident metadata: `incidents/{incidentId}`
- Evidence: `incidents/{incidentId}/evidence/{evidenceId}`
- Offline outbox: local SharedPreferences key scoped to the signed-in ranger
- Evidence is JPEG-compressed to 100 KB maximum per image and limited to three
  images per report; no Firebase Storage bucket is used.
- Patrol ID is optional until the UC01 assigned/active patrol flow supplies it.

Reports are written as `Uploading`, then evidence is written with stable IDs,
then the parent becomes `Reported`. If any cloud write fails, the complete
report remains in the device outbox as Pending Sync and can be retried safely.
