import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';

const Color kBlue = Color(0xFF1976D2);

/// Экран "О приложении"
class AboutScreen extends StatelessWidget {
  const AboutScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kWhite,
      appBar: AppBar(
        title: const Text('О приложении'),
        centerTitle: true,
        backgroundColor: kBlue,
        foregroundColor: AppColors.kWhite,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Логотип и название
          _buildHeader(),
          
          const SizedBox(height: 32),
          
          // Информация о приложении
          _buildAppInfo(),
          
          const SizedBox(height: 24),
          
          // Разработчик
          _buildDeveloperInfo(),
          
          const SizedBox(height: 24),
          
          // Контакты
          _buildContactInfo(),
          
          const SizedBox(height: 24),
          
          // Политика конфиденциальности
          _buildPrivacyPolicy(),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Заголовок с логотипом
  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: kBlue,
            borderRadius: BorderRadius.circular(60),
            boxShadow: [
              BoxShadow(
                color: kBlue.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.water_drop,
            size: 60,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Водный баланс',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: kBlue,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Версия 1.0.0',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  /// Информация о приложении
  Widget _buildAppInfo() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'О приложении',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kBlue,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Версия', '1.0.0'),
            _buildInfoRow('Платформа', 'Android'),
            _buildInfoRow('Языки', 'Русский, Английский'),
            _buildInfoRow('Размер', '~15 MB'),
            const SizedBox(height: 12),
            const Text(
              'Приложение для отслеживания потребления воды с интерактивным интерфейсом и умными напоминаниями.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Информация о разработчике
  Widget _buildDeveloperInfo() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Разработчик',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kBlue,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: kBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: kBlue,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SVitalich',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Flutter разработчик',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Контактная информация
  Widget _buildContactInfo() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Контакты',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kBlue,
              ),
            ),
            const SizedBox(height: 12),
            _buildContactRow(
              Icons.email,
              'Email',
              'svitalich76@mail.ru',
              () => _launchEmail(),
            ),
            const SizedBox(height: 8),
            _buildContactRow(
              Icons.bug_report,
              'Сообщить об ошибке',
              'Отправить отчет',
              () => _launchEmail(subject: 'Ошибка в приложении Водный баланс'),
            ),
            const SizedBox(height: 8),
            _buildContactRow(
              Icons.lightbulb,
              'Предложить идею',
              'Отправить предложение',
              () => _launchEmail(subject: 'Предложение для приложения Водный баланс'),
            ),
          ],
        ),
      ),
    );
  }

  /// Политика конфиденциальности
  Widget _buildPrivacyPolicy() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Политика конфиденциальности',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kBlue,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Приложение "Водный баланс" уважает вашу конфиденциальность:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            _buildPrivacyPoint('• Все данные хранятся локально на вашем устройстве'),
            _buildPrivacyPoint('• Мы не собираем и не передаем личную информацию'),
            _buildPrivacyPoint('• Приложение работает без интернета'),
            _buildPrivacyPoint('• Уведомления настраиваются только локально'),
            const SizedBox(height: 12),
            const Text(
              'Для получения полной политики конфиденциальности напишите на email.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Строка информации
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Строка контакта
  Widget _buildContactRow(IconData icon, String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(
              icon,
              color: kBlue,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  /// Пункт политики конфиденциальности
  Widget _buildPrivacyPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13),
      ),
    );
  }

  /// Открытие email
  Future<void> _launchEmail({String subject = ''}) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'svitalich76@mail.ru',
      query: subject.isNotEmpty ? 'subject=$subject' : null,
    );
    
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }
} 