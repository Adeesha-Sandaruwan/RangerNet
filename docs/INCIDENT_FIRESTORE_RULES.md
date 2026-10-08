# UC02 Firestore roles and security rules

Replace the existing rules in **Firebase Console → Firestore Database → Rules**
with the complete rules below, then select **Publish**. The old owner-only rule
set does not permit manager review or responder access.

```text
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function signedIn() {
      return request.auth != null;
    }

    function userPath(uid) {
      return /databases/$(database)/documents/users/$(uid);
    }

    function hasRole(uid, expectedRole) {
      return exists(userPath(uid))
        && get(userPath(uid)).data.role == expectedRole
        && get(userPath(uid)).data.active != false;
    }

    function isManager() {
      return signedIn() && hasRole(request.auth.uid, 'manager');
    }

    function isRanger() {
      return signedIn() && hasRole(request.auth.uid, 'ranger');
    }

    function incidentPath(incidentId) {
      return /databases/$(database)/documents/incidents/$(incidentId);
    }

    function isReporter(incidentId) {
      return signedIn()
        && exists(incidentPath(incidentId))
        && get(incidentPath(incidentId)).data.rangerId == request.auth.uid;
    }

    function isAssignedResponder(incidentId) {
      return isRanger()
        && exists(incidentPath(incidentId))
        && request.auth.uid in get(incidentPath(incidentId)).data.assignedRangerIds;
    }

    function canReadIncident(incidentId) {
      return isManager() || isReporter(incidentId) || isAssignedResponder(incidentId);
    }

    match /users/{userId} {
      // A user may read their own role; managers can list ranger profiles to assign.
      allow get: if signedIn() && (request.auth.uid == userId || isManager());
      allow list: if isManager();

      // New accounts can only provision themselves as ordinary rangers.
      allow create: if signedIn()
        && request.auth.uid == userId
        && request.resource.data.uid == userId
        && request.resource.data.role == 'ranger'
        && request.resource.data.active == true;

      // Users cannot promote themselves, deactivate themselves, or edit history.
      allow update: if signedIn()
        && request.auth.uid == userId
        && resource.data.role == 'ranger'
        && request.resource.data.role == resource.data.role
        && request.resource.data.active == resource.data.active
        && request.resource.data.diff(resource.data).affectedKeys()
             .hasOnly(['displayName']);
      allow delete: if false;
    }

    match /incidents/{incidentId} {
      allow create: if isRanger()
        && request.resource.data.rangerId == request.auth.uid
        && request.resource.data.status == 'Uploading';

      allow get, list: if canReadIncident(incidentId);

      // Reporter sync is limited to completing its own Uploading record.
      allow update: if (
          isReporter(incidentId)
          && resource.data.status == 'Uploading'
          && request.resource.data.diff(resource.data).affectedKeys()
               .hasOnly(['status', 'submittedAt', 'updatedAt'])
        ) || (
          isManager()
          && request.resource.data.diff(resource.data).affectedKeys()
               .hasOnly([
                 'severity', 'activeThreat', 'workflowStatus',
                 'assignmentType', 'assignedRangerIds', 'assignedRangerNames',
                 'assignedAt', 'assignedBy', 'managerNote', 'followUpReason',
                 'escalationReason', 'closedAt', 'closedBy', 'updatedAt'
               ])
        ) || (
          isAssignedResponder(incidentId)
          && request.resource.data.diff(resource.data).affectedKeys()
               .hasOnly(['workflowStatus', 'updatedAt'])
          && request.resource.data.workflowStatus
               in ['responseInProgress', 'resolved']
        );
      allow delete: if false;

      match /evidence/{evidenceId} {
        allow get, list: if canReadIncident(incidentId);
        allow create, update: if isReporter(incidentId)
          && get(incidentPath(incidentId)).data.status == 'Uploading';
        allow delete: if false;
      }

      match /responses/{responseId} {
        allow get, list: if canReadIncident(incidentId);
        allow create: if isAssignedResponder(incidentId)
          && request.resource.data.actorId == request.auth.uid
          && request.resource.data.status
               in ['responseInProgress', 'resolved'];
        allow update, delete: if false;

        match /evidence/{evidenceId} {
          allow get, list: if canReadIncident(incidentId);
          allow create: if isAssignedResponder(incidentId)
            && getAfter(/databases/$(database)/documents/incidents/$(incidentId)/responses/$(responseId))
                 .data.actorId == request.auth.uid;
          allow update, delete: if false;
        }
      }

      match /timeline/{eventId} {
        allow get, list: if canReadIncident(incidentId);
        allow create: if (isManager() || isAssignedResponder(incidentId))
          && request.resource.data.actorId == request.auth.uid;
        allow update, delete: if false;
      }
    }
  }
}
```

## Provision the manager account

Manager role cannot be selected or created by the mobile app. In the Firebase
Console, open **Firestore Database → Data**, create a `users` collection if it
does not exist, and add a document whose document ID is the manager's Firebase
Authentication UID. Add these fields:

| Field | Type | Value |
|---|---|---|
| `uid` | string | Same as the document ID |
| `email` | string | Manager's sign-in email |
| `displayName` | string | Manager's display name |
| `role` | string | `manager` |
| `active` | boolean | `true` |

Create a normal Authentication account for every ranger/responder. The app
creates a `users/{uid}` profile with role `ranger` at first sign-in. A ranger
profile must exist before a manager can assign that account.

## Access model

- Rangers can create their own incident and read it.
- Managers can review all incidents, list ranger profiles, and manage incident
  severity, assignment, follow-up, escalation, and closure fields.
- Assigned rangers can read the incidents assigned to them, add immutable
  response records and response evidence, and move the case to `responseInProgress`
  or `resolved`.
- Incident timeline events and response records are append-only.
- Clients cannot create manager accounts or change roles. Do not publish open
  rules such as `allow read, write: if true`.
