# UC02: Report and Manage Wildlife / Poaching Incidents

## Scope

This feature implements the UC02 incident lifecycle for three UC02 actors:

- **Reporting ranger:** creates the report, location, description, severity,
  and initial photo evidence; the draft and pending report are retained locally
  and can sync later.
- **Park Manager / Duty Supervisor:** reviews the report, changes severity,
  assigns one ranger or a response team, reassigns responders, escalates,
  records monitoring/follow-up, handles duplicate/invalid reports, and confirms
  closure after a responder submits a resolution.
- **Assigned responder:** sees assigned UC02 incidents, records response notes
  and supplementary photos, and submits progress or resolution for manager
  review.

This does not implement patrol recording, sensor alerts, or conservation
analytics. They are other use cases. The manager screen here is an incident
operations inbox, not a shared dashboard for those other features.

## Role routing

The application reads the trusted role from `users/{uid}` after Firebase Auth:

- `role: ranger` routes to the ranger shell with **Home**, **Incidents**, and
  **Assigned** tabs. Any ranger can act as a responder when assigned.
- `role: manager` routes to a manager landing dashboard. The manager selects
  **Go to incident management** to open the UC02 incident inbox.

New users can only create their own profile as a ranger. A project administrator
must promote the manager's profile to `manager` in the Firebase Console. The
client never allows users to grant themselves manager access. See
[INCIDENT_FIRESTORE_RULES.md](INCIDENT_FIRESTORE_RULES.md) for setup.

## Incident lifecycle

```text
Reported → Under review → Assigned → Response in progress → Resolved
                                                          ↓
                                                    Manager closes

Manager side paths: Critical escalation · Monitoring · Follow-up required
                    Duplicate · Rejected / invalid
```

The manager may select one ranger or a response team made of two or more ranger
accounts. Reassignment replaces the active assignee list and appends a history
event. Assigned responders see changes in the live **Assigned** list while the
app is open. The app shows an in-app message for newly reported/assigned
incidents; it does not send operating-system push notifications.

Responders submit response notes and optional photos as an append-only response
record. A resolved response does not close the case. The manager reviews it and
confirms closure. Follow-up/monitoring, critical escalation, duplicate/rejected
decisions, and closure require a reason and are retained in the incident
timeline.

## Firestore structure

```text
users/{uid}
  uid, email, displayName, role, active, createdAt

incidents/{incidentId}
  incidentId, rangerId, rangerEmail
  type, typeLabel, title, description, severity, activeThreat
  latitude, longitude, locationAccuracyMeters, locationSource
  parkOrBlock, patrolId, createdAtClient, evidenceCount
  status, workflowStatus, assignmentType, assignedRangerIds
  assignedRangerNames, assignedBy, assignedAt, managerNote
  followUpReason, escalationReason, closedAt, closedBy, updatedAt

incidents/{incidentId}/evidence/{evidenceId}
  fileName, contentType, base64Data, createdAt

incidents/{incidentId}/responses/{responseId}
  actorId, actorName, note, status, evidenceCount, createdAt

incidents/{incidentId}/responses/{responseId}/evidence/{evidenceId}
  fileName, contentType, base64Data, createdAt

incidents/{incidentId}/timeline/{eventId}
  actorId, actorName, type, message, createdAt
```

`status` records upload state (`Uploading` / `Reported`). `workflowStatus`
records UC02 management state. Keeping them separate prevents a sync retry from
rewinding a manager's status. Incident IDs and initial evidence IDs remain
stable for retry. Timeline entries and responder records are append-only.

Photos are JPEG-compressed to at most 100 KiB each, up to three per report or
response update. No Firebase Storage bucket is used.

## Code organization

- `lib/features/incidents/domain/` — incident, role, and timeline value models.
- `lib/features/incidents/data/` — Firebase repositories, local draft/outbox,
  location, and evidence adapters.
- `lib/features/incidents/presentation/` — separate ranger, manager, and
  responder screens.
- `lib/features/home/presentation/rangernet_shell.dart` — ranger navigation
  for UC02 only.

The UI calls repositories rather than writing directly to Firestore. Firestore
rules remain the authorization boundary; route visibility is not treated as
security.

## Manual setup and acceptance

1. Publish the complete role-aware rules in
   [INCIDENT_FIRESTORE_RULES.md](INCIDENT_FIRESTORE_RULES.md).
2. Create/sign in to the manager's Firebase Auth account once, then use the
   Firebase Console to set `users/{managerUid}.role` to `manager` and `active`
   to `true`. Sign out and back in to reload the role.
3. Each ranger signs in once so RangerNet creates a `role: ranger` profile.
4. As a ranger, submit an incident and confirm it reaches Firestore and appears
   in the ranger's submitted list.
5. As a manager, review it, change severity, and assign one ranger. Repeat with
   at least two ranger accounts to verify team assignment and reassignment.
6. Sign in as an assigned ranger and confirm the incident appears in **Assigned**.
   Add response notes and a supplementary photo, then submit progress.
7. Submit a resolved response. Confirm the incident stays open until the
   manager reviews it and selects **Confirm resolution and close**.
8. Exercise critical escalation, monitoring/follow-up, duplicate, and rejected
   outcomes; verify each reason appears in incident history.
9. Confirm a ranger cannot see another ranger's unassigned report and cannot
   promote their own role.

The analyzer/build passing does not substitute for testing these flows using
separate ranger and manager Firebase accounts.
