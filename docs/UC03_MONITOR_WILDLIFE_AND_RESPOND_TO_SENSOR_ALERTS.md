# Use Case 03 (UC03): Monitor Wildlife and Respond to Sensor Alerts

## Executive Summary
This document provides complete architecture, design patterns, domain logic, and testing documentation for **UC03: Monitor Wildlife and Respond to Sensor Alerts** in the RangerNet Wildlife Conservation System, implemented in accordance with the SE3070 Software Engineering assignment critique.

---

## 1. Architectural Pattern (Clean Architecture)

```
lib/features/wildlife_alerts/
├── domain/
│   ├── models/
│   │   ├── geo_location.dart               # Value Object: Lat, Lon, Altitude, Timestamp
│   │   ├── sensor.dart                     # Abstract Sensor, GPSCollar, CameraTrap
│   │   ├── animal.dart                     # Animal entity, Conservation risk profile
│   │   ├── high_risk_zone.dart             # HighRiskZone: Polygon (Ray-casting) & Circular (Haversine)
│   │   ├── wildlife_alert.dart             # WildlifeAlert entity with lifecycle & location history
│   │   └── alert_response.dart             # AlertResponse entity (ranger actions & observations)
│   ├── services/
│   │   ├── geofence_service.dart           # Ray-casting algorithm & Haversine distance
│   │   ├── sensor_processing_strategy.dart # Strategy Pattern (GPS & Camera Trap processors)
│   │   ├── sensor_processor_factory.dart   # Factory Pattern for sensor processors
│   │   ├── alert_throttling_service.dart   # De-duplication & Throttling service
│   │   ├── sensor_telemetry_service.dart   # Telemetry Ingestion API / pipeline
│   │   ├── alert_workflow_service.dart     # Ranger workflow: ACTIVE -> ACKNOWLEDGED -> RESOLVED
│   │   └── wildlife_sensor_simulator.dart  # Live simulation scenarios for mock hardware
│   └── repositories/
│       └── wildlife_alert_repository.dart  # Abstract Repository interface
├── data/
│   ├── repositories/
│   │   └── wildlife_alert_repository_impl.dart # Memory cache + Firestore synchronization capability
│   └── seed/
│       └── wildlife_seed_data.dart         # Realistic national park seed data
└── presentation/
    ├── controllers/
    │   └── wildlife_alert_controller.dart  # ChangeNotifier state controller
    ├── dialogs/
    │   ├── submit_response_dialog.dart     # Form to resolve alert with actions & observations
    │   └── sensor_simulator_dialog.dart    # Interactive 7-scenario live simulator UI
    ├── widgets/
    │   ├── alert_badges.dart               # Risk level (High/Med/Low) & Status badges
    │   └── location_history_timeline.dart  # Breadcrumbs trail visualizer (throttled pings)
    └── pages/
        ├── wildlife_alert_dashboard_page.dart # Metrics bar, filters, real-time alert cards
        └── wildlife_alert_detail_page.dart    # Telemetry details, camera preview, action buttons
```

---

## 2. Core Domain Models

| Model | Attributes & Types | Description |
|---|---|---|
| `GeoLocation` | `latitude`, `longitude`, `altitude`, `timestamp` | Value object with validity checks (lat: `[-90, 90]`, lon: `[-180, 180]`). |
| `Sensor` *(Base)* | `id`, `sensorType`, `batteryLevel`, `status`, `lastActiveAt`, `name` | Abstract base entity for all conservation field sensors. |
| `GPSCollar` | Subtype of `Sensor`, `animalId`, `currentLocation` | Tracks animal movement and collar battery. |
| `CameraTrap` | Subtype of `Sensor`, `cameraLocation`, `triggerTimestamp`, `capturedImageUrl`, `simulatedDetectionTag` | Fixed camera trap with AI vision classification tags. |
| `Animal` | `id`, `name`, `species`, `collarId`, `riskProfile`, `notes` | Wildlife subject; risk profile (`high`, `medium`, `low`) impacts alert prioritization. |
| `HighRiskZone` | `zoneId`, `name`, `severityLevel`, `boundaryPolygon`, `centerLocation`, `radiusMeters` | High-risk geofence zones supporting both polygons and radial circles. |
| `WildlifeAlert` | `alertId`, `sensorId`, `targetId`, `riskLevel`, `status`, `triggeredAt`, `resolvedAt`, `responseNotes`, `locationHistory` | Alert lifecycle entity with breadcrumb tracking history. |
| `AlertResponse` | `responseId`, `alertId`, `rangerId`, `actionTaken`, `observations`, `timestamp`, `followUpRequired` | Formal field intervention record logged by ranger. |

---

## 3. Design Patterns & Business Logic

### A. Strategy Pattern (`SensorProcessingStrategy`)
Allows decoupled algorithms for processing different sensor types:
- `GPSCollarProcessingStrategy`: Evaluates animal coordinates against polygon and radial geofences; factors animal vulnerability and zone severity into risk level; flags low battery (< 10%).
- `CameraTrapProcessingStrategy`: Evaluates simulated vision detection tags (`POACHER_WEAPON_DETECTED`, `HUMAN_TRESPASS`, `DISTRESSED_INJURED_ANIMAL`, `NORMAL_PASSAGE`).

### B. Factory Pattern (`SensorProcessorFactory`)
Instantiates and delivers the correct `SensorProcessingStrategy` based on `SensorType.gpsCollar` or `SensorType.cameraTrap`.

### C. Geofencing Algorithms (`GeofenceService`)
1. **Ray-Casting Algorithm (Even-Odd Rule)**: Evaluates whether a geographic point is inside arbitrary polygon boundaries. Detects exact boundary edge intersections with collinearity cross-products.
2. **Haversine Formula**: Computes spherical great-circle distance for circular radius zones.

### D. Alert De-duplication & Throttling (`AlertThrottlingService`)
Prevents ranger alert fatigue:
- When an active/acknowledged alert exists for the same animal in the same zone within a configured cooldown period (15 minutes), subsequent telemetry pings **DO NOT** spawn duplicate alerts.
- Instead, the coordinates are appended to the existing alert's `locationHistory` list, providing a live breadcrumb trail!

### E. Ranger Workflow (`AlertWorkflowService`)
- Strict status transitions:
  - `ACTIVE` -> `ACKNOWLEDGED`
  - `ACKNOWLEDGED` -> `RESOLVED` (requires `actionTaken` and `observations`)
- Invalid transitions (e.g. attempting to acknowledge or resolve an already resolved alert) throw `InvalidAlertTransitionException`.
- Priority sorting: `HIGH` (3) > `MEDIUM` (2) > `LOW` (1), then newest first.

---

## 4. Live Sensor Simulator Scenarios

The simulator provides 7 automated mock hardware scenarios accessible from both the UI dialog and automated test scripts:
1. **Scenario 1: Elephant Breaches High-Risk Zone** - Tusker Raja moves into the Southern Agricultural Buffer Zone -> Spawns HIGH risk geofence breach alert.
2. **Scenario 2: Rapid Pings Throttling Demo** - 3 rapid GPS pings sent 1-3 mins apart -> 1st creates alert; 2nd and 3rd are throttled and appended as location history breadcrumbs.
3. **Scenario 3: Normal Movement (Safe Range)** - Elephant feeds within sanctuary core sector -> Ingested without spawning alert.
4. **Scenario 4: Camera Trap: Poacher / Human Intrusion** - Armed trespasser detected -> HIGH threat alert with photo preview.
5. **Scenario 5: Camera Trap: Distressed Wildlife** - Injured leopard flagged -> High priority veterinary intervention alert.
6. **Scenario 6: Exact Geofence Boundary Test** - Collar positioned on polygon edge -> Spawns alert with exact boundary notice.
7. **Scenario 7: Critical Collar Battery (<10%)** - Collar battery drops to 8.5% -> Hardware maintenance alert.

---

## 5. Comprehensive Unit Testing

All unit tests are located in `test/features/wildlife_alerts/`:
- `geofence_service_test.dart` (7 tests): Ray-casting inside, outside, exact boundary, circular Haversine, invalid coordinates, multi-zone prioritization.
- `sensor_processing_strategy_test.dart` (7 tests): Factory resolution, GPS geofence breach, GPS safe zone, low battery, camera poacher threat, camera distressed animal, normal passage, type safety.
- `alert_throttling_service_test.dart` (5 tests): Throttling within cooldown, expired cooldown, different animal, different zone, resolved alert.
- `sensor_telemetry_service_test.dart` (7 tests): End-to-end ingestion pipeline, throttling history append, invalid lat/lon rejection, invalid battery rejection, unregistered collar rejection, camera trap threats.
- `alert_workflow_service_test.dart` (8 tests): Ranger acknowledge, ranger resolve with AlertResponse, priority sorting, invalid transitions (already acknowledged, already resolved, empty actions, invalid ID).
- `wildlife_sensor_simulator_test.dart` (7 tests): All 7 end-to-end mock hardware simulation scenarios.
- `wildlife_alerts_ui_test.dart` (8 tests): Controller metrics, status and risk filters, acknowledge/resolve controller workflow, online/offline toggle, badges and timeline widget tests.

**Total Test Suite Status:**
- **84/84 tests passed (100% pass rate).**
- **0 errors or lint warnings (`flutter analyze` clean).**
