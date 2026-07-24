import 'package:flutter/material.dart';

class MainBottomBar extends StatelessWidget {
  final int? currentIndex;
  final ValueChanged<int> onTap;

  const MainBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [

              _item(
                index: 0,
                icon: Icons.home_rounded,
                label: "Главная",
              ),

              _item(
                index: 1,
                icon: Icons.groups_rounded,
                label: "Рейтинг",
              ),

              _item(
                index: 2,
                icon: Icons.emoji_events_rounded,
                label: "Награды",
              ),

              _item(
                index: 3,
                icon: Icons.family_restroom_rounded,
                label: "Семья",
              ),

              _item(
                index: 4,
                icon: Icons.more_horiz_rounded,
                label: "Ещё",
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected = currentIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.blue.shade50
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: selected
                      ? Colors.blue
                      : Colors.grey,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: selected
                      ? Colors.blue
                      : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}