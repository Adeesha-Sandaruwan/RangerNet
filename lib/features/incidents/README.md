# Incident feature structure

This folder contains the UC02 incident-reporting feature.

## Folders

- `models/` contains the incident, ranger, and timeline data shapes.
- `repositories/` contains the data access contracts and their Firebase or
  on-device storage implementations.
- `services/` contains device helpers, such as GPS and photo picking, plus the
  incident workflow rules.
- `pages/` contains the screens for reporting, viewing, and managing incidents.
- `widgets/` contains small UI pieces shared by more than one incident page.
- `navigation/` contains role-based routing and sign-out navigation helpers.

## Where is the controller layer?

Each Flutter page is a `StatefulWidget` when it needs to remember screen state.
Its matching `State` class handles that page's actions and display state. This
is the controller for that screen. A separate controller folder is not needed
yet; adding one now would duplicate the same responsibility across extra files.

## How the layers work together

The role gate chooses the Firebase repository implementation and passes it to
screens through the manager or responder interface. Pages call repositories to
load or save records. Services handle device tasks and business rules. Models
carry the incident data between those parts.

For an incident report, the page collects the details, GPS and photo services
provide device information, the local repository keeps a copy on the phone,
and the cloud repository uploads it when the connection is available.
