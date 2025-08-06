import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class FishWidget extends StatefulWidget {
  final double progress;
  final bool isSwimming;

  const FishWidget({
    super.key,
    required this.progress,
    required this.isSwimming,
  });

  @override
  State<FishWidget> createState() => _FishWidgetState();
}

class _FishWidgetState extends State<FishWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animationHorizontal;
  late Animation<double> _animationVertical;
  bool _isFacingRight = true;
  Timer? _directionChangeTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );

    _setupAnimations();

    // Запускаем или останавливаем анимацию в зависимости от isSwimming
    if (widget.isSwimming) {
      _controller.repeat(reverse: true);
    }

    // Таймер для смены направления
    _directionChangeTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && widget.isSwimming) {
        setState(() {
          _isFacingRight = math.Random().nextBool();
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant FishWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Проверяем, изменилось ли состояние плавания
    if (widget.isSwimming != oldWidget.isSwimming) {
      if (widget.isSwimming) {
        _controller.repeat(reverse: true);
        if (_directionChangeTimer == null || !_directionChangeTimer!.isActive) {
          _directionChangeTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
            if (mounted) {
              setState(() {
                _isFacingRight = math.Random().nextBool();
              });
            }
          });
        }
      } else {
        _controller.stop();
        _directionChangeTimer?.cancel();
      }
    }
  }

  void _setupAnimations() {
    _animationHorizontal = Tween<double>(begin: -50, end: 50).animate(_controller);
    _animationVertical = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _directionChangeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double fishSize = 30 + 40 * widget.progress;
    final Color fishColor = Color.lerp(Colors.grey, Colors.orange, widget.progress)!;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_animationHorizontal.value, _animationVertical.value),
          child: Transform(
            alignment: Alignment.center,
            transform: _isFacingRight ? Matrix4.identity() : Matrix4.rotationY(math.pi),
            child: Image.asset(
              'assets/images/fish/fish.png',
              width: fishSize,
              height: fishSize,
              color: fishColor,
              colorBlendMode: BlendMode.modulate,
            ),
          ),
        );
      },
    );
  }
}