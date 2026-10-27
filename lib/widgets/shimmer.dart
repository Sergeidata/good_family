import 'package:flutter/material.dart';

/// Анимированный «переливающийся» прямоугольник-плейсхолдер.
class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color baseColor;
  final Color highlightColor;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
    this.baseColor = const Color(0xFFE0E0E0),
    this.highlightColor = const Color(0xFFF0F0F0),
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + _controller.value * 2.0, 0),
              end: Alignment(1.0 - _controller.value * 2.0, 0),
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}

/// Карточка-скелетон: набор серых блоков, повторяющих контур карточки контента.
class ShimmerCard extends StatelessWidget {
  final double height;
  final double borderRadius;

  const ShimmerCard({
    super.key,
    this.height = 220,
    this.borderRadius = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const ShimmerBox(width: 54, height: 54, borderRadius: 12),
          const SizedBox(height: 16),
          const ShimmerBox(width: double.infinity, height: 18, borderRadius: 8),
          const SizedBox(height: 10),
          const ShimmerBox(width: 160, height: 18, borderRadius: 8),
          const SizedBox(height: 14),
          const ShimmerBox(width: 100, height: 12, borderRadius: 6),
        ],
      ),
    );
  }
}

/// Карточка-скелетон достижения: иконка + заголовок + бейдж редкости + блок текста.
class ShimmerAchievementCard extends StatelessWidget {
  final double borderRadius;

  const ShimmerAchievementCard({
    super.key,
    this.borderRadius = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBox(width: 54, height: 54, borderRadius: 12),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Заголовок
                const ShimmerBox(width: 180, height: 18, borderRadius: 8),
                const SizedBox(height: 12),
                // Бейдж редкости
                const ShimmerBox(width: 84, height: 22, borderRadius: 11),
                const SizedBox(height: 12),
                // Блок текста
                const ShimmerBox(width: double.infinity, height: 12, borderRadius: 6),
                const SizedBox(height: 8),
                const ShimmerBox(width: double.infinity, height: 12, borderRadius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Список из 4 карточек-скелетонов достижений с padding 16.
class ShimmerAchievementList extends StatelessWidget {
  final int count;

  const ShimmerAchievementList({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      child: Column(
        children: List.generate(
          count,
          (_) => const ShimmerAchievementCard(),
        ),
      ),
    );
  }
}

/// Карточка-скелетон награды: иконка 72×72 + название + описание + цена.
class ShimmerRewardCard extends StatelessWidget {
  const ShimmerRewardCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBox(width: 72, height: 72, borderRadius: 14),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Название
                const ShimmerBox(width: 170, height: 18, borderRadius: 8),
                const SizedBox(height: 10),
                // Описание
                const ShimmerBox(width: double.infinity, height: 12, borderRadius: 6),
                const SizedBox(height: 6),
                const ShimmerBox(width: 220, height: 12, borderRadius: 6),
                const SizedBox(height: 12),
                // Строка с ценой
                const ShimmerBox(width: 92, height: 22, borderRadius: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Список из 4 карточек-скелетонов наград.
class ShimmerRewardList extends StatelessWidget {
  final int count;

  const ShimmerRewardList({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      child: Column(
        children: List.generate(
          count,
          (_) => const ShimmerRewardCard(),
        ),
      ),
    );
  }
}

/// Карточка-скелетон задания: цветная полоска + название + исполнитель/повтор/награда.
class ShimmerTaskCard extends StatelessWidget {
  const ShimmerTaskCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Цветная полоска слева
            const ShimmerBox(width: 6, height: double.infinity, borderRadius: 0),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Название
                    const ShimmerBox(width: 190, height: 18, borderRadius: 8),
                    const SizedBox(height: 12),
                    // Исполнитель
                    const ShimmerBox(width: 140, height: 12, borderRadius: 6),
                    const SizedBox(height: 8),
                    // Повтор
                    const ShimmerBox(width: 120, height: 12, borderRadius: 6),
                    const SizedBox(height: 8),
                    // Награда
                    const ShimmerBox(width: 96, height: 12, borderRadius: 6),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Список из 4 карточек-скелетонов заданий.
class ShimmerTaskList extends StatelessWidget {
  final int count;

  const ShimmerTaskList({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      child: Column(
        children: List.generate(
          count,
          (_) => const ShimmerTaskCard(),
        ),
      ),
    );
  }
}

/// Строка-скелетон рейтинга: аватар 48×48 + имя + время.
class ShimmerRankRow extends StatelessWidget {
  const ShimmerRankRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const ShimmerBox(width: 48, height: 48, borderRadius: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Имя
                const ShimmerBox(width: 150, height: 16, borderRadius: 8),
                const SizedBox(height: 8),
                // Время
                const ShimmerBox(width: 90, height: 12, borderRadius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Список из 5 строк-скелетонов рейтинга.
class ShimmerRankList extends StatelessWidget {
  final int count;

  const ShimmerRankList({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      child: Column(
        children: List.generate(
          count,
          (_) => const ShimmerRankRow(),
        ),
      ),
    );
  }
}
