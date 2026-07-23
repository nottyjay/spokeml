import 'package:flutter/material.dart';

import 'calendar_controller.dart';
import 'catalog_controller.dart';
import 'generated/calendar/table_calendar.g.dart';
import 'generated/catalog/product_list.g.dart';

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
      home: const DemoHomePage(),
    );
  }
}

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({super.key});

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage> {
  final _calendar = CalendarController();
  final _catalog = CatalogController();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SpokeML Example'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '第三方组件'),
              Tab(text: '动态集合'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            CalendarDemoView(calendar: _calendar),
            Column(
              children: [
                Expanded(child: ProductListView(controller: _catalog)),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: FilledButton(
                      onPressed: _catalog.appendProducts,
                      child: const Text('追加 5 个商品'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _calendar.dispose();
    _catalog.dispose();
    super.dispose();
  }
}
