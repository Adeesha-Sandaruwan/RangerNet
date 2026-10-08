import '../models/sensor.dart';
import 'sensor_processing_strategy.dart';

/// Factory class to provide the appropriate SensorProcessingStrategy
/// based on the sensor hardware type.
class SensorProcessorFactory {
  SensorProcessorFactory({
    SensorProcessingStrategy? gpsCollarStrategy,
    SensorProcessingStrategy? cameraTrapStrategy,
  }) : _gpsCollarStrategy = gpsCollarStrategy ?? const GPSCollarProcessingStrategy(),
       _cameraTrapStrategy = cameraTrapStrategy ?? const CameraTrapProcessingStrategy();

  final SensorProcessingStrategy _gpsCollarStrategy;
  final SensorProcessingStrategy _cameraTrapStrategy;

  /// Returns the strategy matching the given sensor type.
  SensorProcessingStrategy getStrategy(SensorType sensorType) {
    switch (sensorType) {
      case SensorType.gpsCollar:
        return _gpsCollarStrategy;
      case SensorType.cameraTrap:
        return _cameraTrapStrategy;
    }
  }

  /// Convenience method to resolve strategy directly from a Sensor instance.
  SensorProcessingStrategy getStrategyForSensor(Sensor sensor) {
    return getStrategy(sensor.sensorType);
  }
}
