import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart'; // FontLoader
import 'package:flutter_test/flutter_test.dart';
import 'package:vacmaster/pages/splash_page.dart';
import 'package:vacmaster/widgets/brand_mark.dart';

// ═══════════════════════════════════════════════════════════════════
// 启动页几何校验
//
// 启动页唯一的硬指标是：**标记落在屏幕正中的 120dp**。
// 因为系统启动页（Android 12+）只画那一个图标，位置尺寸由系统决定；
// Flutter 首帧的标记必须和它**重合**，否则交接的瞬间标记会跳一下。
//
// 所以这里不"看着差不多就行"，直接按 dp 断言。改布局跑这个测试，
// 过不了就是会跳。（真机逐帧对比见 tools/_splash_align_check.py）
// ═══════════════════════════════════════════════════════════════════

/// 真机参数（SM-S9060 / Android 16）：1080×2340 / density 2.625
const double kDpr = 2.625;
const Size kPhysical = Size(1080, 2340);
const double kScreenW = 1080 / 2.625; // 411.43 dp
const double kScreenH = 2340 / 2.625; // 891.43 dp

/// 与 `lib/pages/splash_page.dart` 同源的期望值
const double kMarkH = 120; // 系统启动页图标内容实测高
const double kMarkW = 120 * 475 / 538; // 母版宽高比
const double kK = 120 / 300; // 设计稿（1024² 画布）比例尺
const double kGapMark = 84 * kK - 3.5;
const double kGapTag = 56 * kK - 4.5;
const double kLineBottom = 119.5;
const double kLineW = 73.3;
const double kLineH = 1.5;

final _materialFonts =
    r'C:\flutter\bin\cache\artifacts\material_fonts';

/// 装上真字体再渲染。测试环境默认字体把所有字形画成方块，
/// 那样导出的渲染图看不出字号是否合适（几何对，但没法人工核对）。
Future<void> _loadRoboto() async {
  final loader = FontLoader('Roboto');
  for (final f in ['roboto-regular.ttf', 'roboto-bold.ttf']) {
    final p = File('$_materialFonts\\$f');
    if (p.existsSync()) {
      loader.addFont(Future.value(p.readAsBytesSync().buffer.asByteData()));
    }
  }
  await loader.load();
}

Future<void> _pump(WidgetTester tester, {GlobalKey? boundaryKey}) async {
  tester.view.physicalSize = kPhysical;
  tester.view.devicePixelRatio = kDpr;
  addTearDown(tester.view.reset);

  // 与 main() 同一条预热：不等它，Image 首帧拿不到图，宽度会是 0（真实存在的坑）
  await tester.runAsync(warmUpBrandMark);

  final app = MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto'),
    // ⚠️ 这层 Material 是为了让 Text 拿到主题字体。
    // Text 没有 Material 祖先时，DefaultTextStyle 走的是 WidgetsApp 的兜底样式
    // （不含 fontFamily），测试环境于是回落到"方块字体"，每字 1em ——
    // 导出的渲染图会看到字宽翻倍，误以为是排版错了。
    // 真机上没这个问题（family 为 null → 平台默认 Roboto）。
    home: const Material(type: MaterialType.transparency, child: SplashPage()),
  );
  await tester.pumpWidget(
    boundaryKey == null ? app : RepaintBoundary(key: boundaryKey, child: app),
  );
  await tester.pumpAndSettle(); // 等进场动画（320ms）跑完
}

void main() {
  setUpAll(_loadRoboto);

  testWidgets('标记：整屏居中、120dp 高 —— 与系统启动页重合', (tester) async {
    await _pump(tester);
    final r = tester.getRect(find.byKey(SplashPage.markKey));

    expect(r.height, closeTo(kMarkH, 0.5), reason: '高度必须等于系统启动页图标内容高');
    expect(r.width, closeTo(kMarkW, 0.5), reason: '宽度由母版宽高比决定');
    expect(r.center.dx, closeTo(kScreenW / 2, 0.5), reason: '水平正中');
    expect(r.center.dy, closeTo(kScreenH / 2, 0.5), reason: '垂直正中（系统就是画在屏幕中心）');
  });

  testWidgets('字标 / 副标：紧跟在标记下方，间距等于设计稿比例', (tester) async {
    await _pump(tester);
    final mark = tester.getRect(find.byKey(SplashPage.markKey));
    final title = tester.getRect(find.byKey(SplashPage.titleKey));
    final tag = tester.getRect(find.byKey(SplashPage.taglineKey));

    expect(title.top - mark.bottom, closeTo(kGapMark, 0.5));
    expect(tag.top - title.bottom, closeTo(kGapTag, 0.5));
    expect(title.center.dx, closeTo(kScreenW / 2, 0.5), reason: '整组水平居中');
    expect(tag.center.dx, closeTo(kScreenW / 2, 0.5));
    // 整组不能压到底部横线
    expect(tag.bottom < kScreenH - kLineBottom - 8, isTrue,
        reason: '文字与底部横线要保持距离');
  });

  testWidgets('底部横线：与 branding.png 同位同尺寸', (tester) async {
    await _pump(tester);
    final r = tester.getRect(find.byKey(SplashPage.lineKey));

    expect(r.height, closeTo(kLineH, 0.1));
    expect(r.width, closeTo(kLineW, 0.1));
    expect(kScreenH - r.bottom, closeTo(kLineBottom, 0.1), reason: '底沿距屏幕底 119.5dp');
    expect(r.center.dx, closeTo(kScreenW / 2, 0.1));
  });

  testWidgets('导出渲染图（真机像素，供人工核对）', (tester) async {
    final key = GlobalKey();
    await _pump(tester, boundaryKey: key);

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final img = await boundary.toImage(pixelRatio: kDpr);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });

    final out = File('logs/splash_flutter_1080x2340.png');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(bytes!);
    expect(out.lengthSync() > 3000, isTrue);
    debugPrint('渲染图 → ${out.absolute.path}');
  });
}
