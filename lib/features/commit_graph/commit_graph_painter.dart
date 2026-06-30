import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../git_engine/git_models.dart';
import 'graph_layout.dart';

class CommitGraphPainter extends CustomPainter {
  final List<GraphCommit> commits;
  final double rowHeight;

  CommitGraphPainter({required this.commits, this.rowHeight = 24.0});

  @override
  void paint(Canvas canvas, Size size) {
    final laneSpacing = 14.0;
    final dotRadius = 4.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..isAntiAlias = true;

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Draw connection lines
    for (var i = 0; i < commits.length; i++) {
      final gc = commits[i];
      final yCenter = (i * rowHeight) + (rowHeight / 2);

      for (final conn in gc.connections) {
        final color = FurcateTheme.laneColors[conn.colorIndex];
        paint.color = color;

        final fromX = (conn.fromLane * laneSpacing) + 14.0;
        final toX = (conn.toLane * laneSpacing) + 14.0;

        if (conn.type == ConnectionType.straight) {
          // Vertical straight line passing through this row
          final startY = i * rowHeight;
          final endY = (i + 1) * rowHeight;
          canvas.drawLine(Offset(fromX, startY), Offset(fromX, endY), paint);
        } else if (conn.type == ConnectionType.mergeLeft || conn.type == ConnectionType.mergeRight) {
          // Curved line for merge (coming from another lane into our lane)
          final startY = i * rowHeight;

          final path = Path()
            ..moveTo(fromX, startY)
            ..cubicTo(
              fromX,
              startY + (rowHeight / 4),
              toX,
              yCenter - (rowHeight / 4),
              toX,
              yCenter,
            );

          canvas.drawPath(path, paint);
        } else if (conn.type == ConnectionType.branchLeft || conn.type == ConnectionType.branchRight) {
          // Curved line for branch (branching out from our lane)
          final startY = yCenter;
          final endY = (i + 1) * rowHeight;

          final path = Path()
            ..moveTo(fromX, startY)
            ..cubicTo(
              fromX,
              startY + (rowHeight / 4),
              toX,
              endY - (rowHeight / 4),
              toX,
              endY,
            );

          canvas.drawPath(path, paint);
        }
      }
    }

    // Draw commit dots on top of the lines
    for (var i = 0; i < commits.length; i++) {
      final gc = commits[i];
      final xCenter = (gc.laneIndex * laneSpacing) + 14.0;
      final yCenter = (i * rowHeight) + (rowHeight / 2);
      final color = FurcateTheme.laneColors[gc.colorIndex];

      // Draw active commit dot
      dotPaint.color = color;
      canvas.drawCircle(Offset(xCenter, yCenter), dotRadius, dotPaint);

      // If HEAD, draw an outer ring
      if (gc.commit.isHead) {
        paint.color = FurcateTheme.darkTextEmphasis;
        paint.strokeWidth = 1.5;
        canvas.drawCircle(Offset(xCenter, yCenter), dotRadius + 2.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CommitGraphPainter oldDelegate) {
    return oldDelegate.commits != commits || oldDelegate.rowHeight != rowHeight;
  }
}
