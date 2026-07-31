# SpokeML

[English](README.md)

SpokeML 是一个实验性的 XML-to-Flutter 编译器。它允许 Flutter 应用使用 XML
描述 Widget 树，同时继续使用 Dart 管理状态、业务逻辑和资源生命周期。

```text
layouts/account/login.xml
        │ build_runner
        ▼
lib/generated/account/login.g.dart
```

生成结果是普通、可读且可进行类型检查的 Flutter 代码。发布后的应用不需要在运行时
解析 XML，也不依赖动态 Widget 解释器。

常见 Flutter 布局 Widget 以原生 XML 标签提供，包括 `Row`、`Column`、
`Stack`、`Positioned`、`Align`、`Container`、`Padding`、`Center` 和
`SizedBox`。

> **项目状态：** SpokeML 目前处于方案验证阶段，还不是生产就绪的软件包。代码生成、
> Source Map、布局分组、局部状态边界、生命周期和第三方 Widget 接入均已有可执行测试；
> example 也已在 Android 与 macOS 上完成编译和启动验证。

## 为什么使用 SpokeML？

SpokeML 尝试为 Flutter 提供类似 Android Data Binding 的开发流程：

- 声明式 Widget 结构只需编辑 `layouts/` 下的 XML；
- 通过 `build_runner watch` 自动生成 `.g.dart`；
- XML 输入目录和生成的 Dart 目录保持一一对应；
- 使用有类型的 Dart 表达式，不引入运行时字符串表达式引擎；
- 只重建动态区域，不要求整个页面都成为 StatefulWidget；
- 通过 XML namespace 使用 Flutter 或第三方 Widget；
- 将生成阶段和后续 Dart 分析错误定位回原始 XML。

SpokeML 不会替代 Flutter 的状态管理生态。Controller、网络请求、分页、重试、
表单验证和领域逻辑仍然使用普通 Dart 代码实现。

## 环境要求

- Dart `^3.10.4`
- Flutter `>=3.38.0`
- `build_runner`

当前建议通过本地路径引用该项目：

```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  spoke_ml:
    path: ../SpokeML

dev_dependencies:
  build_runner: ">=2.14.1 <2.15.0"
```

在构建系统中包含顶层 `layouts/` 目录：

```yaml
# build.yaml
targets:
  $default:
    sources:
      - "$package$"
      - "lib/**"
      - "layouts/**"
```

## 快速开始

创建 `layouts/profile.xml`：

```xml
<layout class="ProfileView">
  <data>
    <variable
      name="controller"
      type="ProfileController"
      import="package:my_app/profile_controller.dart" />
  </data>

  <Center>
    <Column mainAxisSize="min">
      <Text text="@{controller.userName}" style="headlineMedium" />
      <SizedBox height="16" />
      <ElevatedButton onPressed="@{controller.save}">
        <Text text="保存" />
      </ElevatedButton>
    </Column>
  </Center>
</layout>
```

单次生成 Dart 代码：

```sh
dart run build_runner build --delete-conflicting-outputs
```

开发期间持续监听 XML 变化：

```sh
dart run build_runner watch --delete-conflicting-outputs
```

SpokeML 会生成：

```text
layouts/profile.xml
lib/generated/profile.g.dart
lib/generated/profile.g.dart.spoke.json
```

像普通 Flutter Widget 一样使用生成的 View：

```dart
import 'generated/profile.g.dart';

ProfileView(controller: profileController)
```

`.spoke.json` 是将生成 Dart 代码映射回 XML 的构建元数据，SpokeML 的错误重映射
工具会使用它。

## 布局目录和分组

输入与输出路径始终一一对应：

```text
layouts/profile.xml
layouts/account/login.xml
layouts/admin/login.xml

lib/generated/profile.g.dart
lib/generated/account/login.g.dart
lib/generated/admin/login.g.dart
```

因此，不同功能目录可以使用相同的 XML 文件名，而不需要把全部布局放进同一个生成
目录。每个布局仍然应该声明合适且不冲突的 Dart 类名。

移动、重命名或删除 XML 后，Dart 构建系统会同步更新其声明的生成输出。

## 数据与表达式

声明生成 View 接收的每个数据：

```xml
<data>
  <variable
    name="calendar"
    type="CalendarController"
    import="package:my_app/calendar_controller.dart" />
</data>
```

这会生成有类型的字段和构造参数：

```dart
final CalendarController calendar;
```

使用 `@{...}` 编写 Dart 表达式：

```xml
<Text
  text="@{calendar.selectionLabel}"
  visible="@{calendar.hasSelection}" />
```

早期原型可以省略 `type`，此时会生成 `dynamic`。但有类型的变量能提供更好的生成代码
分析能力，正式开发时应优先使用。

字符串、布尔值、数字、颜色、Insets、常用枚举和主题文字样式等简单 XML 值会自动
转换。复杂对象和回调应使用绑定表达式。

## 静态页面与动态区域

默认生成的布局 View 是 `StatelessWidget`。页面整体可以保持静态，同时让一个或多个
小区域分别监听自身状态：

```xml
<Column>
  <Text text="登录" style="headlineMedium" />

  <Observe listenable="@{controller}">
    <ElevatedButton
      onPressed="@{controller.isSubmitting ? null : controller.submit}">
      <Text text="@{controller.isSubmitting ? '登录中…' : '登录'}" />
    </ElevatedButton>
  </Observe>
</Column>
```

Controller 发出通知时，只有 `Observe` 内部的子树会重建。同一页面可以设置多个互不
影响的 `Observe` 节点。

### Listenable

```xml
<Observe listenable="@{controller}">
  <Text text="@{controller.label}" />
</Observe>
```

### ValueListenable

```xml
<Observe valueListenable="@{controller.count}" as="count">
  <Text text="@{count.toString()}" />
</Observe>
```

### Stream

```xml
<Observe stream="@{controller.events}" as="snapshot">
  <Text text="@{snapshot.data?.toString() ?? '等待中'}" />
</Observe>
```

它们会分别生成局部的 `ListenableBuilder`、`ValueListenableBuilder` 和
`StreamBuilder` 边界。

使用 `visible` 隐藏但保留子树；使用 `if` 按条件创建和销毁子树：

```xml
<CircularProgressIndicator if="@{controller.isSubmitting}" />
```

## 动态列表

SpokeML 提供构建 Widget 的通用机制，不实现具体分页方案。请求、游标、重试、去重和
滚动触发策略应由应用 Controller 或第三方组件负责。

命名 Builder slot 可以对接 Flutter 的懒加载 Widget：

```xml
<Observe listenable="@{controller}">
  <ListView.builder itemCount="@{controller.products.length}">
    <Builder name="itemBuilder" args="context,index">
      <Container
        key="@{ValueKey(controller.products[index].id)}"
        padding="16">
        <Text text="@{controller.products[index].name}" />
      </Container>
    </Builder>
  </ListView.builder>
</Observe>
```

Controller 追加商品并调用 `notifyListeners()` 后，只有列表区域重建，
`ListView.builder` 会继续按需创建新的列表项。稳定的 Key 用于保持列表项身份。

对于直接生成 `children` 的集合，可以使用 `ForEach`：

```xml
<Column>
  <ForEach
    items="@{products}"
    as="product"
    index="index"
    keyBy="@{product.id}">
    <Text text="@{product.name}" />
  </ForEach>
</Column>
```

## 布局组合

使用 `Include` 组合其他生成布局。相对路径以当前 XML 所在目录为基准，数据作为构造
参数向下传递：

```xml
<Include
  layout="./product_item.xml"
  product="@{product}"
  onTap="@{controller.openProduct}" />
```

被 Include 的布局会作为构建依赖进行跟踪，因此它发生变化时，依赖它的布局也会重新
生成。缺失或未知参数会在生成阶段被检查。

## 资源生命周期

变量默认由外部持有，由 Dart 父级负责创建和释放：

```dart
CalendarDemoView(calendar: calendarController)
```

当布局明确声明自己持有资源时，SpokeML 会生成一个轻量的 `StatefulWidget` Host，
同时让真正负责渲染的 View 继续保持无状态：

```xml
<variable
  name="controller"
  type="LoginController"
  import="package:my_app/login_controller.dart"
  ownership="owned"
  create="@{LoginController()}" />
```

对于名为 `LoginView` 的布局，使用生成的 `LoginViewHost`。Host 创建 Controller，
将其传给 `LoginView`，并在销毁时调用 Controller 的 `dispose()`。如果对象没有
`dispose()` 方法，可以添加 `dispose="none"`。

这种职责分离让 View 生成保持可预测：

```text
LoginViewHost（StatefulWidget：持有和释放资源）
└── LoginView（StatelessWidget：负责 XML 渲染）
```

## 第三方 Widget

将 XML namespace 前缀映射到 Dart library：

```xml
<layout
  class="CalendarDemoView"
  xmlns:table="package:table_calendar/table_calendar.dart">
  <data>
    <variable
      name="calendar"
      type="CalendarController"
      import="package:my_app/calendar_controller.dart" />
  </data>

  <table:TableCalendar
    firstDay="@{calendar.firstDay}"
    lastDay="@{calendar.lastDay}"
    focusedDay="@{calendar.focusedDay}"
    selectedDayPredicate="@{calendar.isSelected}"
    onDaySelected="@{calendar.selectDay}" />
</layout>
```

应用的 `pubspec.yaml` 中也必须声明对应依赖。SpokeML 会导入 namespace 映射的 Dart
library，并通过 analyzer 检查生成的构造调用。该能力已使用
[`table_calendar`](https://pub.dev/packages/table_calendar) 完成验证。

命名构造器或第三方组件需要位置参数时，使用连续的 `arg0`、`arg1` 属性：

```xml
<m:Image.asset
  arg0="@{video.thumbnailUrl}"
  fit="@{m.BoxFit.cover}" />
```

SpokeML 会按编号在命名参数之前生成位置参数，并检查参数数量与编号连续性。

使用 `Slot` 传递 `title`、`body`、`leading` 等命名 Widget 参数：

```xml
<m:Scaffold>
  <Slot name="body">
    <Text text="内容" />
  </Slot>
</m:Scaffold>
```

## 错误定位

当 Source Location 可用时，SpokeML 会将 XML 解析、Schema、构造函数、命名参数和
绑定错误定位到 XML 文件、行和列。

通过 SpokeML 执行 Dart 分析，可以把生成代码中的后续错误重映射回 XML：

```sh
dart run spoke_ml analyze
```

也可以只分析指定目录：

```sh
dart run spoke_ml analyze lib/generated
```

例如，生成 Dart 中的无效绑定可以被报告到其原始表达式：

```text
ERROR|COMPILE_TIME_ERROR|ARGUMENT_TYPE_NOT_ASSIGNABLE|
layouts/catalog/product_list.xml|10|36|10|...
```

Analyzer 的退出码保持不变。不存在 SpokeML Source Map 的诊断会原样输出。

Source Map 基于 Dart 构建工具实现，不依赖 Android 或 Apple 平台的运行时代码。因此
同一机制适用于 Android、iOS、macOS、Windows、Linux 和 Web 构建。

## 单文件编译

不使用 `build_runner` 时，也可以单独编译一个布局：

```sh
dart run spoke_ml layouts/profile.xml lib/generated/profile.g.dart
```

省略输出路径时，生成的 Dart 代码会输出到 stdout。

## 运行 Example

仓库中的可执行 Flutter example 展示了：

- 第三方 `TableCalendar` Widget；
- 有类型的 `ChangeNotifier` Controller；
- 局部监听的动态商品列表；
- 稳定列表项 Key 和懒加载 Builder；
- 自持有 Controller 的生命周期 Host；
- 一一对应的分组布局目录。

```sh
cd example
dart run build_runner build --delete-conflicting-outputs
flutter run
```

运行测试：

```sh
cd example
flutter test
```

构建平台应用：

```sh
cd example
flutter build apk --debug
flutter build macos --debug
```

## 当前能力范围

已实现：

- 常用 Flutter 布局、文本、按钮和进度 Widget；
- 字符串、数字、布尔值、枚举、颜色、Insets 和主题文字样式；
- 有类型的数据变量和 Dart 绑定表达式；
- 结构化 `if` 和不销毁状态的 `visible`；
- 局部 `Listenable`、`ValueListenable` 和 Stream 监听；
- 通用 `ForEach`、稳定 Key 和命名 Builder 回调；
- 通过 `Include` 使用相对路径组合布局；
- 外部持有和布局自持有两种资源生命周期；
- 第三方 Dart package namespace；
- 与 XML 一一对应的功能分组目录；
- XML 文件、行、列和表达式范围诊断；
- 基于 Analyzer 的构造函数与命名参数检查。

计划中或尚未完成：

- 对所有回调和表达式进行完整的静态类型检查；
- 覆盖所有 Flutter child 与 Builder slot 约定的丰富 Schema；
- XML 编辑器/LSP 中的实时诊断和代码补全；
- 更全面的内置 Widget 与值转换目录；
- 覆盖更多 Flutter 版本的兼容性和 Golden Test。

## 参与开发

提交修改前请运行：

```sh
flutter test
dart analyze
cd example && flutter test
```

生成的 `.g.dart` 被有意设计为可读代码。修改应保持正常 Flutter 语义，并避免把状态
管理策略放入编译器。

## 许可证

参见 [LICENSE](LICENSE)。
