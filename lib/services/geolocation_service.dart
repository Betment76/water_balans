import 'package:geolocator/geolocator.dart';

class GeolocationService {
  /// Определяет текущее местоположение устройства.
  ///
  /// При необходимости запрашивает разрешения на доступ к местоположению.
  /// Возвращает объект [Position], если удалось определить местоположение, иначе выбрасывает исключение.
  Future<Position> determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Проверяем, включены ли службы геолокации.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Службы геолокации не включены, не можем продолжить.
      return Future.error('Службы геолокации отключены.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Разрешения отклонены, не можем продолжить.
        return Future.error('В доступе к геолокации отказано.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Разрешения отклонены навсегда, не можем запросить снова.
      return Future.error(
          'Разрешения на геолокацию отклонены навсегда, мы не можем запросить разрешения.');
    }

    // Когда разрешения предоставлены, получаем текущее местоположение.
    return await Geolocator.getCurrentPosition();
  }
}