import 'package:flutter/foundation.dart';

final class CalendarController extends ChangeNotifier {
  final DateTime firstDay = DateTime.utc(2020);
  final DateTime lastDay = DateTime.utc(2030, 12, 31);
  DateTime focusedDay = DateTime.now();
  DateTime? selectedDay;

  String get selectionLabel {
    final day = selectedDay;
    if (day == null) {
      return '请选择日期';
    }
    return '已选择：${day.year}-${_twoDigits(day.month)}-${_twoDigits(day.day)}';
  }

  bool isSelected(DateTime day) {
    final selected = selectedDay;
    return selected != null &&
        selected.year == day.year &&
        selected.month == day.month &&
        selected.day == day.day;
  }

  void selectDay(DateTime selected, DateTime focused) {
    selectedDay = selected;
    focusedDay = focused;
    notifyListeners();
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
