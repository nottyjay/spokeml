import 'package:flutter_test/flutter_test.dart';
import 'package:spoke_ml_example/main.dart';
import 'package:table_calendar/table_calendar.dart';

void main() {
  testWidgets('generated layout renders a third-party calendar', (
    tester,
  ) async {
    await tester.pumpWidget(const SpokeMlExampleApp());

    expect(find.byType(TableCalendar<dynamic>), findsOneWidget);
    expect(find.text('第三方 TableCalendar'), findsOneWidget);
    expect(find.text('请选择日期'), findsOneWidget);

    await tester.tap(find.text('${DateTime.now().day}').first);
    await tester.pump();

    expect(find.textContaining('已选择：'), findsOneWidget);
  });
}
