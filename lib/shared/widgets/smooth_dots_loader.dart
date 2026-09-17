import 'package:flutter/material.dart';

class SmoothDotsLoader extends StatefulWidget {
  const SmoothDotsLoader({super.key});

  @override
  State<SmoothDotsLoader> createState() => _SmoothDotsLoaderState();
}

class _SmoothDotsLoaderState extends State<SmoothDotsLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _dotScale(double t, double shift) {
    final x = (t + shift) % 1.0;
    final d = (x - 0.5).abs() * 2;
    final s = 1.0 - (d * d);
    return 0.6 + (s * 0.5);
  }

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF1E3A8A);

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        final t = _controller.value;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(color: color, scale: _dotScale(t, 0.00)),
            const SizedBox(width: 6),
            _Dot(color: color, scale: _dotScale(t, 0.18)),
            const SizedBox(width: 6),
            _Dot(color: color, scale: _dotScale(t, 0.36)),
          ],
        );
      },
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final double scale;

  const _Dot({required this.color, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
