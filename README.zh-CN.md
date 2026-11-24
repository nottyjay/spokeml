<div align="center">

# SpokeML

**将 XML 布局编译为普通、可进行类型检查的 Flutter 代码**

[![star](https://gitee.com/nottyjay/spoke-ml/badge/star.svg?theme=dark)](https://gitee.com/nottyjay/spoke-ml/stargazers)
[![fork](https://gitee.com/nottyjay/spoke-ml/badge/fork.svg?theme=dark)](https://gitee.com/nottyjay/spoke-ml/members)
[![issue](https://gitee.com/nottyjay/spoke-ml/badge/issue.svg?theme=dark)](https://gitee.com/nottyjay/spoke-ml/issues)

![Dart](https://img.shields.io/badge/Dart-%5E3.10.4-0175C2?logo=dart&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.38.0-02569B?logo=flutter&logoColor=white)
![Status](https://img.shields.io/badge/status-proof%20of%20concept-orange)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Android%20%C2%B7%20iOS%20%C2%B7%20macOS%20%C2%B7%20Windows%20%C2%B7%20Linux%20%C2%B7%20Web-lightgrey)

[English](README.md) | [简体中文](README.zh-CN.md)

</div>

---

## 项目介绍

SpokeML 是一个实验性的 XML-to-Flutter 编译器。它允许 Flutter 应用使用声明式
XML 文件描述 Widget 树，同时继续使用普通 Dart 管理状态、业务逻辑和资源生命周期。

```text
layouts/account/login.xml
        │  build_runner
        ▼
lib/generated/account/login.g.dart     ← 普通 Flutter 源码
```

生成结果是可读、可进行类型检查的 Flutter 代码。发布后的应用不需要在运行时解析
XML，也不依赖动态 Widget 解释器 —— 一切都发生在编译期。

**工作流程：**

1. 在 `layouts/` 下的 XML 中声明 Widget 树，使用 `@{...}` 编写 Dart 绑定表达式；
2. `build_runner` 将每个 XML 文件编译为 `.g.dart` Widget —— 无状态渲染器，
   以及（当布局自持有资源时）一个轻量的 `StatefulWidget` Host；
3. 应用像使用普通手写 Widget 一样实例化生成的 View，并从 Dart 传入有类型的
   Controller。

SpokeML 尝试为 Flutter 提供类似 Android Data Binding 的开发流程，同时不放弃
Flutter 的优势：类型化代码、Tree Shaking 和现有状态管理生态全部保持可用。

> **项目状态：** SpokeML 目前处于方案验证阶段，还不是生产就绪的软件包。代码生成、
> Source Map、布局分组、局部状态边界、生命周期和第三方 Widget 接入均已有可执行
> 测试；example 也已在 Android 与 macOS 上完成编译和启动验证。

## 仓库统计

上方徽章为实时数据。下表为 **2026-11-24** 通过 Gitee API 获取的快照：

| 指标 | 数量 |
| --- | --- |
| ⭐ Star | 0 |
| 🍴 Fork | 0 |
| 👁 关注 | 1 |
| 🐛 开放 Issue | 0 |

📊 实时数据请查看 [Gitee 仓库主页](https://gitee.com/nottyjay/spoke-ml)。

## 功能亮点

| 功能 | 说明 |
| --- | --- |
| 🏗 声明式 XML | 常见 Flutter Widget（`Row`、`Column`、`Stack`、`Positioned`、`Align`、`Container`、`Padding`、`Center`、`SizedBox` 等）均为一等 XML 元素。 |
| 🔒 类型化绑定 | `@{...}` 表达式编译为有类型的 Dart 代码，不引入运行时字符串表达式引擎。 |
| 🎯 局部状态边界 | `Observe` 只重建监听中的子树，页面整体保持 `StatelessWidget`。 |
| 📋 懒加载集合 | `ForEach`、命名 Builder slot 和稳定 Key，支持 `ListView.builder` 等懒加载 Widget。 |
| 🧩 布局组合 | `Include` 通过相对路径组合布局，并校验参数。 |
| ♻️ 生命周期持有 | 通过生成的 `View` / `ViewHost` 支持外部持有和自持有两种资源生命周期。 |
| 📦 第三方 Widget | XML namespace 映射 Dart package，已用 `table_calendar` 验证。 |
| 🗺 XML Source Map | 生成阶段和后续 Dart 错误定位回 XML 文件、行、列和表达式范围。 |

## 示例手册

[`example/`](example/) 下的可运行 Flutter 应用演示了全部核心功能。每个 XML
布局与其生成输出路径一一对应。

| # | 示例 | 布局文件 | 演示内容 |
| --- | --- | --- | --- |
| 1 | [Profile](example/layouts/profile.xml) | `example/layouts/profile.xml` | 基础布局、简单值自动转换、`visible` |
| 2 | [Include](example/layouts/include_demo.xml) | `example/layouts/include_demo.xml` | 布局组合、参数转发 |
| 3 | [商品列表](example/layouts/catalog/product_list.xml) | `example/layouts/catalog/product_list.xml` | 局部监听、懒加载 `ListView.builder`、稳定 Key |
| 4 | [TableCalendar](example/layouts/calendar/table_calendar.xml) | `example/layouts/calendar/table_calendar.xml` | 通过 XML namespace 使用第三方 Widget |
| 5 | [自持有生命周期](example/layouts/lifecycle/calendar_owned.xml) | `example/layouts/lifecycle/calendar_owned.xml` | 自持有 Controller 与生成的 Host |

### 1. Profile —— 带条件的静态布局

`example/layouts/profile.xml` 渲染一个简单的资料卡片。简单属性（`width`、
`padding`、`color`、`height`、`textAlign`）自动转换；动态值使用 `@{...}` 绑定；
`visible` 在不销毁子树的前提下将其隐藏。

```xml
<layout class="ProfileView">
  <data>
    <variable name="user" />
    <variable name="form" />
    <variable name="controller" />
  </data>

  <Center>
    <Container width="420" padding="24" color="#F5F5F5">
      <Column mainAxisSize="min" crossAxisAlignment="stretch">
        <Text text="@{user.name}" style="headlineMedium" textAlign="center" />
        <SizedBox height="12" />
        <Text
          text="请确认资料后保存"
          textAlign="center"
          visible="@{form.showHint}" />
        <SizedBox height="24" />
        <ElevatedButton onPressed="@{controller.save}">
          <Text text="保存" />
        </ElevatedButton>
      </Column>
    </Container>
  </Center>
</layout>
```

生成输出：`example/lib/generated/profile.g.dart`。

### 2. Include —— 布局组合

`example/layouts/include_demo.xml` 组合上面的 Profile 布局并转发全部三个变量。
相对路径以当前 XML 所在目录为基准，被 Include 的布局会作为构建依赖被跟踪。

```xml
<layout class="IncludeDemoView">
  <data>
    <variable name="user" />
    <variable name="form" />
    <variable name="controller" />
  </data>

  <Include
    layout="./profile.xml"
    user="@{user}"
    form="@{form}"
    controller="@{controller}" />
</layout>
```

生成输出：`example/lib/generated/include_demo.g.dart`，它会导入并实例化生成的
`ProfileView`。

### 3. 商品列表 —— 局部监听与懒加载 Builder

`example/layouts/catalog/product_list.xml` 将 `Observe` 边界与
`ListView.builder` 结合。Controller 追加商品并调用 `notifyListeners()` 后，
只有列表区域重建，列表项按需懒加载创建。`ValueKey` 保持列表项身份稳定。

```xml
<layout class="ProductListView">
  <data>
    <variable
      name="controller"
      type="CatalogController"
      import="package:spoke_ml_example/catalog_controller.dart" />
  </data>

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
</layout>
```

Controller：`example/lib/catalog_controller.dart` —— 一个只追加数据的演示
`CatalogController`。生成输出：
`example/lib/generated/catalog/product_list.g.dart`。示例应用提供了一个每次
点击追加 5 个商品的按钮，可以实时观察局部区域的更新。

### 4. TableCalendar —— 第三方 Widget

`example/layouts/calendar/table_calendar.xml` 将 `table:` namespace 前缀映射到
`package:table_calendar/table_calendar.dart`。SpokeML 会导入该 library，通过
analyzer 校验生成的构造调用，并支持 `onDaySelected` 等回调。

```xml
<layout
  class="CalendarDemoView"
  xmlns:table="package:table_calendar/table_calendar.dart">
  <data>
    <variable
      name="calendar"
      type="CalendarController"
      import="package:spoke_ml_example/calendar_controller.dart" />
  </data>

  <Center>
    <Container width="420" padding="16" color="#F5F5F5">
      <Column mainAxisSize="min" crossAxisAlignment="stretch">
        <Text
          text="第三方 TableCalendar"
          style="titleLarge"
          textAlign="center" />
        <SizedBox height="12" />
        <Observe listenable="@{calendar}">
          <Column mainAxisSize="min" crossAxisAlignment="stretch">
            <table:TableCalendar
              firstDay="@{calendar.firstDay}"
              lastDay="@{calendar.lastDay}"
              focusedDay="@{calendar.focusedDay}"
              selectedDayPredicate="@{calendar.isSelected}"
              onDaySelected="@{calendar.selectDay}"
              rowHeight="48" />
            <SizedBox height="12" />
            <Text text="@{calendar.selectionLabel}" textAlign="center" />
          </Column>
        </Observe>
      </Column>
    </Container>
  </Center>
</layout>
```

Controller：`example/lib/calendar_controller.dart`。生成输出：
`example/lib/generated/calendar/table_calendar.g.dart`。纯 Dart 实现的
`table_calendar` package 在所有平台上无需额外插件配置。

### 5. 自持有生命周期 —— 生成的 Host

`example/layouts/lifecycle/calendar_owned.xml` 声明了一个自持有变量。SpokeML
会生成一个轻量的 `StatefulWidget` Host（`OwnedCalendarLabelViewHost`），由它
创建 Controller、传给无状态渲染器并在销毁时释放 —— 而
`OwnedCalendarLabelView` 本身始终保持 `StatelessWidget`。

```xml
<layout class="OwnedCalendarLabelView">
  <data>
    <variable
      name="calendar"
      type="CalendarController"
      import="package:spoke_ml_example/calendar_controller.dart"
      ownership="owned"
      create="@{CalendarController()}" />
  </data>

  <Observe listenable="@{calendar}">
    <Text text="@{calendar.selectionLabel}" />
  </Observe>
</layout>
```

生成输出：`example/lib/generated/lifecycle/calendar_owned.g.dart`。

### 运行 Example

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

example 已在 Flutter 3.38.5 下完成原生 Android APK 与原生 macOS Debug 应用的
编译和启动验证。

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

## 使用文档

- [布局目录和分组](#布局目录和分组) —— 输入输出目录一一对应
- [数据与表达式](#数据与表达式) —— 变量声明与 `@{...}` 绑定
- [静态页面与动态区域](#静态页面与动态区域) —— `Observe`、`if`、`visible`
- [动态列表](#动态列表) —— `ForEach`、Builder slot、稳定 Key
- [布局组合](#布局组合) —— `Include`
- [资源生命周期](#资源生命周期) —— 外部持有与自持有变量
- [第三方 Widget](#第三方-widget) —— namespace、位置参数、Slot
- [错误定位](#错误定位) —— XML Source Map 与 `spoke_ml analyze`
- [单文件编译](#单文件编译) —— 不使用 build_runner 编译单个文件

### 布局目录和分组

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

### 数据与表达式

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

### 静态页面与动态区域

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

**Listenable：**

```xml
<Observe listenable="@{controller}">
  <Text text="@{controller.label}" />
</Observe>
```

**ValueListenable：**

```xml
<Observe valueListenable="@{controller.count}" as="count">
  <Text text="@{count.toString()}" />
</Observe>
```

**Stream：**

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

### 动态列表

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

### 布局组合

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

### 资源生命周期

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

### 第三方 Widget

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

### 错误定位

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

### 单文件编译

不使用 `build_runner` 时，也可以单独编译一个布局：

```sh
dart run spoke_ml layouts/profile.xml lib/generated/profile.g.dart
```

省略输出路径时，生成的 Dart 代码会输出到 stdout。

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

SpokeML 基于 [MIT 许可证](LICENSE) 发布。

---

<div align="center">

⭐ 如果 SpokeML 对你有帮助，欢迎在
[Gitee](https://gitee.com/nottyjay/spoke-ml) 上点一个 Star，让更多人看到它。

</div>
