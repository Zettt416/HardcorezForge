import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SignaturePoint {
  final Offset offset;
  final Color color;
  final double strokeWidth;

  SignaturePoint({
    required this.offset,
    required this.color,
    required this.strokeWidth,
  });

  Map<String, dynamic> toMap() => {
    'dx': offset.dx,
    'dy': offset.dy,
    'color': color.toARGB32(),
    'strokeWidth': strokeWidth,
  };

  factory SignaturePoint.fromMap(Map<String, dynamic> map) => SignaturePoint(
    offset: Offset(
      (map['dx'] as num).toDouble(),
      (map['dy'] as num).toDouble(),
    ),
    color: Color(map['color'] as int),
    strokeWidth: (map['strokeWidth'] as num).toDouble(),
  );
}

class SignatureScreen extends StatefulWidget {
  final Function(List<List<SignaturePoint>> strokes, String? stampText)?
  onSignatureSaved;

  const SignatureScreen({super.key, this.onSignatureSaved});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  final List<List<SignaturePoint>> _strokes = [];
  List<SignaturePoint>? _currentStroke;

  Color _selectedColor = const Color(0xFF0F172A); // Default dark ink
  double _strokeWidth = 3.5;
  String? _selectedStamp;

  final List<Color> _availableColors = [
    const Color(0xFF0F172A), // Hitam tinta
    const Color(0xFF1E40AF), // Biru dokumen resmi
    const Color(0xFFDC2626), // Merah paraf
  ];

  final List<String> _availableStamps = [
    'APPROVED',
    'LUNAS',
    'CONFIDENTIAL',
    'DRAFT',
    'VERIFIED',
  ];

  void _undo() {
    if (_strokes.isNotEmpty) {
      setState(() => _strokes.removeLast());
    }
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _selectedStamp = null;
    });
  }

  void _saveSignature() {
    if (_strokes.isEmpty && _selectedStamp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Silakan buat tanda tangan atau pilih stempel terlebih dahulu',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Deep-copy strokes to avoid referencing state lists
    final savedStrokes = _strokes
        .map(
          (stroke) => stroke
              .map(
                (p) => SignaturePoint(
                  offset: p.offset,
                  color: p.color,
                  strokeWidth: p.strokeWidth,
                ),
              )
              .toList(),
        )
        .toList();

    widget.onSignatureSaved?.call(savedStrokes, _selectedStamp);
    Navigator.pop(context, {'strokes': savedStrokes, 'stamp': _selectedStamp});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tanda Tangan & Stempel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo_rounded),
            tooltip: 'Batalkan Coretan',
            onPressed: _strokes.isEmpty ? null : _undo,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Hapus Semua',
            onPressed: _strokes.isEmpty && _selectedStamp == null
                ? null
                : _clear,
          ),
          IconButton(
            icon: const Icon(Icons.check_rounded, color: AppTheme.accentBlue),
            tooltip: 'Simpan Tanda Tangan',
            onPressed: _saveSignature,
          ),
        ],
      ),
      body: Column(
        children: [
          // Guidance banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? AppTheme.darkSurface : const Color(0xFFEFF6FF),
            child: Row(
              children: [
                const Icon(
                  Icons.draw_rounded,
                  size: 20,
                  color: AppTheme.accentBlue,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Goreskan tanda tangan dengan jari atau stylus di kanvas di bawah.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main Interactive Signature Canvas
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      // Watermark baseline guidance line
                      Positioned(
                        bottom: 60,
                        left: 40,
                        right: 40,
                        child: Row(
                          children: [
                            const Text(
                              'X',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black26,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                height: 1.5,
                                color: Colors.black12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Optional Stamped Watermark
                      if (_selectedStamp != null)
                        Center(
                          child: Transform.rotate(
                            angle: -0.25,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.7),
                                  width: 3,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _selectedStamp!,
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3,
                                  color: Colors.red.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Touch / Stylus Drawing Area
                      GestureDetector(
                        onPanStart: (details) {
                          setState(() {
                            _currentStroke = [
                              SignaturePoint(
                                offset: details.localPosition,
                                color: _selectedColor,
                                strokeWidth: _strokeWidth,
                              ),
                            ];
                            _strokes.add(_currentStroke!);
                          });
                        },
                        onPanUpdate: (details) {
                          setState(() {
                            _currentStroke?.add(
                              SignaturePoint(
                                offset: details.localPosition,
                                color: _selectedColor,
                                strokeWidth: _strokeWidth,
                              ),
                            );
                          });
                        },
                        onPanEnd: (_) {
                          _currentStroke = null;
                        },
                        child: CustomPaint(
                          painter: SignaturePainter(strokes: _strokes),
                          size: Size.infinite,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom Toolbar: Pen Color, Stroke Width, and Quick Stamp Chips
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ink Colors & Stroke Width
                  Row(
                    children: [
                      const Text(
                        'Tinta:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      for (final color in _availableColors)
                        GestureDetector(
                          onTap: () => setState(() => _selectedColor = color),
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _selectedColor == color
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: [
                                if (_selectedColor == color)
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(width: 10),
                      const Text('Tebal:', style: TextStyle(fontSize: 13)),
                      Expanded(
                        child: Slider(
                          value: _strokeWidth,
                          min: 1.5,
                          max: 8.0,
                          activeColor: AppTheme.accentBlue,
                          onChanged: (val) =>
                              setState(() => _strokeWidth = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Stamp Selection
                  Row(
                    children: [
                      const Text(
                        'Stempel:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final stamp in _availableStamps)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Text(
                                      stamp,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    selected: _selectedStamp == stamp,
                                    selectedColor: Colors.red.shade100,
                                    labelStyle: TextStyle(
                                      color: _selectedStamp == stamp
                                          ? Colors.red.shade900
                                          : null,
                                      fontWeight: _selectedStamp == stamp
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    onSelected: (selected) {
                                      setState(() {
                                        _selectedStamp = selected
                                            ? stamp
                                            : null;
                                      });
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SignaturePainter extends CustomPainter {
  final List<List<SignaturePoint>> strokes;
  final bool autoFit;
  final String? stampText;

  SignaturePainter({
    required this.strokes,
    this.autoFit = false,
    this.stampText,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw stamp watermark if provided
    if (stampText != null && stampText!.isNotEmpty) {
      _drawStamp(canvas, size, stampText!);
    }

    if (strokes.isEmpty) return;

    // 2. Compute bounding box
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;

    for (final stroke in strokes) {
      for (final pt in stroke) {
        if (pt.offset.dx < minX) minX = pt.offset.dx;
        if (pt.offset.dx > maxX) maxX = pt.offset.dx;
        if (pt.offset.dy < minY) minY = pt.offset.dy;
        if (pt.offset.dy > maxY) maxY = pt.offset.dy;
      }
    }

    if (minX == double.infinity) return;

    double boundW = maxX - minX;
    double boundH = maxY - minY;
    if (boundW < 1.0) boundW = 1.0;
    if (boundH < 1.0) boundH = 1.0;

    double scale = 1.0;
    double offsetX = 0.0;
    double offsetY = 0.0;

    if (autoFit && size.width > 0 && size.height > 0) {
      const padding = 8.0;
      final availW = math.max(10.0, size.width - padding * 2);
      final availH = math.max(10.0, size.height - padding * 2);

      final scaleX = availW / boundW;
      final scaleY = availH / boundH;
      scale = math.min(scaleX, scaleY);

      offsetX = (size.width - (boundW * scale)) / 2 - (minX * scale);
      offsetY = (size.height - (boundH * scale)) / 2 - (minY * scale);
    }

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;

      final strokeColor = stroke.first.color;
      final strokeW = math.max(
        1.5,
        stroke.first.strokeWidth * (autoFit ? math.min(scale, 1.2) : 1.0),
      );

      final paint = Paint()
        ..color = strokeColor
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.length == 1) {
        final p = stroke.first;
        final dx = autoFit ? (p.offset.dx * scale + offsetX) : p.offset.dx;
        final dy = autoFit ? (p.offset.dy * scale + offsetY) : p.offset.dy;
        canvas.drawCircle(
          Offset(dx, dy),
          strokeW / 2,
          paint..style = PaintingStyle.fill,
        );
        continue;
      }

      final path = Path();
      final p0 = stroke.first;
      final startX = autoFit ? (p0.offset.dx * scale + offsetX) : p0.offset.dx;
      final startY = autoFit ? (p0.offset.dy * scale + offsetY) : p0.offset.dy;
      path.moveTo(startX, startY);

      for (int i = 1; i < stroke.length; i++) {
        final prev = stroke[i - 1];
        final curr = stroke[i];

        final prevX = autoFit
            ? (prev.offset.dx * scale + offsetX)
            : prev.offset.dx;
        final prevY = autoFit
            ? (prev.offset.dy * scale + offsetY)
            : prev.offset.dy;

        final currX = autoFit
            ? (curr.offset.dx * scale + offsetX)
            : curr.offset.dx;
        final currY = autoFit
            ? (curr.offset.dy * scale + offsetY)
            : curr.offset.dy;

        final midX = (prevX + currX) / 2;
        final midY = (prevY + currY) / 2;
        path.quadraticBezierTo(prevX, prevY, midX, midY);
      }

      canvas.drawPath(path, paint);
    }
  }

  void _drawStamp(Canvas canvas, Size size, String text) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-0.15);

    final stampPaint = Paint()
      ..color = const Color(0xFFDC2626).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final rectWidth = math.min(size.width * 0.85, 130.0);
    const rectHeight = 28.0;
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: rectWidth,
      height: rectHeight,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      stampPaint,
    );

    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: const Color(0xFFDC2626).withValues(alpha: 0.9),
        fontWeight: FontWeight.w900,
        fontSize: math.max(9.0, rectWidth / 10),
        letterSpacing: 2.0,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SignaturePainter oldDelegate) => true;
}
