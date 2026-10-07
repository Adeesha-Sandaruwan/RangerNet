# UC02: Ranger wildlife / poaching incident reporting

## Scope

This feature covers the ranger's UC02 path only: create an incident report,
preserve it locally when needed, synchronize it to Firestore, and let the
reporting ranger review their own reports. It does not implement patrol
controls or manager review, response-team assignment, or incident closure.

The signed-in app has two destinations for this work:

- **Home**: a simple RangerNet welcome page with a shortcut to incident reports.
- **Incidents**: create/resume a draft, review pending synchronization, and
  view submitted reports.

Other use cases can add their own destinations when their owners implement
them. The UC02 feature does not add placeholder implementations for those use
cases.

## Ranger flow

1. Open **Incidents** and choose **Report incident** (or resume the saved draft).
2. Select a type and enter a title, description, severity, threat flag, and
   optional patrol ID.
3. Capture GPS or enter a valid latitude and longitude manually. The app records
   which method was used and GPS accuracy when available.
4. Optionally attach up to three compressed photos. Preview or remove a photo
   before submission.
5. Review the information and confirm it is accurate.
6. The app saves the report to the device first. It attempts Firestore upload;
   if that fails or the device is offline, the report stays in the local outbox
   and can be retried.
7. Open a row in **My submitted reports** to review its details and evidence.

An unfinished draft is saved on the device. From the Incidents screen, the
ranger can resume it or explicitly discard it after a confirmation prompt.

## Firestore structure

```text
incidents/{incidentId}
  incidentId, rangerId, rangerEmail
  type, typeLabel, title, description, severity, activeThreat
  latitude, longitude, locationAccuracyMeters, locationSource
  parkOrBlock, patrolId, createdAtClient, evidenceCount
  status, submittedAt, updatedAt

incidents/{incidentId}/evidence/{evidenceId}
  fileName, contentType, base64Data, createdAt
```

The incident ID and evidence IDs remain stable during retry so repeated sync
attempts update the same documents. The parent is set to `Uploading`, evidence
documents are written, and the parent becomes `Reported` after all writes
succeed. Locally queued reports use `Pending Sync`; a failed retry is retained
with a `Sync needs attention` state.

Images are JPEG-compressed to a maximum of 100 KiB each and limited to three
per report. The app stores them in the Firestore evidence subcollection; it
does not use Firebase Storage.

## Access control

The Firestore rules are in [INCIDENT_FIRESTORE_RULES.md](INCIDENT_FIRESTORE_RULES.md).
They allow a signed-in ranger to access only incident documents whose
`rangerId` matches their Firebase Authentication UID. The project owner has
published those rules for the current Firebase project. Manager access is not
granted by this rule set; a manager-side feature needs its own verified role
and assignment rules.

## Local files

- `lib/features/incidents/domain/incident_report.dart` — incident and evidence
  models.
- `lib/features/incidents/data/incident_local_store.dart` — local draft and
  pending outbox.
- `lib/features/incidents/data/incident_cloud_repository.dart` — Firestore
  submission and ranger-owned report retrieval.
- `lib/features/incidents/presentation/incident_report_page.dart` — guided
  create/review/submit flow.
- `lib/features/incidents/presentation/incident_home_page.dart` — pending and
  submitted lists plus retry controls.
- `lib/features/incidents/presentation/incident_detail_page.dart` — read-only
  report and evidence review.
- `lib/features/home/presentation/rangernet_shell.dart` — Home/Incidents
  navigation for the currently implemented ranger feature.

## Manual acceptance walkthrough

1. Sign in and confirm Home appears with a shortcut to Incidents.
2. Use the bottom bar to open Incidents and create a report without photos.
3. Check the report appears in Firestore and in **My submitted reports**.
4. Open it and confirm its details and location are shown.
5. Create a report with one or more photos and verify the photos can be opened
   from the detail screen.
6. Start a draft, leave the wizard, return to Incidents, and resume the draft.
7. Discard a draft and confirm it no longer appears as available to resume.
8. Submit while offline, reconnect, choose **Sync now**, and confirm the report
   moves from Pending Sync to the submitted list.

Do not treat the generated debug build or a successful sync as proof that all
of these manual scenarios have been exercised on every device.
