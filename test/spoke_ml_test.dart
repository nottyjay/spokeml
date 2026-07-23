import 'package:flutter_test/flutter_test.dart';
import 'package:spoke_ml/spoke_ml.dart';

void main() {
  final compiler = SpokeMlCompiler();

  test('compiles bindings and widget properties', () {
    final output = compiler.compile('''
<layout class="GreetingView">
  <data>
    <variable name="user" />
    <variable name="controller" />
  </data>
  <Column mainAxisAlignment="center">
    <Text text="@{user.name}" style="headlineMedium" />
    <ElevatedButton onPressed="@{controller.submit}">
      <Text text="提交" />
    </ElevatedButton>
  </Column>
</layout>
''');

    expect(output, contains('class GreetingView extends StatelessWidget'));
    expect(output, contains('required this.user'));
    expect(output, contains('user.name'));
    expect(
      output,
      contains('style: Theme.of(context).textTheme.headlineMedium'),
    );
    expect(output, contains('onPressed: controller.submit'));
    expect(output, contains("'提交'"));
  });

  test('compiles layout values and conditional visibility', () {
    final output = compiler.compile('''
<layout>
  <data><variable name="state" /></data>
  <Container padding="8, 16, 8, 16" color="#336699">
    <Text text="Ready" visible="@{state.ready}" />
  </Container>
</layout>
''');

    expect(output, contains('EdgeInsets.fromLTRB(8, 16, 8, 16)'));
    expect(output, contains('Color(0xFF336699)'));
    expect(output, contains('visible: state.ready'));
  });

  test('rejects bindings to undeclared variables', () {
    expect(
      () => compiler.compile('''
<layout><Text text="@{user.name}" /></layout>
'''),
      throwsA(
        isA<SpokeMlCompileException>().having(
          (error) => error.message,
          'message',
          contains('undeclared variable "user"'),
        ),
      ),
    );
  });

  test('rejects unsupported attributes', () {
    expect(
      () => compiler.compile('''
<layout><Text text="hello" typo="value" /></layout>
'''),
      throwsA(
        isA<SpokeMlCompileException>().having(
          (error) => error.message,
          'message',
          contains('does not support attribute "typo"'),
        ),
      ),
    );
  });

  test('compiles a namespaced third-party widget', () {
    final output = compiler.compile('''
<layout
  class="CalendarView"
  xmlns:table="package:table_calendar/table_calendar.dart">
  <data><variable name="calendar" /></data>
  <table:TableCalendar
    firstDay="@{calendar.firstDay}"
    lastDay="@{calendar.lastDay}"
    focusedDay="@{calendar.focusedDay}"
    rowHeight="48"
    pageJumpingEnabled="true" />
</layout>
''');

    expect(
      output,
      contains("import 'package:table_calendar/table_calendar.dart' as table;"),
    );
    expect(output, contains('table.TableCalendar('));
    expect(output, contains('firstDay: calendar.firstDay'));
    expect(output, contains('rowHeight: 48'));
    expect(output, contains('pageJumpingEnabled: true'));
  });

  test('generates typed variables and local Observe boundaries', () {
    final output = compiler.compile('''
<layout class="CounterView">
  <data>
    <variable
      name="controller"
      type="CounterController"
      import="package:example/counter_controller.dart" />
  </data>
  <Observe listenable="@{controller}">
    <Text text="@{controller.label}" />
  </Observe>
</layout>
''');

    expect(
      output,
      contains("import 'package:example/counter_controller.dart';"),
    );
    expect(output, contains('final CounterController controller;'));
    expect(output, contains('ListenableBuilder('));
    expect(output, contains('listenable: controller'));
  });

  test('value Observe introduces a scoped alias', () {
    final output = compiler.compile('''
<layout>
  <data><variable name="controller" /></data>
  <Observe valueListenable="@{controller.count}" as="count">
    <Text text="@{count.toString()}" />
  </Observe>
</layout>
''');

    expect(output, contains('ValueListenableBuilder('));
    expect(output, contains('builder: (context, count, _)'));
    expect(output, contains('count.toString()'));
  });

  test('reports the XML path and attribute location', () {
    expect(
      () => compiler.compile(
        '<layout>\n  <Text text="hello" typo="value" />\n</layout>',
        sourcePath: 'layouts/broken.xml',
      ),
      throwsA(
        isA<SpokeMlCompileException>()
            .having(
              (error) => error.location?.path,
              'path',
              'layouts/broken.xml',
            )
            .having((error) => error.location?.line, 'line', 2)
            .having((error) => error.location?.column, 'column', 22),
      ),
    );
  });

  test('namespace aliases can be used in binding expressions', () {
    final output = compiler.compile('''
<layout xmlns:table="package:table_calendar/table_calendar.dart">
  <data><variable name="calendar" /></data>
  <table:TableCalendar
    firstDay="@{calendar.firstDay}"
    lastDay="@{calendar.lastDay}"
    focusedDay="@{calendar.focusedDay}"
    calendarFormat="@{table.CalendarFormat.month}" />
</layout>
''');

    expect(output, contains('calendarFormat: table.CalendarFormat.month'));
  });

  test('compiles conditional construction and stable keyed collections', () {
    final output = compiler.compile('''
<layout class="ProductsView">
  <data><variable name="products" type="List&lt;Product&gt;" /></data>
  <Column>
    <ForEach
      items="@{products}"
      as="product"
      index="index"
      keyBy="@{product.id}">
      <Text text="@{product.name}" if="@{!product.hidden}" />
    </ForEach>
  </Column>
</layout>
''');

    expect(
      output,
      contains('for (final (index, product) in products.indexed)'),
    );
    expect(output, contains('key: ValueKey(product.id)'));
    expect(output, contains('!product.hidden ? Text('));
    expect(output, contains('product.name'));
    expect(output, contains(': const SizedBox.shrink()'));
  });

  test('compiles generic named builder callbacks', () {
    final output = compiler.compile('''
<layout>
  <data><variable name="products" /></data>
  <ListView.builder itemCount="@{products.length}">
    <Builder name="itemBuilder" args="context,index">
      <Text text="@{products[index].name}" key="@{ValueKey(index)}" />
    </Builder>
  </ListView.builder>
</layout>
''');

    expect(output, contains('ListView.builder('));
    expect(output, contains('itemCount: products.length'));
    expect(output, contains('itemBuilder: (context, index)'));
    expect(output, contains('key: ValueKey(index)'));
  });

  test('stream Observe exposes an AsyncSnapshot alias', () {
    final output = compiler.compile('''
<layout>
  <data><variable name="updates" /></data>
  <Observe stream="@{updates}" as="snapshot">
    <Text text="@{snapshot.data.toString()}" />
  </Observe>
</layout>
''');

    expect(output, contains('StreamBuilder('));
    expect(output, contains('stream: updates'));
    expect(output, contains('builder: (context, snapshot)'));
  });

  test('owned variables generate a thin stateful host', () {
    final output = compiler.compile('''
<layout class="LoginView">
  <data>
    <variable name="title" type="String" />
    <variable
      name="controller"
      type="LoginController"
      ownership="owned"
      create="@{LoginController()}" />
  </data>
  <Text text="@{title}" />
</layout>
''');

    expect(output, contains('class LoginView extends StatelessWidget'));
    expect(output, contains('class LoginViewHost extends StatefulWidget'));
    expect(
      output,
      contains('late final LoginController controller = LoginController();'),
    );
    expect(output, contains('controller.dispose();'));
    expect(output, contains('title: widget.title'));
    expect(output, contains('controller: controller'));
  });

  test('maps generated diagnostics back to the nearest XML widget', () {
    final sourceMap = SpokeMlSourceMap.fromJson('''
{
  "version": 1,
  "entries": [
    {
      "generatedLine": 10,
      "path": "layouts/catalog.xml",
      "offset": 42,
      "line": 3,
      "column": 5
    },
    {
      "generatedLine": 20,
      "path": "layouts/catalog.xml",
      "offset": 90,
      "line": 5,
      "column": 7
    }
  ]
}
''');

    expect(sourceMap.lookup(9), isNull);
    expect(sourceMap.lookup(18)?.line, 3);
    expect(sourceMap.lookup(22)?.line, 5);
  });

  test('keeps static login content outside independent dynamic boundaries', () {
    final output = compiler.compile('''
<layout class="LoginView">
  <data><variable name="controller" /></data>
  <Column>
    <Text text="LOGO" />
    <Observe valueListenable="@{controller.isSubmitting}" as="submitting">
      <ElevatedButton
        onPressed="@{submitting ? null : controller.login}">
        <Text text="登录" />
      </ElevatedButton>
    </Observe>
    <Observe valueListenable="@{controller.error}" as="error">
      <Text text="@{error ?? ''}" if="@{error != null}" />
    </Observe>
  </Column>
</layout>
''');

    expect(output, contains("'LOGO'"));
    expect(output, contains('submitting ? null : controller.login'));
    expect(output, contains('valueListenable: controller.error'));
    expect(output, contains('error != null ? Text('));
    expect(output, contains("error ?? ''"));
  });
}
