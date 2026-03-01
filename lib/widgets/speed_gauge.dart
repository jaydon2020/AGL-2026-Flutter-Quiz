import 'dart:math';
import 'package:flutter/material.dart';

class SpeedGauge extends StatelessWidget {
  final double speed;
  final double maxSpeed;

  const SpeedGauge({super.key, required this.speed, this.maxSpeed = 220.0});

  @override
  Widget build(BuildContext context) {
    Color gaugeColor = speed > 150
        ? Colors.red.shade500
        : const Color(0xFF3B82F6);

    return SizedBox(
      width: 256,
      height: 256,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Glow
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color.fromRGBO(
                  30,
                  58,
                  138,
                  0.4,
                ), // border-blue-900/40
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromRGBO(
                    30,
                    58,
                    138,
                    0.4,
                  ), // blue-900/40 glow
                  blurRadius: 50,
                  spreadRadius: 0,
                ),
              ],
            ),
          ),

          // Outer Pulse Ring (Simulated)
          Container(
            width: 256,
            height: 256,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color.fromRGBO(59, 130, 246, 0.1), // blue-500/10
                width: 1,
              ),
            ),
          ),

          // The SVG-like Gauge using CustomPaint
          CustomPaint(
            size: const Size(200, 200),
            painter: SpeedGaugePainter(
              speed: speed,
              maxSpeed: maxSpeed,
              gaugeColor: gaugeColor,
            ),
          ),

          // Center Text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                speed.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                  color: gaugeColor == Colors.red.shade500
                      ? Colors.red.shade500
                      : Colors.white,
                  shadows: [
                    Shadow(
                      color: gaugeColor.withValues(alpha: 0.8),
                      blurRadius: 10,
                    ),
                  ],
                  // font display would go here
                  fontFamily: 'Orbitron',
                ),
              ),
              const Text(
                'KPH',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF60A5FA), // text-blue-400
                  letterSpacing: 2.0, // tracking-widest
                  // font display would go here
                  fontFamily: 'Orbitron',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SpeedGaugePainter extends CustomPainter {
  final double speed;
  final double maxSpeed;
  final Color gaugeColor;

  SpeedGaugePainter({
    required this.speed,
    required this.maxSpeed,
    required this.gaugeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background track (dark slate)
    final bgPaint = Paint()
      ..color =
          const Color(0xFF1E293B) // stroke="#1e293b"
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12.0;

    canvas.drawCircle(center, radius, bgPaint);

    // Foreground track (speed dependent color)
    final fgPaint = Paint()
      ..color = gaugeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12.0
      ..strokeCap = StrokeCap.round;

    // HTML SVG used stroke-dasharray and dashoffset
    // We'll use drawArc. Start mapping SVG transform rotate(-90deg)
    const startAngle = -pi / 2;
    // Calculate sweep angle based on speed percentage
    final percentage = (speed.clamp(0.0, maxSpeed)) / maxSpeed;
    final sweepAngle = 2 * pi * percentage;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false, // useCenter
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant SpeedGaugePainter oldDelegate) {
    return oldDelegate.speed != speed || oldDelegate.gaugeColor != gaugeColor;
  }
}
