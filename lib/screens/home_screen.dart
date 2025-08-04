import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'dart:math';
import 'package:water_balance/l10n/app_localizations.dart';
import '../models/water_intake.dart';
import '../services/storage_service.dart';
import '../providers/user_settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const Color kBlue = Color(0xFF1976D2); // синий для рамок и текста
const Color kLightBlue = Color(0xFF64B5F6); // голубой для воды
const Color kWhite = Colors.white; // белый фон

/// Главный экран с прогрессом воды и "живой" водой
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  double _tiltAngle = 0.0; // угол наклона по X (в радианах)
  double _currentWaveAngle = 0.0; // угол волны (инерция)
  double _waveAmplitude = 0.0; // амплитуда волны
  double _wavePhase = 0.0; // фаза волны
  double _lastAngle = 0.0; // для вычисления скорости изменения
  StreamSubscription<AccelerometerEvent>? _accelSub;
  late AnimationController _controller;

  int _currentWater = 0; // теперь состояние
  int _dailyGoal = 2000; // будет обновляться из настроек

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 16))
      ..addListener(_animateWave);
    _controller.repeat();
    _accelSub = accelerometerEventStream().listen((event) {
      // Только по X (наклон влево/вправо)
      double angle = event.x / 9.8 * (pi / 2);
      angle = angle.clamp(-pi / 2, pi / 2); // до 90 градусов
      setState(() {
        _tiltAngle = angle;
      });
    });
    
    // Загружаем данные о воде за сегодня
    _loadTodayWater();
    _loadUserSettings();
  }
  
  Future<void> _loadTodayWater() async {
    try {
      final todayIntakes = await StorageService.getWaterIntakesForDate(DateTime.now());
      final todayTotal = todayIntakes.fold<int>(0, (sum, intake) => sum + intake.volumeML);
      print('Загружено записей за сегодня: ${todayIntakes.length}, общий объем: $todayTotal мл');
      setState(() {
        _currentWater = todayTotal;
      });
    } catch (e) {
      print('Ошибка загрузки данных о воде: $e');
    }
  }
  
  void _loadUserSettings() {
    final settings = ref.read(userSettingsProvider);
    if (settings != null) {
      setState(() {
        _dailyGoal = settings.dailyNormML;
      });
    }
  }

  void _animateWave() {
    // Плавно догоняем целевой угол (эффект инерции)
    const double inertia = 0.12;
    _currentWaveAngle += (_tiltAngle - _currentWaveAngle) * inertia;

    // Физика волны: если угол меняется — увеличиваем амплитуду
    double angleDelta = _tiltAngle - _lastAngle;
    _lastAngle = _tiltAngle;
    if (angleDelta.abs() > 0.001) {
      _waveAmplitude += angleDelta * 2.0;
      _waveAmplitude = _waveAmplitude.clamp(-0.8, 0.8);
    }
    _waveAmplitude *= 0.96;
    _wavePhase += 0.06;
    if (_waveAmplitude.abs() < 0.01) _waveAmplitude = 0.0;
    setState(() {});
  }

  Future<void> _addWater(int amount) async {
    setState(() {
      _currentWater = (_currentWater + amount).clamp(0, _dailyGoal);
    });
    
    // Сохраняем запись о приеме воды
    final intake = WaterIntake(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      volumeML: amount,
      dateTime: DateTime.now(),
    );
    
    try {
      final allIntakes = await StorageService.loadWaterIntakes();
      allIntakes.add(intake);
      await StorageService.saveWaterIntakes(allIntakes);
      print('Запись воды сохранена: ${intake.volumeML} мл');
      
      // Обновляем отображение
      await _loadTodayWater();
    } catch (e) {
      print('Ошибка сохранения записи воды: $e');
    }
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(userSettingsProvider);
    if (settings != null && _dailyGoal != settings.dailyNormML) {
      _dailyGoal = settings.dailyNormML;
    }
    
    final int percent = _dailyGoal > 0 ? ((_currentWater / _dailyGoal) * 100).toInt() : 0;
    final double percentFill = _dailyGoal > 0 ? (_currentWater / _dailyGoal).clamp(0.0, 1.0) : 0.0;
    final double ballSize = MediaQuery.of(context).size.height * 0.45;

    return Scaffold(
      backgroundColor: kWhite,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.appTitle),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: kBlue,
        foregroundColor: kWhite,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            // Шар с водой и процентом
            Center(
              child: _WaterBall(
                percent: percent,
                fill: percentFill,
                size: ballSize,
                tiltAngle: _currentWaveAngle,
                waveAmplitude: _waveAmplitude,
                wavePhase: _wavePhase,
              ),
            ),
            const SizedBox(height: 24),
            // Прогресс (текущее/цель)
            Text(
              AppLocalizations.of(context)!.currentWaterStats(_currentWater, _dailyGoal),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kBlue),
            ),
            const Spacer(),
            // Слово "Добавить" над кнопкой
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                AppLocalizations.of(context)!.addWater,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: kBlue),
              ),
            ),
            // Ряд быстрых кнопок без контейнера и рамки
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _QuickAddButton(amount: 200, onPressed: () => _addWater(200)),
                _QuickAddButton(amount: 250, onPressed: () => _addWater(250)),
                _QuickAddButton(amount: 500, onPressed: () => _addWater(500)),
                _QuickAddButton(amount: 1000, onPressed: () => _addWater(1000)),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Круглый шар с водой и процентом
class _WaterBall extends StatelessWidget {
  final int percent;
  final double fill; // от 0.0 до 1.0
  final double size;
  final double tiltAngle; // угол наклона воды
  final double waveAmplitude; // амплитуда волны
  final double wavePhase; // фаза волны
  const _WaterBall({
    required this.percent,
    required this.fill,
    required this.size,
    required this.tiltAngle,
    required this.waveAmplitude,
    required this.wavePhase,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _WaterBallPainter(fill, tiltAngle, waveAmplitude, wavePhase),
          ),
          // Цвет процентов всегда синий с белой тенью
          Text(
            '$percent%',
            style: TextStyle(
              fontSize: size * 0.28,
              fontWeight: FontWeight.bold,
              color: kBlue,
              shadows: [
                Shadow(
                  blurRadius: 12,
                  color: Colors.white,
                  offset: Offset(0, 0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Painter для шара с "живой" водой
class _WaterBallPainter extends CustomPainter {
  final double fill; // от 0.0 до 1.0
  final double tiltAngle; // угол наклона воды
  final double waveAmplitude; // амплитуда волны
  final double wavePhase; // фаза волны
  _WaterBallPainter(this.fill, this.tiltAngle, this.waveAmplitude, this.wavePhase);

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final Offset center = Offset(radius, radius);

    // Рисуем белый круг (фон)
    final Paint circlePaint = Paint()
      ..color = kWhite
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, circlePaint);

    // Рисуем "живую" воду (волнистая поверхность, наклоняется по X)
    final Paint waterPaint = Paint()
      ..color = kLightBlue
      ..style = PaintingStyle.fill;
    final Path waterPath = Path();
    final double waterLevel = size.height * (1 - fill);
    final double baseWaveHeight = size.height * 0.05;
    final int waveCount = 2;
    // Волна: если амплитуда почти 0 — ровная поверхность
    waterPath.moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += 1) {
      double edgeAttenuation = 0.5 + 0.5 * cos((x / size.width) * pi); // затухание по краям
      double wave = 0;
      if (waveAmplitude.abs() > 0.001) {
        wave = sin((x / size.width) * pi * waveCount + wavePhase) * baseWaveHeight * waveAmplitude * 1.3 * edgeAttenuation;
      }
      double y = waterLevel + tan(tiltAngle) * (x - radius) * 0.25 + wave;
      waterPath.lineTo(x, y);
    }
    waterPath.lineTo(size.width, size.height);
    waterPath.close();
    // Обрезаем по кругу
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
    canvas.drawPath(waterPath, waterPaint);
    canvas.restore();

    // Контур шара
    final Paint outlinePaint = Paint()
      ..color = kBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, outlinePaint);
  }

  @override
  bool shouldRepaint(covariant _WaterBallPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.tiltAngle != tiltAngle ||
      oldDelegate.waveAmplitude != waveAmplitude ||
      oldDelegate.wavePhase != wavePhase;
}

/// Быстрая кнопка добавления воды
class _QuickAddButton extends StatelessWidget {
  final int amount;
  final VoidCallback onPressed;
  const _QuickAddButton({required this.amount, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: kBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        minimumSize: const Size(0, 40),
        elevation: 0,
      ),
      child: Text('$amount ${AppLocalizations.of(context)!.mlUnit}', style: const TextStyle(fontSize: 16, color: kWhite)),
    );
  }
}