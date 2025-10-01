import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/user_settings_provider.dart';
import '../models/user_settings.dart';
import '../services/storage_service.dart';

/// Экран настроек профиля: фото, имя, дата рождения (с возрастом), пол, рост, вес
class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});
  @override
  ConsumerState<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _birthCtrl = TextEditingController();
  final TextEditingController _weightCtrl = TextEditingController();
  final TextEditingController _heightCtrl = TextEditingController();

  DateTime? _birthDate; // дата рождения
  String _gender = 'male'; // пол: male/female
  XFile? _avatar; // путь к фото
  int _activityLevel = 1; // 0..2

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Загружаем имя/дату/пол/аватар из SharedPreferences
    final name = await StorageService.getString('profile_name');
    final birth = await StorageService.getString('profile_birthdate');
    final gender = await StorageService.getString('profile_gender');
    final avatar = await StorageService.getString('profile_avatar_path');

    final settings = ref.read(userSettingsProvider);

    if (mounted) setState(() {
      _nameCtrl.text = name ?? '';
      if (birth != null) {
        _birthCtrl.text = birth;
        _birthDate = _tryParseDate(birth);
      }
      _gender = (gender == 'female') ? 'female' : 'male';
      if (settings != null) {
        _weightCtrl.text = settings.weight.toString();
        _heightCtrl.text = settings.height?.toString() ?? '';
        // нормализуем старые 1..5 в 0..2
        final savedLevel = settings.activityLevel;
        _activityLevel = savedLevel <= 2 ? savedLevel : (((savedLevel - 1) / 2).round()).clamp(0, 2);
      }
      if (avatar != null && File(avatar).existsSync()) {
        _avatar = XFile(avatar);
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _birthCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  // Сохранить профиль
  Future<void> _save() async {
    // Сохраняем имя/дату/пол/аватар в SharedPreferences
    await StorageService.setString('profile_name', _nameCtrl.text.trim());
    await StorageService.setString('profile_birthdate', _birthCtrl.text.trim());
    await StorageService.setString('profile_gender', _gender);
    if (_avatar != null) {
      await StorageService.setString('profile_avatar_path', _avatar!.path);
    }

    // Обновляем вес/рост через UserSettings
    final old = ref.read(userSettingsProvider);
    final weight = int.tryParse(_weightCtrl.text);
    final height = _heightCtrl.text.isNotEmpty ? int.tryParse(_heightCtrl.text) : null;
    if (weight != null && old != null) {
      final updated = UserSettings(
        weight: weight,
        height: height,
        activityLevel: _activityLevel, // 0..2
        dailyNormML: old.dailyNormML,
        isWeatherEnabled: old.isWeatherEnabled,
        notificationIntervalHours: old.notificationIntervalHours,
        unit: old.unit,
      );
      ref.read(userSettingsProvider.notifier).save(updated);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Профиль сохранён')));
      Navigator.of(context).pop();
    }
  }

  // Выбрать фото из галереи
  Future<void> _pickAvatar() async {
    final photos = await Permission.photos.request();
    final storage = await Permission.storage.request();
    if (!(photos.isGranted || storage.isGranted)) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null && mounted) setState(() => _avatar = file);
  }

  // Обработчик ввода даты с автоподстановкой точек
  void _onBirthChanged(String value) {
    final d = _tryParseDate(value);
    if (mounted) setState(() => _birthDate = d);
  }

  DateTime? _tryParseDate(String value) {
    final m = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(value);
    if (m == null) return null;
    final day = int.parse(m.group(1)!);
    final mon = int.parse(m.group(2)!);
    final year = int.parse(m.group(3)!);
    try { return DateTime(year, mon, day); } catch (_) { return null; }
  }

  int _age(DateTime birth) {
    final now = DateTime.now();
    var a = now.year - birth.year;
    if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) a--;
    return a;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мой профиль'), centerTitle: true, backgroundColor: const Color(0xFF1976D2), elevation: 0),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1976D2), Color(0xFF64B5F6), Colors.white]),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 86, left: 16, right: 16, bottom: 24), // отступ под баннер
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCard(
                child: Column(
                  children: [
                    // Фото
                    Center(
                      child: GestureDetector(
                        onTap: _pickAvatar,
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor: Colors.white,
                          backgroundImage: _avatar != null ? FileImage(File(_avatar!.path)) : null,
                          child: _avatar == null ? const Icon(Icons.camera_alt, color: Color(0xFF1976D2)) : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(controller: _nameCtrl, label: 'Имя', icon: Icons.person),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildCard(
                child: Column(
                  children: [
                    // Дата рождения + возраст
                    TextField(
                      controller: _birthCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: _onBirthChanged,
                      inputFormatters: [_DateDigitsOnlyFormatter()],
                      maxLength: 10,
                      decoration: InputDecoration(
                        counterText: '',
                        labelText: 'Дата рождения (ДД.ММ.ГГГГ)',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.cake),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              _birthDate != null ? '${_age(_birthDate!)} лет' : '—',
                              style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                      style: const TextStyle(color: Colors.black),
                    ),
                    const SizedBox(height: 12),
                    // Пол
                    Row(children: [
                      const Text('Пол:', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      ChoiceChip(label: const Text('Мужской'), selected: _gender == 'male', onSelected: (_) => setState(() => _gender = 'male')),
                      const SizedBox(width: 8),
                      ChoiceChip(label: const Text('Женский'), selected: _gender == 'female', onSelected: (_) => setState(() => _gender = 'female')),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildCard(
                child: Row(children: [
                  Expanded(child: _buildTextField(controller: _weightCtrl, label: 'Вес (кг)', icon: Icons.monitor_weight)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTextField(controller: _heightCtrl, label: 'Рост (см)', icon: Icons.height)),
                ]),
              ),
              const SizedBox(height: 8),
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Уровень активности', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Низкий'),
                            selected: _activityLevel == 0,
                            selectedColor: Colors.blue,
                            labelStyle: TextStyle(color: _activityLevel == 0 ? Colors.white : Colors.black87),
                            onSelected: (_) => setState(() => _activityLevel = 0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            backgroundColor: Colors.grey.shade200,
                            showCheckmark: false,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Средний'),
                            selected: _activityLevel == 1,
                            selectedColor: Colors.blue,
                            labelStyle: TextStyle(color: _activityLevel == 1 ? Colors.white : Colors.black87),
                            onSelected: (_) => setState(() => _activityLevel = 1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            backgroundColor: Colors.grey.shade200,
                            showCheckmark: false,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Высокий'),
                            selected: _activityLevel == 2,
                            selectedColor: Colors.blue,
                            labelStyle: TextStyle(color: _activityLevel == 2 ? Colors.white : Colors.black87),
                            onSelected: (_) => setState(() => _activityLevel = 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            backgroundColor: Colors.grey.shade200,
                            showCheckmark: false,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  icon: const Icon(Icons.save),
                  label: const Text('Сохранить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Карточка в стиле настроек
  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }

  /// Единый текстфилд
  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon}) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
      ),
      style: const TextStyle(color: Colors.black),
    );
  }
}

/// Форматтер: только цифры и автоподстановка точек для ДД.ММ.ГГГГ
class _DateDigitsOnlyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 8) digits = digits.substring(0, 8);
    final sb = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      sb.write(digits[i]); if (i == 1 || i == 3) sb.write('.');
    }
    final txt = sb.toString();
    return TextEditingValue(text: txt, selection: TextSelection.collapsed(offset: txt.length));
  }
}



