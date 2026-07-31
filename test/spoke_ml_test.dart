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

  test('compiles Stack with common positioning and alignment widgets', () {
    final output = compiler.compile('''
<layout>
  <data><variable name="state" /></data>
  <Stack
    alignment="center"
    textDirection="ltr"
    fit="expand"
    clipBehavior="none">
    <Positioned top="12" left="@{state.offset}" width="200">
      <Text text="浮层" />
    </Positioned>
    <Align alignment="bottomRight" widthFactor="1">
      <Text text="操作" />
    </Align>
  </Stack>
</layout>
''');

    expect(output, contains('Stack('));
    expect(output, contains('alignment: Alignment.center'));
    expect(output, contains('textDirection: TextDirection.ltr'));
    expect(output, contains('fit: StackFit.expand'));
    expect(output, contains('clipBehavior: Clip.none'));
    expect(output, contains('Positioned('));
    expect(output, contains('top: 12'));
    expect(output, contains('left: state.offset'));
    expect(output, contains('width: 200'));
    expect(output, contains('Align('));
    expect(output, contains('alignment: Alignment.bottomRight'));
    expect(output, contains('widthFactor: 1'));
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

  test('compiles positional arguments for named constructors', () {
    final output = compiler.compile('''
<layout xmlns:m="package:flutter/material.dart">
  <data><variable name="assetName" type="String" /></data>
  <m:Image.asset
    arg0="@{assetName}"
    width="320"
    fit="@{m.BoxFit.cover}" />
</layout>
''');

    expect(output, contains('m.Image.asset('));
    expect(output, contains('assetName,'));
    expect(output, contains('width: 320'));
    expect(output, contains('fit: m.BoxFit.cover'));
  });

  test('rejects non-contiguous positional arguments', () {
    expect(
      () => compiler.compile('''
<layout xmlns:m="package:flutter/material.dart">
  <m:Image.asset arg1="image.png" />
</layout>
'''),
      throwsA(
        isA<SpokeMlCompileException>().having(
          (error) => error.message,
          'message',
          contains('must be contiguous from "arg0"'),
        ),
      ),
    );
  });

  test('accepts const expressions and closure-local parameters', () {
    final output = compiler.compile('''
<layout xmlns:m="package:flutter/material.dart">
  <data><variable name="controller" /></data>
  <m:Image
    image="@{const m.AssetImage('image.png')}"
    errorBuilder="@{(context, error, stackTrace) => controller.fallback(error)}" />
</layout>
''');

    expect(output, contains("const m.AssetImage('image.png')"));
    expect(output, contains('controller.fallback(error)'));
  });

  test('accepts literal-only binding expressions', () {
    final output = compiler.compile('''
<layout>
  <SizedBox width="@{320}" height="@{0x20}" />
</layout>
''');

    expect(output, contains('width: 320'));
    expect(output, contains('height: 0x20'));
  });

  test('emits children for a single ForEach in a custom collection', () {
    final output = compiler.compile('''
<layout xmlns:m="package:flutter/material.dart">
  <data><variable name="items" /></data>
  <m:ListView>
    <ForEach items="@{items}" as="item" keyBy="@{item.id}">
      <Text text="@{item.label}" />
    </ForEach>
  </m:ListView>
</layout>
''');

    expect(output, contains('m.ListView('));
    expect(output, contains('children: ['));
    expect(output, isNot(contains('m.ListView(\n      child:')));
  });

  test('compiles named widget slots for custom constructors', () {
    final output = compiler.compile('''
<layout xmlns:m="package:flutter/material.dart">
  <m:Scaffold>
    <Slot name="appBar">
      <m:AppBar>
        <Slot name="title">
          <Text text="视频列表" />
        </Slot>
      </m:AppBar>
    </Slot>
    <Slot name="body">
      <Center><Text text="内容" /></Center>
    </Slot>
  </m:Scaffold>
</layout>
''');

    expect(output, contains('appBar:'));
    expect(output, contains('title:'));
    expect(output, contains('body:'));
    expect(output, isNot(contains('m.Scaffold(\n      child:')));
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

  test('tracks the exact XML binding expression span with CRLF input', () {
    const source =
        '<layout>\r\n'
        '  <data><variable name="state" /></data>\r\n'
        '  <Text text="@{state.title}" />\r\n'
        '</layout>';
    final document = compiler.parse(source, sourcePath: 'layouts/title.xml');
    final value = document.root.attributes['text']!;
    final expressionOffset = source.indexOf('state.title');

    expect(value.valueLocation.path, 'layouts/title.xml');
    expect(value.valueLocation.offset, expressionOffset);
    expect(value.valueLocation.line, 3);
    expect(value.valueLocation.column, 17);
    expect(value.valueLocation.length, 'state.title'.length);
  });

  test('tracks the raw XML range when a binding contains an entity', () {
    const source = '''
<layout>
  <data><variable name="state" /></data>
  <Text text="young" if="@{state.age &lt; 18}" />
</layout>
''';
    final document = compiler.parse(source, sourcePath: 'layouts/age.xml');
    final value = document.root.attributes['if']!;

    expect(value.source, 'state.age < 18');
    expect(value.valueLocation.offset, source.indexOf('state.age'));
    expect(value.valueLocation.length, 'state.age &lt; 18'.length);
  });

  test('maps a generated offset to the smallest enclosing XML span', () {
    const outer = SourceLocation(
      path: 'layouts/title.xml',
      offset: 20,
      line: 3,
      column: 3,
      length: 30,
    );
    const binding = SourceLocation(
      path: 'layouts/title.xml',
      offset: 32,
      line: 3,
      column: 15,
      length: 11,
    );
    final mapped = const SpokeMlSourceMapWriter().write(
      'final value = '
      '/* spoke_ml:20:30 */ Text('
      '/* spoke_ml:32:11 */ state.title);',
      const [outer, binding],
    );
    final sourceMap = SpokeMlSourceMap.fromJson(mapped.mapJson);
    final expressionOffset = mapped.source.indexOf('state.title');

    expect(mapped.source, contains('spoke_ml:32:11'));
    final offsetLocation = sourceMap.lookupOffset(expressionOffset);
    final positionLocation = sourceMap.lookupPosition(
      mapped.source,
      1,
      expressionOffset + 1,
    );
    for (final location in [offsetLocation, positionLocation]) {
      expect(location?.path, binding.path);
      expect(location?.offset, binding.offset);
      expect(location?.line, binding.line);
      expect(location?.column, binding.column);
      expect(location?.length, binding.length);
    }
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
