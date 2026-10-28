import 'package:flutter/material.dart';

class QrVisualWidget extends StatelessWidget {
  final String data;
  final double size;
  final Color color;
  final Color backgroundColor;

  const QrVisualWidget({
    super.key,
    required this.data,
    this.size = 140,
    this.color = Colors.black,
    this.backgroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.05),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
      ),
      child: CustomPaint(
        painter: _QrPainter(data: data, color: color),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  final String data;
  final Color color;

  _QrPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const int gridSize = 21; // standard QR version 1 grid
    final cellSize = size.width / gridSize;

    // Deterministic pseudo-random seed based on data string
    int hash = 0;
    for (int i = 0; i < data.length; i++) {
      hash = (hash * 31 + data.codeUnitAt(i)) & 0xFFFFFFFF;
    }

    // Helper to draw a square cell
    void drawCell(int r, int c) {
      canvas.drawRect(
        Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize),
        paint,
      );
    }

    // Helper to draw QR corner finder pattern (7x7)
    void drawFinderPattern(int startR, int startC) {
      for (int r = 0; r < 7; r++) {
        for (int c = 0; c < 7; c++) {
          if (r == 0 || r == 6 || c == 0 || c == 6) {
            drawCell(startR + r, startC + c);
          } else if (r >= 2 && r <= 4 && c >= 2 && c <= 4) {
            drawCell(startR + r, startC + c);
          }
        }
      }
    }

    // 1. Draw 3 main corner finder patterns
    drawFinderPattern(0, 0); // Top-Left
    drawFinderPattern(0, gridSize - 7); // Top-Right
    drawFinderPattern(gridSize - 7, 0); // Bottom-Left

    // 2. Timing patterns
    for (int i = 8; i < gridSize - 8; i += 2) {
      drawCell(6, i);
      drawCell(i, 6);
    }

    // 3. Fill inner matrix deterministically from hash
    var currentHash = hash;
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        // Skip finder pattern zones
        final inTopLeft = r < 8 && c < 8;
        final inTopRight = r < 8 && c >= gridSize - 8;
        final inBottomLeft = r >= gridSize - 8 && c < 8;
        final onTiming = (r == 6 && (c >= 8 && c < gridSize - 8)) ||
            (c == 6 && (r >= 8 && r < gridSize - 8));

        if (inTopLeft || inTopRight || inBottomLeft || onTiming) {
          continue;
        }

        // Pseudo-random bit based on position and hash
        final bit = ((currentHash ^ (r * 37 + c * 17)) % 7) < 3;
        if (bit) {
          drawCell(r, c);
        }
        currentHash = (currentHash * 1103515245 + 12345) & 0x7FFFFFFF;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.color != color;
}
