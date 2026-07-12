import 'dart:math';
import 'package:flutter/material.dart';

class TopoBackground extends StatefulWidget {
  final Color color;
  final double speed;

  const TopoBackground({Key? key, required this.color, this.speed = 1.0})
    : super(key: key);

  @override
  _TopoBackgroundState createState() => _TopoBackgroundState();
}

class _TopoBackgroundState extends State<TopoBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: TopoPainter(
                  animationValue: _controller.value,
                  color: widget.color,
                  speed: widget.speed,
                ),
                size: Size(constraints.maxWidth, constraints.maxHeight),
              );
            },
          ),
        );
      },
    );
  }
}

class TopoPainter extends CustomPainter {
  final double animationValue;
  final Color color;
  final double speed;

  static const double resolution = 12.0;

  TopoPainter({
    required this.animationValue,
    required this.color,
    required this.speed,
  });

  double _getElevation(double x, double y, double t) {
    const double scaleX = 0.012;
    const double scaleY = 0.012;

    double v = sin(x * scaleX + t) + cos(y * scaleY + t * 0.8);
    v += 0.5 * sin((x * 0.03) - (y * 0.03) + t * 2.0);
    v += 0.2 * cos((x * 0.05) + (y * 0.01));

    return v;
  }

  Offset _lerp(Offset a, Offset b, double valA, double valB, double threshold) {
    if ((valB - valA).abs() < 0.0001) return a;
    double t = (threshold - valA) / (valB - valA);
    return Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final double t = animationValue * 2 * pi * speed;

    final List<double> thresholds = [];
    for (double i = -3.0; i <= 3.0; i += 0.25) {
      thresholds.add(i);
    }

    int cols = (size.width / resolution).ceil() + 1;
    int rows = (size.height / resolution).ceil() + 1;

    List<double> currentRow = List.filled(cols, 0.0);
    List<double> nextRow = List.filled(cols, 0.0);

    for (int i = 0; i < cols; i++) {
      currentRow[i] = _getElevation(i * resolution, 0, t);
    }

    for (int j = 0; j < rows - 1; j++) {
      double y = j * resolution;
      double nextY = (j + 1) * resolution;

      for (int i = 0; i < cols; i++) {
        nextRow[i] = _getElevation(i * resolution, nextY, t);
      }

      for (int i = 0; i < cols - 1; i++) {
        double x = i * resolution;
        double nextX = (i + 1) * resolution;

        double valTL = currentRow[i];
        double valTR = currentRow[i + 1];
        double valBL = nextRow[i];
        double valBR = nextRow[i + 1];

        for (double threshold in thresholds) {
          int state = 0;
          if (valTL > threshold) state |= 8;
          if (valTR > threshold) state |= 4;
          if (valBR > threshold) state |= 2;
          if (valBL > threshold) state |= 1;

          if (state == 0 || state == 15) continue;

          Offset tl = Offset(x, y);
          Offset tr = Offset(nextX, y);
          Offset br = Offset(nextX, nextY);
          Offset bl = Offset(x, nextY);

          Offset a = _lerp(tl, tr, valTL, valTR, threshold);
          Offset b = _lerp(tr, br, valTR, valBR, threshold);
          Offset c = _lerp(bl, br, valBL, valBR, threshold);
          Offset d = _lerp(tl, bl, valTL, valBL, threshold);

          switch (state) {
            case 1:
              canvas.drawLine(d, c, paint);
              break;
            case 2:
              canvas.drawLine(c, b, paint);
              break;
            case 3:
              canvas.drawLine(d, b, paint);
              break;
            case 4:
              canvas.drawLine(a, b, paint);
              break;
            case 5:
              canvas.drawLine(d, a, paint);
              canvas.drawLine(c, b, paint);
              break;
            case 6:
              canvas.drawLine(a, c, paint);
              break;
            case 7:
              canvas.drawLine(d, a, paint);
              break;
            case 8:
              canvas.drawLine(d, a, paint);
              break;
            case 9:
              canvas.drawLine(a, c, paint);
              break;
            case 10:
              canvas.drawLine(a, b, paint);
              canvas.drawLine(d, c, paint);
              break;
            case 11:
              canvas.drawLine(a, b, paint);
              break;
            case 12:
              canvas.drawLine(d, b, paint);
              break;
            case 13:
              canvas.drawLine(c, b, paint);
              break;
            case 14:
              canvas.drawLine(d, c, paint);
              break;
          }
        }
      }
      List<double> temp = currentRow;
      currentRow = nextRow;
      nextRow = temp;
    }
  }

  @override
  bool shouldRepaint(covariant TopoPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.color != color;
  }
}
