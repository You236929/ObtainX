import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

/// A circular progress indicator with a wavy arc that ripples
/// along the active portion rather than rotating the ring.
class CircularRipplingWavyProgressIndicator extends StatefulWidget {
  final double? value;
  final CircularProgressM3ESize size;
  final Color? activeColor;
  final Color? trackColor;

  /// Smooth transition duration when [value] changes.
  final Duration dragDuration;

  /// Wave animation speed in cycles per second.
  final double waveSpeed;

  /// Width of the painted stroke.
  final double strokeWidth;

  /// Arc-length gap between the track and active arcs. Defaults to 5.0.
  final double gapWidth;

  /// Radial amplitude of the wave squiggle.
  final double amplitude;

  /// Along‑arc wavelength in logical pixels.
  final double wavelength;

  /// Number of line segments used to draw the wavy arc.
  final int steps;

  const CircularRipplingWavyProgressIndicator({
    super.key,
    this.value,
    this.size = CircularProgressM3ESize.m,
    this.activeColor,
    this.trackColor,
    this.dragDuration = const Duration(milliseconds: 500),
    this.waveSpeed = 1.0,
    this.strokeWidth = 4.0,
    this.gapWidth = 5.0,
    this.amplitude = 1.0,
    this.wavelength = 15.0,
    this.steps = 120,
  });

  @override
  State<CircularRipplingWavyProgressIndicator> createState() =>
      _CircularRipplingWavyProgressState();
}

class _CircularRipplingWavyProgressState
    extends State<CircularRipplingWavyProgressIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _phaseController;
  late final AnimationController _valueController;
  late final Listenable _mergedListeners;

  Duration _getDuration(double cyclesPerSecond) {
    return Duration(
      milliseconds: (1000 / cyclesPerSecond.clamp(0.001, double.infinity))
          .round(),
    );
  }

  @override
  void initState() {
    super.initState();
    _phaseController = AnimationController(
      vsync: this,
      duration: _getDuration(widget.waveSpeed),
      lowerBound: 1e-10,
      upperBound: 2 * math.pi,
    )..repeat();
    _valueController = AnimationController(
      vsync: this,
      duration: widget.dragDuration,
      value: widget.value,
    );
    _mergedListeners = Listenable.merge([_phaseController, _valueController]);
  }

  @override
  void didUpdateWidget(
    covariant CircularRipplingWavyProgressIndicator oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.waveSpeed != widget.waveSpeed) {
      _phaseController.duration = _getDuration(widget.waveSpeed);
      if (_phaseController.isAnimating) {
        _phaseController.repeat();
      }
    }
    if (oldWidget.value != widget.value && widget.value != null) {
      _valueController.animateTo(
        widget.value!,
        duration: widget.dragDuration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _phaseController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _mergedListeners,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        final active = widget.activeColor ?? cs.primary;
        final track =
            widget.trackColor ?? cs.onSurfaceVariant.withValues(alpha: 0.24);
        final value = widget.value == null ? null : _valueController.value;
        return RepaintBoundary(
          child: SizedBox(
            width: widget.size.diameterWavy,
            height: widget.size.diameterWavy,
            child: CustomPaint(
              painter: _CircularRipplingWavyPainter(
                value: value,
                active: active,
                track: track,
                phase: _phaseController.value,
                strokeWidth: widget.strokeWidth,
                amplitude: widget.amplitude,
                wavelength: widget.wavelength,
                steps: widget.steps,
                gapWidth: widget.gapWidth,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CircularRipplingWavyPainter extends CustomPainter {
  _CircularRipplingWavyPainter({
    this.value,
    required this.active,
    required this.track,
    required this.phase,
    required this.strokeWidth,
    required this.amplitude,
    required this.wavelength,
    required this.steps,
    required this.gapWidth,
  });

  final double? value;
  final Color active;
  final Color track;
  final double phase;
  final double strokeWidth;
  final double amplitude;
  final double wavelength;
  final int steps;
  final double gapWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    if (radius <= 0) return;

    const startAngle = -math.pi / 2;
    final sweep = value == null
        ? 2 * math.pi
        : value!.clamp(0.0, 1.0) * 2 * math.pi;
    final endAngle = startAngle + sweep;

    final gapArcLen = sweep == 0 ? 0.0 : gapWidth;
    final gapAngle = gapArcLen / radius;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Draw the track arc with a gap at both ends of the active arc
    if (value != null && value! < 1.0) {
      final trackSweep = 2 * math.pi - sweep - 2 * gapAngle;
      if (trackSweep > 0) {
        canvas.drawArc(
          rect,
          endAngle + gapAngle,
          trackSweep,
          false,
          Paint()
            ..color = track
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    if (sweep <= 0) return;

    // Draw the wavy active arc

    final wavePaint = Paint()
      ..color = active
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final angle = startAngle + sweep * t;
      final arcLen = radius * (angle - startAngle);
      final wave = math.sin(arcLen / wavelength * 2 * math.pi + phase);

      double r = radius + amplitude * wave;

      // Taper the wave amplitude to 0 at the end of the arc
      final taperLen = wavelength / 2;
      final arcToEnd = radius * (endAngle - angle);
      if (arcToEnd < taperLen && arcToEnd >= 0) {
        final taperFactor = math.sin((arcToEnd / taperLen) * math.pi / 2);
        r = radius + (amplitude * taperFactor) * wave;
      }

      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(_CircularRipplingWavyPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.active != active ||
        oldDelegate.track != track ||
        oldDelegate.phase != phase ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.wavelength != wavelength ||
        oldDelegate.steps != steps ||
        oldDelegate.gapWidth != gapWidth;
  }
}
