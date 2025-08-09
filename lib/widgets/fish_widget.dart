import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Виджет для отображения анимированной рыбки, плавающей в аквариуме.
/// Рыбка случайным образом перемещается по доступному пространству.
class FishWidget extends StatefulWidget {
  final double progress;
  final bool isSwimming;
  final double waterHeight;
  final double fishSize;
  final double aquariumSize;

  const FishWidget({
    super.key,
    required this.progress,
    required this.isSwimming,
    required this.waterHeight,
    required this.fishSize,
    required this.aquariumSize,
  });

  @override
  State<FishWidget> createState() => _FishWidgetState();
}

class _FishWidgetState extends State<FishWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;
  Timer? _timer;

  Offset _currentPosition = Offset.zero;
  Offset _nextPosition = Offset.zero;
  bool _isFacingRight = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 8), // Замедляем анимацию для более плавного движения
      vsync: this,
    );

    _animation = Tween<Offset>(begin: _currentPosition, end: _nextPosition).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Запускаем таймер для смены позиции
    _startTimer();

    if (widget.isSwimming) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant FishWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSwimming != oldWidget.isSwimming) {
      if (widget.isSwimming) {
        _startTimer();
        _moveFish();
      } else {
        _timer?.cancel();
        _controller.stop();
      }
    }
  }

  /// Запускает таймер, который периодически инициирует движение рыбки.
  void _startTimer() {
    _timer?.cancel(); // Отменяем предыдущий таймер, если он был
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && widget.isSwimming) {
        _moveFish();
      }
    });
  }

  /// Вычисляет новую случайную позицию и запускает анимацию.
  void _moveFish() {
    if (!mounted) return;

    _currentPosition = _animation.value;
    _nextPosition = _getRandomPosition();

    // Определяем направление движения
    if ((_nextPosition.dx > _currentPosition.dx && !_isFacingRight) ||
        (_nextPosition.dx < _currentPosition.dx && _isFacingRight)) {
      setState(() {
        _isFacingRight = !_isFacingRight;
      });
    }

    _animation = Tween<Offset>(begin: _currentPosition, end: _nextPosition).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward(from: 0.0);
  }

  /// Генерирует случайную позицию в пределах аквариума.
  Offset _getRandomPosition() {
    final random = math.Random();
    final horizontalRange = (widget.aquariumSize / 2) - (widget.fishSize / 2);

    // Корректно рассчитываем доступное вертикальное пространство для движения рыбы.
    // Оно не должно быть отрицательным.
    final availableVerticalSpace = (widget.waterHeight - widget.fishSize).clamp(0.0, double.infinity);

    // Рыба уже центрирована по вертикали родительским виджетом Positioned.
    // Мы рассчитываем случайное смещение от этой центральной точки.
    final verticalOffset = availableVerticalSpace / 2;

    final dx = random.nextDouble() * horizontalRange * (random.nextBool() ? 1 : -1);
    // Генерируем случайное значение dy в пределах допустимого вертикального смещения.
    final dy = random.nextDouble() * verticalOffset * (random.nextBool() ? 1 : -1);

    return Offset(dx, dy);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const String fishAsset = 'assets/images/fish/fish2.gif';

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: _animation.value,
          child: Transform(
            alignment: Alignment.center,
            transform: _isFacingRight ? Matrix4.identity() : Matrix4.rotationY(math.pi),
            child: Image.asset(
              fishAsset,
              width: widget.fishSize,
              height: widget.fishSize,
              gaplessPlayback: true,
            ),
          ),
        );
      },
    );
  }
}
