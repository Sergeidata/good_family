import 'package:flutter/material.dart';

/// Анимация загрузки: три по очереди подпрыгивающие точки.
///
/// Один [AnimationController] на весь цикл (1200 мс); каждая точка
/// управляется своим [Interval] со сдвигом старта 0 / 150 / 300 мс
/// и длительностью прыжка 400 мс.
class LoadingDots extends StatefulWidget {
  /// Если задан — все точки рисуются этим цветом (например, белым на кнопке).
  final Color? color;

  const LoadingDots({super.key, this.color});

  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with SingleTickerProviderStateMixin {
  /// Диаметр точки.
  static const double _dotSize = 14;

  /// Расстояние между точками.
  static const double _gap = 10;

  /// Высота подпрыгивания.
  static const double _jump = 10;

  /// Полный цикл анимации.
  static const Duration _cycle = Duration(milliseconds: 1200);

  /// Окна прыжка: 0–400, 150–550, 300–700 мс (в долях цикла 1200 мс).
  static const List<Interval> _intervals = [
    Interval(0 / 1200, 400 / 1200),
    Interval(150 / 1200, 550 / 1200),
    Interval(300 / 1200, 700 / 1200),
  ];

  /// Цвета точек: синий, вишнёвый, синий.
  static const List<Color> _colors = [
    Color(0xFF2196F3),
    Color(0xFFB71C1C),
    Color(0xFF2196F3),
  ];

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _cycle,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 30,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: _gap),
              _buildDot(i),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    // 0 -> -10px -> 0 (прыжок вверх и обратно) внутри окна точки.
    final jump = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -_jump)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -_jump, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(
      CurvedAnimation(parent: _controller, curve: _intervals[index]),
    );

    return AnimatedBuilder(
      animation: jump,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, jump.value),
          child: child,
        );
      },
      child: Container(
        width: _dotSize,
        height: _dotSize,
        decoration: BoxDecoration(
          color: widget.color ?? _colors[index],
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
