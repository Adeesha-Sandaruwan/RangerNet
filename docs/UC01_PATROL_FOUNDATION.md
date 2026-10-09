# UC01 patrol domain and local persistence foundation

This foundation adds patrol records, lifecycle rules, an injectable repository
boundary, a local Shared Preferences adapter, and a service that coordinates
patrol operations. It does not yet add screens, continuous GPS collection,
photo capture/compression, assignment loading, or cloud synchronization.

## Domain and lifecycle

- `Patrol` holds the assignment, ranger, park/zone/route, locations, route
  points, manual waypoints, observations, photographs, pause/resume history,
  sync metadata, and optional coverage summary.
- Patrol and synchronization states are separate. A patrol can be
  `completedPendingSync` or `completedSynced`; interruption and early
  termination have distinct states and reasons.
- Route distance is derived from recorded route points. Active duration is
  derived from start/end times and pause/resume events, excluding paused time.
- `PatrolWorkflowPolicy` validates lifecycle transitions and blocks recording
  new field records outside an active or paused patrol.
- `PatrolService` is the application boundary for starting, pausing, resuming,
  completing, interrupting, terminating, recording, and updating sync state.

## Local persistence

`PatrolRepository` is the storage port. `LocalPatrolRepository` implements it
using `PatrolLocalStore`, which stores each ranger's patrol collection as
versioned JSON through the project's existing Shared Preferences dependency.
`PatrolCodec` owns serialization; domain models remain independent of JSON and
Flutter plugins. Saves replace by stable local ID and serialized writes avoid
lost updates within a repository instance.

The current adapter is suitable as an initial assignment foundation, not a
high-volume route database. JSON rewrites the ranger's patrol collection on
each save, and photographs are inline Base64 fields. Before long-duration or
high-frequency tracking is enabled, validate expected route/photo volume and
consider moving binary evidence to files and route records to a database.

## Tests

Patrol tests cover model validation and derived metrics, workflow transitions,
service operations, record serialization, and local persistence. The cloud
schema and Firestore rules still need to be designed before patrol sync is
implemented.
