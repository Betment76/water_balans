import 'package:flutter/material.dart';
import '../models/water_intake.dart';

/// Список последних записей о приёме воды
class WaterList extends StatelessWidget {
  /// Список записей (максимум 3)
  final List<WaterIntake> waterIntakes;
  /// Callback для удаления записи
  final void Function(String id) onDelete;

  const WaterList({Key? key, required this.waterIntakes, required this.onDelete}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: waterIntakes.length,
      itemBuilder: (context, index) {
        final intake = waterIntakes[index];
        return Dismissible(
          key: Key(intake.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => onDelete(intake.id),
          child: ListTile(
            leading: const Icon(Icons.local_drink, color: Colors.blue),
            title: Text('${intake.volumeML} мл'),
            subtitle: Text(_formatTime(intake.dateTime)),
          ),
        );
      },
    );
  }

  /// Форматировать время для отображения
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
} 