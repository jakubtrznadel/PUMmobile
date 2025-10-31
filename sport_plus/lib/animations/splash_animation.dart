import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashAnimation extends StatefulWidget {
  final VoidCallback onAnimationComplete;

  const SplashAnimation({super.key, required this.onAnimationComplete});

  @override
  _SplashAnimationState createState() => _SplashAnimationState();
}

class _SplashAnimationState extends State<SplashAnimation> with SingleTickerProviderStateMixin {
  double lineProgress = 0.0;
  double slideOffset = 0.0;
  double sportOffset = 1.0;
  late AnimationController _controller;
  late Animation<double> _lineAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _sportAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _lineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.3, curve: Curves.easeInOut)),
    );

    _slideAnimation = Tween<double>(begin: 0.0, end: -1.2).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 0.6, curve: Curves.easeOut)),
    );

    _sportAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 0.7, curve: Curves.easeOutBack)),
    );

    _controller.addListener(() {
      setState(() {
        lineProgress = _lineAnimation.value;
        if (_controller.value > 0.3) slideOffset = _slideAnimation.value;
        if (_controller.value > 0.4) sportOffset = _sportAnimation.value;
      });
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      _controller.forward();
    });

    Future.delayed(const Duration(milliseconds: 2000), () {
      widget.onAnimationComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.translate(
              offset: Offset(slideOffset * MediaQuery.of(context).size.width, 0),
              child: Stack(
                children: [
                  Text(
                    'Comfort mode',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 60,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFffc300),
                      shadows: const [Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 4)],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  CustomPaint(
                    painter: CrossLinePainter(progress: lineProgress),
                    size: const Size(300, 70),
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: Offset(0, sportOffset * MediaQuery.of(context).size.height),
              child: Opacity(
                opacity: _controller.value > 0.4 ? 1.0 : 0.0,
                child: Text(
                  'Sport+ mode',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 60,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFffc300),
                    shadows: const [Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 4)],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CrossLinePainter extends CustomPainter {
  final double progress;

  CrossLinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF5722)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final startPoint = Offset(0, size.height / 2);
    final endPoint = Offset(size.width * progress, size.height / 2);
    canvas.drawLine(startPoint, endPoint, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}