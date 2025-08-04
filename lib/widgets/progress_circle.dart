import 'package:flutter/material.dart';

/// Круговая диаграмма прогресса воды
class ProgressCircle extends StatelessWidget {
  /// Прогресс (от 0.0 до 1.0)
  final double progress;
  /// Текущее количество воды (мл)
  final int currentML;
  /// Целевая дневная норма (мл)
  final int targetML;

  const ProgressCircle({
    Key? key,
    required this.progress,
    required this.currentML,
    required this.targetML,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 200,
          height: 200,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 12,
            backgroundColor: Colors.grey[300],
            color: Colors.blue,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${(progress * 100).round()}%', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            Text('$currentML / $targetML мл', style: const TextStyle(color: Colors.grey, fontSize: 18)),
          ],
        ),
      ],
    );
  }
} 