import '../../domain/models/alert_response.dart';
import '../../domain/models/animal.dart';
import '../../domain/models/geo_location.dart';
import '../../domain/models/high_risk_zone.dart';
import '../../domain/models/sensor.dart';
import '../../domain/models/wildlife_alert.dart';

class WildlifeSeedData {
  static final DateTime _baseTime = DateTime.now().subtract(
    const Duration(hours: 2),
  );

  // High-Risk Geofence Zones in Yala National Park Conservation Sector
  static final List<HighRiskZone> initialZones = [
    HighRiskZone(
      zoneId: 'ZONE-POACH-01',
      name: 'Southern Boundary Human Buffer Zone',
      severityLevel: ZoneSeverityLevel.high,
      description:
          'Border abutting sugarcane farms where human-elephant conflict and snare traps are prevalent.',
      boundaryPolygon: [
        GeoLocation(latitude: 6.3500, longitude: 81.4500, timestamp: _baseTime),
        GeoLocation(latitude: 6.3700, longitude: 81.4500, timestamp: _baseTime),
        GeoLocation(latitude: 6.3700, longitude: 81.4800, timestamp: _baseTime),
        GeoLocation(latitude: 6.3500, longitude: 81.4800, timestamp: _baseTime),
      ],
      centerLocation: GeoLocation(
        latitude: 6.3600,
        longitude: 81.4650,
        timestamp: _baseTime,
      ),
      radiusMeters: 2500,
      isActive: true,
    ),
    HighRiskZone(
      zoneId: 'ZONE-RIVER-02',
      name: 'Menik Ganga Poaching Hotspot',
      severityLevel: ZoneSeverityLevel.high,
      description:
          'Dense riverine corridor known for illegal snares and gemstone mining intrusion.',
      centerLocation: GeoLocation(
        latitude: 6.4200,
        longitude: 81.3900,
        timestamp: _baseTime,
      ),
      radiusMeters: 1800,
      isActive: true,
    ),
    HighRiskZone(
      zoneId: 'ZONE-BUFFER-03',
      name: 'West Perimeter Highway Buffer',
      severityLevel: ZoneSeverityLevel.medium,
      description: 'Road reserve buffer prone to vehicular wildlife collision.',
      centerLocation: GeoLocation(
        latitude: 6.4800,
        longitude: 81.3200,
        timestamp: _baseTime,
      ),
      radiusMeters: 1200,
      isActive: true,
    ),
  ];

  // Monitored Animals
  static final List<Animal> initialAnimals = [
    const Animal(
      id: 'ANIMAL-ELE-01',
      name: 'Raja (Tusker)',
      species: 'Sri Lankan Elephant (Elephas maximus maximus)',
      collarId: 'COLLAR-001',
      riskProfile: AnimalRiskProfile.high,
      notes:
          'Dominant bull elephant; carries history of raiding village farms near Southern Border.',
    ),
    const Animal(
      id: 'ANIMAL-LEO-02',
      name: 'Maya',
      species: 'Sri Lankan Leopard (Panthera pardus kotiya)',
      collarId: 'COLLAR-002',
      riskProfile: AnimalRiskProfile.high,
      notes:
          'Breeding female with cubs frequently patrolling rocky outcrops near river bank.',
    ),
    const Animal(
      id: 'ANIMAL-SAM-03',
      name: 'Samba',
      species: 'Sambar Deer (Rusa unicolor)',
      collarId: 'COLLAR-003',
      riskProfile: AnimalRiskProfile.low,
      notes: 'Adult male monitored for herd migratory movement analysis.',
    ),
  ];

  // Registered Sensors
  static final List<Sensor> initialSensors = [
    GPSCollar(
      id: 'COLLAR-001',
      name: 'Collar Raja',
      batteryLevel: 88.0,
      status: SensorStatus.active,
      lastActiveAt: _baseTime.add(const Duration(minutes: 90)),
      animalId: 'ANIMAL-ELE-01',
      currentLocation: GeoLocation(
        latitude: 6.3620,
        longitude: 81.4610,
        altitude: 45.0,
        timestamp: _baseTime.add(const Duration(minutes: 90)),
      ),
    ),
    GPSCollar(
      id: 'COLLAR-002',
      name: 'Collar Maya',
      batteryLevel: 94.0,
      status: SensorStatus.active,
      lastActiveAt: _baseTime.add(const Duration(minutes: 85)),
      animalId: 'ANIMAL-LEO-02',
      currentLocation: GeoLocation(
        latitude: 6.4150,
        longitude: 81.3850,
        altitude: 62.0,
        timestamp: _baseTime.add(const Duration(minutes: 85)),
      ),
    ),
    GPSCollar(
      id: 'COLLAR-003',
      name: 'Collar Samba',
      batteryLevel: 75.0,
      status: SensorStatus.active,
      lastActiveAt: _baseTime.add(const Duration(minutes: 70)),
      animalId: 'ANIMAL-SAM-03',
      currentLocation: GeoLocation(
        latitude: 6.4500,
        longitude: 81.3500,
        altitude: 35.0,
        timestamp: _baseTime.add(const Duration(minutes: 70)),
      ),
    ),
    CameraTrap(
      id: 'CAM-TRAP-101',
      name: 'North Gate Trail Camera',
      batteryLevel: 82.0,
      status: SensorStatus.active,
      lastActiveAt: _baseTime.add(const Duration(minutes: 60)),
      cameraLocation: GeoLocation(
        latitude: 6.4215,
        longitude: 81.3912,
        altitude: 50.0,
        timestamp: _baseTime,
      ),
      triggerTimestamp: _baseTime.add(const Duration(minutes: 60)),
      capturedImageUrl:
          'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=600&q=80',
      simulatedDetectionTag: 'HUMAN_TRESPASS_SUSPECT',
    ),
    CameraTrap(
      id: 'CAM-TRAP-102',
      name: 'Patanangala Waterhole Cam',
      batteryLevel: 91.0,
      status: SensorStatus.active,
      lastActiveAt: _baseTime.add(const Duration(minutes: 30)),
      cameraLocation: GeoLocation(
        latitude: 6.3800,
        longitude: 81.4100,
        altitude: 28.0,
        timestamp: _baseTime,
      ),
      triggerTimestamp: _baseTime.add(const Duration(minutes: 30)),
      capturedImageUrl:
          'https://images.unsplash.com/photo-1564349683136-77e08dba1ef7?auto=format&fit=crop&w=600&q=80',
      simulatedDetectionTag: 'NORMAL_PASSAGE',
    ),
  ];

  // Initial Sample Alerts (Demonstrates Active, Acknowledged, and Resolved states)
  static final List<WildlifeAlert> initialAlerts = [
    WildlifeAlert(
      alertId: 'ALERT-001',
      sensorId: 'COLLAR-001',
      targetId: 'ANIMAL-ELE-01',
      targetName: 'Raja (Tusker)',
      targetSpecies: 'Sri Lankan Elephant',
      riskLevel: AlertRiskLevel.high,
      status: AlertStatus.active,
      triggerType: AlertTriggerType.geofenceBreach,
      title: 'HIGH: Raja (Tusker) breached Southern Boundary Human Buffer Zone',
      description:
          'Elephant Raja crossed 240m inside agricultural buffer adjacent to village perimeter. Potential human-wildlife conflict hazard.',
      triggeredAt: _baseTime.add(const Duration(minutes: 60)),
      lastUpdatedAt: _baseTime.add(const Duration(minutes: 75)),
      zoneId: 'ZONE-POACH-01',
      zoneName: 'Southern Boundary Human Buffer Zone',
      currentLocation: GeoLocation(
        latitude: 6.3620,
        longitude: 81.4610,
        altitude: 45.0,
        timestamp: _baseTime.add(const Duration(minutes: 75)),
      ),
      locationHistory: [
        GeoLocation(
          latitude: 6.3580,
          longitude: 81.4580,
          altitude: 44.0,
          timestamp: _baseTime.add(const Duration(minutes: 60)),
        ),
        GeoLocation(
          latitude: 6.3600,
          longitude: 81.4595,
          altitude: 45.0,
          timestamp: _baseTime.add(const Duration(minutes: 68)),
        ),
        GeoLocation(
          latitude: 6.3620,
          longitude: 81.4610,
          altitude: 45.0,
          timestamp: _baseTime.add(const Duration(minutes: 75)),
        ),
      ],
    ),
    WildlifeAlert(
      alertId: 'ALERT-002',
      sensorId: 'CAM-TRAP-101',
      targetId: 'CAM-TRAP-101',
      targetName: 'North Gate Trail Camera',
      targetSpecies: 'Human Intrusion',
      riskLevel: AlertRiskLevel.high,
      status: AlertStatus.acknowledged,
      triggerType: AlertTriggerType.cameraDetection,
      title:
          'HIGH THREAT: Human Intrusion / Poaching Detected at River Corridors',
      description:
          'Camera Trap CAM-TRAP-101 flagged armed human motion near Menik Ganga crossing after dusk.',
      triggeredAt: _baseTime.add(const Duration(minutes: 30)),
      acknowledgedAt: _baseTime.add(const Duration(minutes: 40)),
      acknowledgedByRangerId: 'RANGER-LEAD-07',
      lastUpdatedAt: _baseTime.add(const Duration(minutes: 40)),
      capturedImageUrl:
          'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=600&q=80',
      simulatedDetectionTag: 'HUMAN_TRESPASS_SUSPECT',
      currentLocation: GeoLocation(
        latitude: 6.4215,
        longitude: 81.3912,
        altitude: 50.0,
        timestamp: _baseTime.add(const Duration(minutes: 30)),
      ),
      locationHistory: [
        GeoLocation(
          latitude: 6.4215,
          longitude: 81.3912,
          altitude: 50.0,
          timestamp: _baseTime.add(const Duration(minutes: 30)),
        ),
      ],
    ),
    WildlifeAlert(
      alertId: 'ALERT-003',
      sensorId: 'COLLAR-002',
      targetId: 'ANIMAL-LEO-02',
      targetName: 'Maya',
      targetSpecies: 'Sri Lankan Leopard',
      riskLevel: AlertRiskLevel.medium,
      status: AlertStatus.resolved,
      triggerType: AlertTriggerType.geofenceBreach,
      title: 'MEDIUM: Maya approached Menik Ganga Poaching Hotspot',
      description:
          'Leopard crossed near old wire snare sector. Quick response team inspected area.',
      triggeredAt: _baseTime.subtract(const Duration(hours: 4)),
      acknowledgedAt: _baseTime.subtract(const Duration(hours: 3, minutes: 45)),
      acknowledgedByRangerId: 'RANGER-LEAD-07',
      resolvedAt: _baseTime.subtract(const Duration(hours: 3)),
      resolvedByRangerId: 'RANGER-LEAD-07',
      responseNotes:
          'Action: Dispatched mobile patrol team. Swept perimeter and dismantled 2 abandoned wire snares. Animal returned safely to park core.',
      lastUpdatedAt: _baseTime.subtract(const Duration(hours: 3)),
      zoneId: 'ZONE-RIVER-02',
      zoneName: 'Menik Ganga Poaching Hotspot',
      currentLocation: GeoLocation(
        latitude: 6.4150,
        longitude: 81.3850,
        altitude: 62.0,
        timestamp: _baseTime.subtract(const Duration(hours: 4)),
      ),
      locationHistory: [
        GeoLocation(
          latitude: 6.4150,
          longitude: 81.3850,
          altitude: 62.0,
          timestamp: _baseTime.subtract(const Duration(hours: 4)),
        ),
      ],
    ),
  ];

  static final List<AlertResponse> initialResponses = [
    AlertResponse(
      responseId: 'RESP-001',
      alertId: 'ALERT-003',
      rangerId: 'RANGER-LEAD-07',
      rangerName: 'Officer K. Perera',
      actionTaken:
          'Dispatched patrol squad, swept area with metal detector and dismantled 2 wire snares.',
      observations:
          'Maya was visually confirmed moving north back into high canopy forest undamaged.',
      timestamp: _baseTime.subtract(const Duration(hours: 3)),
      followUpRequired: false,
    ),
  ];
}
