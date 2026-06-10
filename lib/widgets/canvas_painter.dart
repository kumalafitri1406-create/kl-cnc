// lib/widgets/canvas_painter.dart
import 'package:flutter/material.dart';
import '../models/grbl_state.dart';
import '../theme.dart';

class ToolPathPoint {
  final double x1, y1, x2, y2;
  final bool rapid;
  ToolPathPoint(this.x1, this.y1, this.x2, this.y2, {this.rapid = false});
}

class CanvasPainter extends CustomPainter {
  final List<ToolPathPoint> path;
  final double toolX, toolY;
  final double bedX, bedY;
  final double viewOX, viewOY, viewScale;
  final bool showGrid;

  CanvasPainter({
    required this.path,
    required this.toolX,
    required this.toolY,
    required this.bedX,
    required this.bedY,
    required this.viewOX,
    required this.viewOY,
    required this.viewScale,
    required this.showGrid,
  });

  Offset toCanvas(double mx, double my) =>
      Offset(viewOX + mx * viewScale, viewOY - my * viewScale);

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF030808));

    // Grid
    if (showGrid) {
      final step = 10 * viewScale;
      final gridPaint = Paint()
        ..color = kNeon.withOpacity(0.06)
        ..strokeWidth = 0.5;
      final ox = viewOX % step;
      final oy = viewOY % step;
      for (double x = ox; x < size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (double y = oy; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
      // Major 50mm grid
      final mstep = 50 * viewScale;
      final majorPaint = Paint()
        ..color = kNeon.withOpacity(0.12)
        ..strokeWidth = 0.8;
      final mox = viewOX % mstep;
      final moy = viewOY % mstep;
      for (double x = mox; x < size.width; x += mstep) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), majorPaint);
      }
      for (double y = moy; y < size.height; y += mstep) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), majorPaint);
      }
    }

    // Bed outline
    final bTL = toCanvas(0, bedY);
    final bBR = toCanvas(bedX, 0);
    final bedPaint = Paint()
      ..color = kNeon.withOpacity(0.25)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawRect(
        Rect.fromPoints(bTL, bBR),
        bedPaint
          ..color = kNeon.withOpacity(0.25));

    // Origin axes
    final orig = toCanvas(0, 0);
    final axisPaint = Paint()
      ..color = Colors.amber.withOpacity(0.6)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(orig.dx - 20, orig.dy),
        Offset(orig.dx + 30, orig.dy), axisPaint);
    canvas.drawLine(Offset(orig.dx, orig.dy + 20),
        Offset(orig.dx, orig.dy - 30), axisPaint);
    canvas.drawCircle(orig, 4, Paint()..color = Colors.amber);

    // Path lines
    for (final seg in path) {
      final a = toCanvas(seg.x1, seg.y1);
      final b = toCanvas(seg.x2, seg.y2);
      final p = Paint()
        ..strokeWidth = seg.rapid ? 0.8 : 1.5
        ..color = seg.rapid
            ? kNeon.withOpacity(0.5)
            : kBlue.withOpacity(0.9);
      canvas.drawLine(a, b, p);
    }

    // Tool crosshair
    final tp = toCanvas(toolX, toolY);
    final xhPaint = Paint()
      ..color = kRed.withOpacity(0.8)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(tp.dx - 14, tp.dy), Offset(tp.dx + 14, tp.dy), xhPaint);
    canvas.drawLine(Offset(tp.dx, tp.dy - 14), Offset(tp.dx, tp.dy + 14), xhPaint);
    canvas.drawCircle(tp, 4, Paint()..color = kRed);
    canvas.drawCircle(
        tp,
        9,
        Paint()
          ..color = kRed.withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(CanvasPainter old) =>
      old.toolX != toolX ||
      old.toolY != toolY ||
      old.path.length != path.length ||
      old.viewOX != viewOX ||
      old.viewOY != viewOY ||
      old.viewScale != viewScale;
}
