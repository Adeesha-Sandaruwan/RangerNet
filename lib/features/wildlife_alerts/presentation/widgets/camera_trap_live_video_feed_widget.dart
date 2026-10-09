import 'dart:async';
import 'package:flutter/material.dart';

enum CameraVisionMode {
  daylight('Daylight (True Color)', Icons.wb_sunny),
  nightVision('Night Vision (Infrared)', Icons.nightlight_round),
  thermal('Thermal FLIR (Ironbow)', Icons.thermostat);

  const CameraVisionMode(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Simulated Live Video Feed Player for field-deployed Camera Traps.
/// Features live timestamp ticker, AI vision target bounding box, scanlines,
/// vision mode filters (Daylight, Night Vision, Thermal), and manual capture.
class CameraTrapLiveVideoFeedWidget extends StatefulWidget {
  const CameraTrapLiveVideoFeedWidget({
    required this.cameraTrapId,
    this.cameraName,
    this.initialImageUrl,
    this.detectionTag,
    this.batteryLevel = 88.0,
    this.temperature = 28.5,
    this.onSnapshotCaptured,
    super.key,
  });

  final String cameraTrapId;
  final String? cameraName;
  final String? initialImageUrl;
  final String? detectionTag;
  final double batteryLevel;
  final double temperature;
  final void Function(String snapshotMessage)? onSnapshotCaptured;

  @override
  State<CameraTrapLiveVideoFeedWidget> createState() =>
      _CameraTrapLiveVideoFeedWidgetState();
}

class _CameraTrapLiveVideoFeedWidgetState
    extends State<CameraTrapLiveVideoFeedWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _streamAnimController;
  CameraVisionMode _visionMode = CameraVisionMode.daylight;
  bool _isPlaying = true;
  bool _showShutterFlash = false;
  final int _fpsCounter = 30;
  Timer? _clockTimer;
  Timer? _flashTimer;
  DateTime _currentLiveTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _streamAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _clockTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted && _isPlaying) {
        setState(() {
          _currentLiveTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _streamAnimController.dispose();
    _clockTimer?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  void _triggerSnapshotCapture() {
    setState(() => _showShutterFlash = true);
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _showShutterFlash = false);
    });

    final msg =
        'Live frame snapshot captured from ${widget.cameraTrapId} at ${_formatLiveTime(_currentLiveTime)}';
    widget.onSnapshotCaptured?.call(msg);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.camera_alt, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: const Color(0xFF17613F),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openFullscreenModal() {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: SizedBox(
          width: 900,
          height: 600,
          child: Column(
            children: [
              Container(
                color: const Color(0xFF14241C),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.videocam, color: Colors.greenAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Live Video Feed — ${widget.cameraName ?? widget.cameraTrapId}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CameraTrapLiveVideoFeedWidget(
                  cameraTrapId: widget.cameraTrapId,
                  cameraName: widget.cameraName,
                  initialImageUrl: widget.initialImageUrl,
                  detectionTag: widget.detectionTag,
                  batteryLevel: widget.batteryLevel,
                  temperature: widget.temperature,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F0D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Video Monitor Screen
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Base visual video frame with slight camera sway
                  AnimatedBuilder(
                    animation: _streamAnimController,
                    builder: (context, child) {
                      final sway = _isPlaying
                          ? (mathSine(_streamAnimController.value * 3.14159) * 0.02)
                          : 0.0;
                      return Transform.scale(
                        scale: 1.05 + sway,
                        child: _buildFilteredVideoFrame(),
                      );
                    },
                  ),

                  // CRT scanlines effect
                  _buildScanlinesOverlay(),

                  // AI Computer Vision Bounding Box
                  if (widget.detectionTag != null &&
                      widget.detectionTag != 'NORMAL_PASSAGE')
                    _buildAiDetectionOverlay(),

                  // Top Live CCTV HUD Banner
                  _buildTopHudBanner(),

                  // Bottom Live Stream Telemetry Banner
                  _buildBottomHudBanner(),

                  // White flash on snapshot
                  if (_showShutterFlash)
                    Container(color: Colors.white.withValues(alpha: 0.85)),
                ],
              ),
            ),
          ),

          // 2. Control Bar below the stream
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF141F18),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Play / Pause Stream
                IconButton(
                  tooltip: _isPlaying ? 'Pause live feed' : 'Resume live feed',
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle : Icons.play_circle,
                    color: Colors.greenAccent,
                    size: 26,
                  ),
                  onPressed: () => setState(() => _isPlaying = !_isPlaying),
                ),

                // Vision Mode Selectors
                ...CameraVisionMode.values.map((mode) {
                  final isSelected = _visionMode == mode;
                  return ChoiceChip(
                    avatar: Icon(
                      mode.icon,
                      size: 14,
                      color: isSelected ? Colors.black : Colors.white70,
                    ),
                    label: Text(
                      mode.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.black : Colors.white70,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: Colors.greenAccent,
                    backgroundColor: const Color(0xFF1E2E25),
                    onSelected: (_) => setState(() => _visionMode = mode),
                  );
                }),

                const SizedBox(width: 8),

                // Capture snapshot button
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF17613F),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: _triggerSnapshotCapture,
                  icon: const Icon(Icons.camera, size: 14),
                  label: const Text('Capture Frame', style: TextStyle(fontSize: 11)),
                ),

                // Expand Fullscreen
                IconButton(
                  tooltip: 'Fullscreen live view',
                  icon: const Icon(Icons.fullscreen, color: Colors.white70),
                  onPressed: _openFullscreenModal,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredVideoFrame() {
    Widget imageContent;

    if (widget.initialImageUrl != null) {
      imageContent = Image.network(
        widget.initialImageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildFallbackBackground(),
      );
    } else {
      imageContent = _buildFallbackBackground();
    }

    switch (_visionMode) {
      case CameraVisionMode.daylight:
        return imageContent;

      case CameraVisionMode.nightVision:
        // Night Vision: Green phosphor infrared filter
        return ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.1, 0.9, 0.1, 0, 0, // Green channel amplified
            0.1, 1.2, 0.1, 0, 0,
            0.0, 0.3, 0.1, 0, 0,
            0.0, 0.0, 0.0, 1, 0,
          ]),
          child: imageContent,
        );

      case CameraVisionMode.thermal:
        // Thermal: FLIR ironbow heatmap filter
        return ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            1.8, 0.2, 0.0, 0, 20, // High red/orange heat
            0.4, 0.8, 0.1, 0, 10,
            0.1, 0.1, 1.5, 0, 40, // Cool background
            0.0, 0.0, 0.0, 1, 0,
          ]),
          child: imageContent,
        );
    }
  }

  Widget _buildFallbackBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF10281E), Color(0xFF0A140F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_outlined, size: 48, color: Colors.green.shade400),
            const SizedBox(height: 8),
            Text(
              'LIVE RTSP FEED: ${widget.cameraTrapId}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontFamily: 'monospace',
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanlinesOverlay() {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.05, 0.5, 0.95, 1.0],
            colors: [
              Colors.black.withValues(alpha: 0.3),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.05),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHudBanner() {
    return Positioned(
      top: 10,
      left: 12,
      right: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // REC Blink and Camera Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedOpacity(
                  opacity: _isPlaying ? 1.0 : 0.2,
                  duration: const Duration(milliseconds: 600),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'REC  LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),

          // Live Time Ticker
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _formatLiveTime(_currentLiveTime),
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 10,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomHudBanner() {
    return Positioned(
      bottom: 10,
      left: 12,
      right: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Node ID & stream telemetry
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${widget.cameraTrapId} • 1080p @ $_fpsCounter FPS • ${_visionMode.name.toUpperCase()}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ),

          // Battery & Solar Gauge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.solar_power, size: 12, color: Colors.amberAccent),
                const SizedBox(width: 4),
                const Text('SOLAR OK',
                    style: TextStyle(color: Colors.amberAccent, fontSize: 9)),
                const SizedBox(width: 8),
                const Icon(Icons.battery_charging_full,
                    size: 12, color: Colors.greenAccent),
                const SizedBox(width: 4),
                Text(
                  '${widget.batteryLevel.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiDetectionOverlay() {
    final tag = widget.detectionTag ?? 'TARGET DETECTED';
    final isPoacher = tag.contains('POACHER') || tag.contains('HUMAN');

    return Center(
      child: Container(
        width: 170,
        height: 130,
        decoration: BoxDecoration(
          border: Border.all(
            color: isPoacher ? Colors.redAccent : Colors.amberAccent,
            width: 2.0,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          children: [
            // Target corner reticles
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                        color: isPoacher ? Colors.red : Colors.amber, width: 3),
                    left: BorderSide(
                        color: isPoacher ? Colors.red : Colors.amber, width: 3),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                        color: isPoacher ? Colors.red : Colors.amber, width: 3),
                    right: BorderSide(
                        color: isPoacher ? Colors.red : Colors.amber, width: 3),
                  ),
                ),
              ),
            ),

            // AI classification label tag
            Positioned(
              top: -20,
              left: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPoacher ? Colors.red : Colors.amber.shade900,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'AI: $tag (97.4%)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double mathSine(double radians) {
    // Simple harmonic Taylor approximation for gentle sway without external dependencies
    double x = radians % (2 * 3.14159265);
    if (x > 3.14159265) x -= 2 * 3.14159265;
    return x - (x * x * x) / 6.0;
  }

  String _formatLiveTime(DateTime dt) {
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    final ms = (dt.millisecond ~/ 100).toString();
    return '$y-$m-$d $hh:$mm:$ss.$ms';
  }
}
