import 'package:flutter/material.dart';
import '../services/rustore_pay_service.dart';
import '../services/mytarget_ad_service.dart';

/// Виджет для показа рекламного баннера MyTarget 320x50
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({Key? key}) : super(key: key);

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  bool _isAdLoaded = false;
  bool _isLoading = true;
  String? _errorMessage;

  // ID рекламного блока MyTarget (ваш реальный)
  static const int _bannerId = 1895039;

  @override
  void initState() {
    super.initState();
    _checkAdFreeStatusAndLoadAd();
  }

  Future<void> _checkAdFreeStatusAndLoadAd() async {
    // Проверяем, куплено ли отключение рекламы
    final isAdFree = await RustorePayService.isAdFree();

    if (isAdFree) {
      // Если реклама отключена, не показываем баннер
      setState(() {
        _isLoading = false;
        _isAdLoaded = false;
      });
      return;
    }

    // Если реклама не отключена, загружаем баннер
    _loadAd();
  }

  Future<void> _loadAd() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Проверяем, доступна ли реклама
      final isAvailable = await MyTargetAdService.isAdAvailable();

      if (isAvailable && mounted) {
        // Показываем баннер точно под AppBar
        await MyTargetAdService.showBannerUnderAppBar(_bannerId);

        setState(() {
          _isAdLoaded = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Реклама недоступна';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ошибка загрузки рекламы: $e';
      });
      print('Ошибка загрузки баннера MyTarget: $e');
    }
  }

  @override
  void dispose() {
    // Скрываем баннер при удалении виджета
    if (_isAdLoaded) {
      MyTargetAdService.hideBanner();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: RustorePayService.isAdFree(),
      builder: (context, snapshot) {
        final isAdFree = snapshot.data ?? false;

        // Если реклама отключена, не показываем баннер
        if (isAdFree) {
          return const SizedBox.shrink();
        }

        if (_isLoading) {
          // Показываем индикатор загрузки без рамки
          return Container(
            width: 320,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.blue,
                ),
              ),
            ),
          );
        }

        if (_errorMessage != null || !_isAdLoaded) {
          // Показываем заглушку при ошибке без рамки
          return Container(
            width: 320,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border.all(color: Colors.grey[300]!, width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                _errorMessage ?? 'Реклама недоступна',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // Когда реальный MyTarget баннер загружен, не показываем Flutter поле
        // Реальный баннер отображается через нативный Android код
        return const SizedBox.shrink();
      },
    );
  }
}
