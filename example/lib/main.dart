import 'package:flutter/material.dart';

import 'calendar_controller.dart';
import 'generated/calendar/table_calendar.g.dart';

void main() {
  runApp(const SpokeMlExampleApp());
}

class SpokeMlExampleApp extends StatelessWidget {
  const SpokeMlExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SpokeML Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const CalendarDemoPage(),
    );
  }
}

class CalendarDemoPage extends StatefulWidget {
  const CalendarDemoPage({super.key});

  @override
  State<CalendarDemoPage> createState() => _CalendarDemoPageState();
}

class _CalendarDemoPageState extends State<CalendarDemoPage> {
  final _calendar = CalendarController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SpokeML 第三方组件')),
      body: CalendarDemoView(calendar: _calendar),
    );
  }

  @override
  void dispose() {
    _calendar.dispose();
    super.dispose();
  }
}
