import 'package:flutter/material.dart';

class EmojiPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  final bool expanded;

  const EmojiPicker({
    super.key,
    required this.selected,
    required this.onSelected,
    this.expanded = false,
  });

  static const List<String> emojis = [
    "🍕","🍔","🍟","🌭","🍗","🍿","🍩","🍪","🍫","🍦",
    "🎮","🕹","🎲","⚽","🏀","🏆","🚲","🛴",
    "💰","💵","💳","🎁","⭐","💎",
    "🎬","📺","🎵","🎧","🎤",
    "🛏️","📚","🧸","🚿","🪥","🧹","🍽️",
    "🐶","🐱","🐰","🐹","🐴",
    "❤️","🌳","🌸","☀️","🎈","🚀"
  ];

  @override
  Widget build(BuildContext context) {
    final visible = expanded ? emojis : emojis.take(12).toList();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: visible.map((emoji) {
        final isSelected = emoji == selected;

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onSelected(emoji),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.transparent,
                width: 2,
              ),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
          ),
        );
      }).toList(),
    );
  }
}