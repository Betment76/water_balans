import 'dart:math';

import 'package:flutter/material.dart';

// Виджет для отображения анимированных пузырьков
class BubblesWidget extends StatefulWidget {
  final double waterHeight;
  const BubblesWidget({super.key, required this.waterHeight});

  @override
  State<BubblesWidget> createState() => _BubblesWidgetState();
}

class _BubblesWidgetState extends State<BubblesWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller; // Контроллер для управления анимацией
  late List<_Bubble> _bubbles; // Список пузырьков
  final Random _random = Random(); // Генератор случайных чисел

  @override
  void initState() {
    super.initState();
    _bubbles = [];
    _controller = AnimationController(
      duration: const Duration(seconds: 10), // Длительность анимации
      vsync: this,
    )..addListener(() {
        _updateBubbles(); // Обновление состояния пузырьков при каждом тике анимации
      });
    _controller.repeat(); // Запуск повторяющейся анимации
  }

  // Метод для обновления состояния пузырьков
  void _updateBubbles() {
    // Добавляем новый пузырек со случайными параметрами
    if (_random.nextDouble() > 0.97 && widget.waterHeight > 0) {
      _bubbles.add(
        _Bubble(
          x: _random.nextDouble(),
          y: 1.1,
          size: _random.nextDouble() * 10 + 5,
          speed: _random.nextDouble() * 0.01 + 0.005,
        ),
      );
    }

    // Обновляем положение каждого пузырька и удаляем те, что вышли за пределы экрана
    setState(() {
      for (var bubble in _bubbles) {
        bubble.y -= bubble.speed;
      }
      final renderBoxSize = context.size;
      if (renderBoxSize != null && renderBoxSize.height > 0) {
        _bubbles.removeWhere(
          (bubble) => bubble.y < (1 - widget.waterHeight / renderBoxSize.height) - 0.1,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose(); // Освобождение ресурсов контроллера
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BubblePainter(bubbles: _bubbles, waterHeight: widget.waterHeight),
      size: Size.infinite,
    );
  }
}

// Класс для хранения данных о пузырьке
class _Bubble {
  double x; // Положение по X (от 0 до 1)
  double y; // Положение по Y (от 0 до 1)
  double size; // Размер
  double speed; // Скорость

  _Bubble({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
  });
}

// Класс для отрисовки пузырьков
class _BubblePainter extends CustomPainter {
  final List<_Bubble> bubbles;
  final double waterHeight;

  _BubblePainter({required this.bubbles, required this.waterHeight});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.3); // Цвет пузырьков

    // Отрисовка каждого пузырька
    for (var bubble in bubbles) {
      final offset = Offset(bubble.x * size.width, bubble.y * size.height);
      if (offset.dy > size.height - waterHeight) { // Рисуем пузырьки только в воде
        canvas.drawCircle(offset, bubble.size, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Всегда перерисовывать для анимации
  }
}