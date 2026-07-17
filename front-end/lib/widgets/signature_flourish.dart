import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SignatureFlourish extends StatefulWidget {
  final double width;
  const SignatureFlourish({super.key, this.width = 120});

  @override
  State<SignatureFlourish> createState() => _SignatureFlourishState();
}

class _SignatureFlourishState extends State<SignatureFlourish>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _progress = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.value = 1.0;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) => CustomPaint(
        size: Size(widget.width, 28),
        painter: _FlourishPainter(_progress.value),
      ),
    );
  }
}

class _FlourishPainter extends CustomPainter {
  final double progress;
  _FlourishPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(0, size.height * 0.6);
    path.cubicTo(
      size.width * 0.22, size.height * 0.0,
      size.width * 0.30, size.height * 1.0,
      size.width * 0.52, size.height * 0.45,
    );
    path.cubicTo(
      size.width * 0.68, size.height * 0.05,
      size.width * 0.78, size.height * 0.85,
      size.width * 1.0, size.height * 0.5,
    );

    final metrics = path.computeMetrics().first;
    final extracted = metrics.extractPath(0, metrics.length * progress);

    final paint = Paint()
      ..color = AppColors.brass
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(extracted, paint);
  }

  @override
  bool shouldRepaint(covariant _FlourishPainter oldDelegate) =>
      oldDelegate.progress != progress;
}