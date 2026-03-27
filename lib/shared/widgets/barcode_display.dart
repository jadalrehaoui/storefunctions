import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart';

class BarcodeDisplay extends StatelessWidget {
  final String data;
  final double width;
  final double height;

  const BarcodeDisplay({
    required this.data,
    this.width = 180,
    this.height = 72,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            painter: _BarcodePainter(data: data),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          data,
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.5,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

class _BarcodePainter extends CustomPainter {
  final String data;

  _BarcodePainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    // Reserve bottom 14px for the number text
    const textHeight = 14.0;
    final barcodeHeight = size.height - textHeight;

    Iterable<BarcodeElement> elements;
    try {
      elements = Barcode.ean13().make(
        data,
        width: size.width,
        height: barcodeHeight,
      );
    } catch (_) {
      elements = Barcode.code128().make(
        data,
        width: size.width,
        height: barcodeHeight,
      );
    }

    final barPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    for (final el in elements) {
      if (el is BarcodeBar && el.black) {
        canvas.drawRect(
          Rect.fromLTWH(el.left, el.top, el.width, el.height),
          barPaint,
        );
      } else if (el is BarcodeText) {
        final tp = TextPainter(
          text: TextSpan(
            text: el.text,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: el.width);

        final dx = switch (el.align) {
          BarcodeTextAlign.left => el.left,
          BarcodeTextAlign.center => el.left + (el.width - tp.width) / 2,
          BarcodeTextAlign.right => el.left + el.width - tp.width,
        };

        tp.paint(canvas, Offset(dx, barcodeHeight + 2));
      }
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter old) => old.data != data;
}
