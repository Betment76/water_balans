import 'package:flutter/material.dart';

/// Плавающая кнопка быстрого добавления воды
class QuickAddButton extends StatelessWidget {
  final VoidCallback onPressed;

  const QuickAddButton({Key? key, required this.onPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      child: const Icon(Icons.add, size: 32),
      backgroundColor: Colors.blue,
      tooltip: 'Добавить воду',
    );
  }
} 