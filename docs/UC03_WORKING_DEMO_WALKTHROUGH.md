# RangerNet — Use Case 03 (UC03) Working Demo & Implementation Status Guide

**Project:** RangerNet Wildlife Conservation System  
**Module:** UC03 — Monitor Wildlife and Respond to Sensor Alerts  
**Course:** SE3070 Software Engineering  

---

## Part 1: Completed Implementation Status (What We Finished)

We have fully implemented, integrated, and verified the production-ready solution for UC03 according to the Assignment 02 critique.

| Component / Requirement | Status | Implementation Details |
|---|:---:|---|
| **Clean Architecture Structure** | **Finished** | Clear separation across `domain/` (pure business logic), `data/` (repositories & seed), and `presentation/` (controllers, widgets, pages). Zero coupling between UI and data sources. |
| **Domain Models & Value Objects** | **Finished** | `GeoLocation` (with validation), `Sensor` base entity, `GPSCollar`, `CameraTrap`, `Animal` (with risk profiles), `HighRiskZone` (polygons & circles), `WildlifeAlert` (with location history), and `AlertResponse`. |
| **Strategy Design Pattern** | **Finished** | `SensorProcessingStrategy` contract with concrete strategies `GPSCollarProcessingStrategy` and `CameraTrapProcessingStrategy`. |
| **Factory Design Pattern** | **Finished** | `SensorProcessorFactory` for decoupled strategy instantiation based on sensor hardware types. |
| **Geofencing Engine** | **Finished** | 2D Ray-Casting algorithm (Even-Odd rule) for arbitrary polygon zones + Haversine spherical distance formula for circular buffer zones + exact boundary line detection. |
| **Alert De-duplication & Throttling** | **Finished** | `AlertThrottlingService` prevents duplicate alert spam within the 15-minute cooldown window; appends coordinates to the existing alert's `locationHistory` breadcrumbs trail. |
| **Telemetry Ingestion Pipeline** | **Finished** | `SensorTelemetryService` validates coordinates ($-90 \le \text{lat} \le 90$, $-180 \le \text{lon} \le 180$) and battery levels ($0\% \text{ to } 100\%$), dispatches strategies, and records sensor state. |
| **Ranger Workflow Lifecycle** | **Finished** | `AlertWorkflowService` enforces `ACTIVE` $\rightarrow$ `ACKNOWLEDGED` $\rightarrow$ `RESOLVED`. Prohibits illegal transitions (throws `InvalidAlertTransitionException`) and logs audited `AlertResponse` records. |
| **Conservation Priority Sorting** | **Finished** | Automated sorting by risk urgency: `HIGH` (weight 3) $>$ `MEDIUM` (weight 2) $>$ `LOW` (weight 1), followed by timestamp descending. |
| **Interactive Sensor Simulator** | **Finished** | `WildlifeSensorSimulator` and in-app `SensorSimulatorDialog` featuring 7 live demonstration scenarios. |
| **High-Fidelity User Interface** | **Finished** | Material 3 UI adhering to RangerNet forest green theme (`#17613F`): Dashboard with live metric cards, filter chips, online/offline toggle, detailed telemetry view, camera photo preview, and breadcrumb trail. |
| **Shell & App Integration** | **Finished** | Added "Alerts" navigation tab to `RangerNetShell` alongside Incidents (UC02) and Home with quick-action launch buttons. |
| **Unit & Widget Testing Suite** | **Finished** | **84 out of 84 automated tests passing (100% pass rate)** with **0 static analysis issues** (`flutter analyze` clean). |

---

## Part 2: Step-by-Step Live Demo Walkthrough Flow

Follow this exact flow during your live demonstration, evaluation presentation, or viva:

```
[1. Launch & Log In] 
        │
        ▼
[2. Home Navigation] ──► Tap "UC03: Monitor Wildlife & Sensor Alerts" or "Alerts" tab
        │
        ▼
[3. Alerts Dashboard] ──► Inspect Metrics Bar, Priority Sorting, Risk Badges, Online/Offline Toggle
        │
        ▼
[4. Launch Simulator] ──► Open In-App Telemetry Simulator Modal
        │
        ├──► Scenario 1: Elephant Breaches Risk Zone (Spawns HIGH Alert)
        ├──► Scenario 2: Rapid Pings Throttling Demo (1st alert, 2nd & 3rd appended to history)
        ├──► Scenario 3: Camera Trap Poacher Intrusion (AI detection tag + photo)
        └──► Scenario 4: Safe Movement (Shows ingestion without false alarms)
        │
        ▼
[5. Alert Detail Screen] ──► View GPS Coordinates, Sensor Battery, Camera Preview, Location History Trail
        │
        ▼
[6. Acknowledge Alert] ──► Status transitions: ACTIVE ──► ACKNOWLEDGED
        │
        ▼
[7. Resolve Alert Form] ──► Enter Action Taken & Observations: ACKNOWLEDGED ──► RESOLVED
```

---

### Step 1: Sign In & Access the Feature
1. Open the RangerNet application in Chrome / Web / Mobile.
2. Sign in with ranger credentials (or test ranger profile).
3. On the Home screen, notice the new green button:  
   **"UC03: Monitor Wildlife & Sensor Alerts"**  
   or tap the **"Alerts"** radar icon in the bottom navigation bar.

---

### Step 2: Explore the Live Alerts Dashboard
Demonstrate the dashboard features to the evaluator:
1. **Summary Metrics Bar**: Shows real-time counts for:
   - *Active Alerts* (orange badge)
   - *High Risk Active* (red badge)
   - *Acknowledged* (blue badge)
   - *Resolved* (green badge)
2. **Priority Sorting**: Explain that alerts are sorted according to conservation urgency: **HIGH Risk** is always pinned above MEDIUM and LOW, followed by newest pings first.
3. **Filter Chips**: Tap **"Active"**, **"Acknowledged"**, **"Resolved"**, or **"High Risk Only"** to demonstrate instant filtering.
4. **Online / Offline Toggle**: Tap the **"Online"** chip in the top right to switch to **"Offline Mode"**; show that the app operates seamlessly with local caching.

---

### Step 3: Trigger Live Telemetry via the Simulator
Tap **"Launch Simulator"** in the top banner (or the antenna icon in the App Bar). This opens the **Sensor & Wildlife Telemetry Simulator** dialog.

Show these key scenarios to the evaluator:

#### Demo Scenario A: Elephant Breaches High-Risk Zone (Geofence Breach)
- Click **"Trigger"** next to **Scenario 1: Elephant Breaches High-Risk Zone**.
- **Explanation to Evaluator:** *"Tusker Raja (COLLAR-001) has crossed the Southern Agricultural Buffer Zone. The Ray-casting geofence algorithm detects the boundary breach, factors Raja's high-risk conservation profile, and immediately spawns a HIGH priority alert."*
- Notice the success card appears: `🚨 [NEW ALERT: ALERT-XXX]`. Close the dialog to view the new alert at the top of the queue.

#### Demo Scenario B: Alert Throttling & De-duplication (Rapid Pings)
- Open the simulator and click **"Trigger"** next to **Scenario 2: Rapid Pings Throttling Demo**.
- **Explanation to Evaluator:** *"In field deployments, GPS collars ping every few minutes. To prevent ranger alert fatigue, our AlertThrottlingService checks if an active alert exists within the 15-minute cooldown window. Ping 1 triggers the alert, while Ping 2 and Ping 3 are throttled and appended directly to the location history of that alert."*
- Notice the feedback logs:
  - `Ping 1: [NEW ALERT]`
  - `Ping 2: ⚡ [THROTTLED/APPENDED]`
  - `Ping 3: ⚡ [THROTTLED/APPENDED]`

#### Demo Scenario C: Camera Trap Threat Detection
- In the simulator, click **"Trigger"** next to **Scenario 4: Camera Trap - Poaching / Trespass**.
- **Explanation to Evaluator:** *"A motion-triggered camera trap on the Menik Ganga trail captures armed trespassers. The CameraTrapProcessingStrategy evaluates the simulated detection tag `POACHER_WEAPON_DETECTED` and spawns a HIGH threat alert with photo evidence."*

#### Demo Scenario D: Safe Range Movement (Zero False Alarms)
- Click **"Trigger"** next to **Scenario 3: Normal Movement (Safe Range)**.
- **Explanation to Evaluator:** *"The collar transmits valid coordinates from the sanctuary core sector. The geofence engine safely evaluates the coordinates and produces NO alert, ensuring rangers are not distracted by benign telemetry."*

---

### Step 4: Inspect Alert Details & Telemetry Breadcrumbs
Tap on any alert card in the list to open the **Alert Details Screen**:
1. **Header Cards**: Risk Level badge (`HIGH RISK`), status badge (`ACTIVE`), animal profile (`Raja (Tusker) - Sri Lankan Elephant`), and breached zone information.
2. **Sensor Telemetry**: Real-time Latitude, Longitude, Altitude, and Collar Battery percentage gauge.
3. **Camera Photo Preview** *(for Camera Trap alerts)*: Displays the captured photo frame and the red **`AI DETECTION TAG`** banner.
4. **Location Breadcrumbs Timeline**: Point out the **"Telemetry Breadcrumbs (X pings)"** list. Show how throttled pings are chronologically tracked with individual timestamps and coordinates, including the `LATEST` badge.

---

### Step 5: Execute the Ranger Response Workflow
Demonstrate the operational lifecycle:

1. **Acknowledge Alert (`ACTIVE` $\rightarrow$ `ACKNOWLEDGED`):**
   - Tap **"Acknowledge Alert"**.
   - Confirm the dialog.
   - The status updates immediately to **ACKNOWLEDGED**, signaling to all rangers that a response team has been assigned.
2. **Submit Response & Resolve Alert (`ACKNOWLEDGED` $\rightarrow$ `RESOLVED`):**
   - Tap **"Submit Response & Resolve"**.
   - Use the quick presets (e.g., *"Dispatched mobile patrol unit to sweep sector"*).
   - Enter Field Observations: *"Elephant herd repelled safely back across buffer boundary. Fence intact."*
   - Check *"Requires Follow-Up Monitoring"*.
   - Tap **"Confirm Resolution"**.
3. **Audit Trail Verification:**
   - The status badge turns green: **RESOLVED**.
   - Scroll down to view the newly created **Ranger Response Record** displaying ranger name, timestamp, action taken, and field observations.

---

## Part 3: Architecture & Engineering Talking Points for Evaluators

When explaining your design to the examination panel, emphasize these key highlights:

1. **Separation of Concerns (Clean Architecture):**
   - The core business logic (`GeofenceService`, `AlertThrottlingService`, `AlertWorkflowService`) has zero dependencies on Flutter UI or Firebase, enabling 100% unit testability in pure Dart.
2. **Design Patterns Used:**
   - **Strategy Pattern (`SensorProcessingStrategy`):** Decouples telemetry processing for GPS Collars from Camera Traps, following the Open/Closed Principle.
   - **Factory Pattern (`SensorProcessorFactory`):** Eliminates complex conditional checks (`if-else` / `switch`) across the codebase.
   - **Value Object Pattern (`GeoLocation`):** Encapsulates coordinate immutability and validity checks.
3. **Mathematical Algorithms:**
   - **Ray-Casting Algorithm:** Handles complex arbitrary polygons via Even-Odd intersection parity and vector cross-products for exact boundary edges.
   - **Haversine Formula:** Computes spherical surface distances accurately for circular radial zones.
4. **High Quality Assurance Standards:**
   - 84 unit and widget tests covering positive cases, negative cases, boundary conditions, invalid transitions, and mock hardware simulations.
