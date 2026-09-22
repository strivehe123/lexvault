import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vacmaster/theme/app_theme.dart';
import 'package:vacmaster/widgets/heatmap_card.dart';

/// 真机 SM-S9060：1080×2340 @2.625 → 411.43 × 891.43 dp
const Size kPhysical = Size(1080, 2340);
const double kDpr = 2.625;

/// 注入固定的"今天"，让日期 → 格子的映射可确定地断言。
/// 2026-09-22 是周二（真机截图那天）。
final DateTime kToday = DateTime(2026, 9, 22);

/// 与 HomePage 同构的 widget 树：
/// ListView(padding 16/16) → HeatmapCard(padding 20/20)。
/// ⚠️ 必须走 MaterialApp + Scaffold —— 上一版启动页的教训是
/// "测试的 widget 树跟真机不是同一棵"，结果漏掉了 Text 缺 Material
/// 祖先导致的黄双下划线。这里不给 Text 留任何兜底路径。
Future<void> _pump(WidgetTester tester, Map<String, int> log,
    {int target = 5, double width = 1080}) async {
  tester.view.physicalSize = Size(width, 2340);
  tester.view.devicePixelRatio = kDpr;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.build(),
    home: Scaffold(
      backgroundColor: AppColors.bg,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          HeatmapCard(log: log, dailyTarget: target, today: kToday),
        ],
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Size _cellSize(WidgetTester tester, int w, int d) =>
    tester.getSize(find.byKey(ValueKey('cell-$w-$d')));

Color _cellColor(WidgetTester tester, int w, int d) {
  final box = tester.widget<DecoratedBox>(find.descendant(
    of: find.byKey(ValueKey('cell-$w-$d')),
    matching: find.byType(DecoratedBox),
  ));
  return (box.decoration as BoxDecoration).color!;
}

void main() {
  // 2026-09-21 是周一 → 末列 d=0 是周一，d=1 是今天（9-22 周二）
  const monday = '2026-09-21';
  const tomorrow = '2026-09-23';

  testWidgets('① 126/98 个格子全部有真实尺寸（钉死"0 宽"回归）', (tester) async {
    await _pump(tester, const {});

    const weeks = HeatmapCard.defaultWeeks; // 14
    const days = HeatmapCard.daysPerWeek; // 7

    for (var w = 0; w < weeks; w++) {
      for (var d = 0; d < days; d++) {
        expect(find.byKey(ValueKey('cell-$w-$d')), findsOneWidget,
            reason: '格子 $w-$d 没渲染出来');
        final s = _cellSize(tester, w, d);
        // 上一版的 bug：宽 = 0，卡片整片空白
        expect(s.width, greaterThan(10),
            reason: '格子 $w-$d 宽度只有 ${s.width}，等于没画出来');
        expect(s.height, greaterThan(10), reason: '格子 $w-$d 太矮');
        expect(s.width, equals(s.height),
            reason: '格子 $w-$d 不是正方形：${s.width}×${s.height}');
      }
    }
  });

  testWidgets('② 所有格子尺寸一致，且间隙 = 0.18 × 格径', (tester) async {
    await _pump(tester, const {});

    final base = _cellSize(tester, 0, 0);
    for (var w = 0; w < HeatmapCard.defaultWeeks; w++) {
      for (var d = 0; d < HeatmapCard.daysPerWeek; d++) {
        expect(_cellSize(tester, w, d), base, reason: '格子 $w-$d 尺寸不一致');
      }
    }

    // 用相邻两格的左上角反推间隙 —— 不引用组件里的常量，独立算
    final x0 = tester.getTopLeft(find.byKey(const ValueKey('cell-0-0'))).dx;
    final x1 = tester.getTopLeft(find.byKey(const ValueKey('cell-1-0'))).dx;
    final gap = (x1 - x0) - base.width;
    expect(gap, greaterThan(0), reason: '格子挨在一起了，没有间隙');
    expect(gap / base.width, closeTo(0.18, 0.02),
        reason: '间隙/格径 = ${(gap / base.width).toStringAsFixed(3)}，设计稿是 0.18');

    final y0 = tester.getTopLeft(find.byKey(const ValueKey('cell-0-0'))).dy;
    final y1 = tester.getTopLeft(find.byKey(const ValueKey('cell-0-1'))).dy;
    expect((y1 - y0) - base.height, closeTo(gap, 0.01), reason: '纵向间隙 ≠ 横向间隙');
  });

  testWidgets('③ 星期标签与对应行垂直居中', (tester) async {
    await _pump(tester, const {});

    // 一/三/五/日 分别在第 1/3/5/7 行
    for (final (label, row) in const [('一', 0), ('三', 2), ('五', 4), ('日', 6)]) {
      final labelY = tester.getCenter(find.text(label)).dy;
      final cellY = tester.getCenter(find.byKey(ValueKey('cell-0-$row'))).dy;
      expect((labelY - cellY).abs(), lessThan(1.0),
          reason: '「$label」与第 ${row + 1} 行没对齐（差 ${labelY - cellY}）');
    }
  });

  testWidgets('④ 列对齐到周一起（左侧标签不是假信息）', (tester) async {
    // 末列 d=0 应为周一 2026-09-21
    await _pump(tester, const {
      monday: 1, // → 第 1 档
      tomorrow: 5, // 未来日期，不该出现在图上
    });

    expect(_cellColor(tester, 13, 0), HeatmapCard.ramp[1],
        reason: '末列第 1 行不是周一');
    // d=2 起是未来（今天 9-22 是 d=1）→ 一律第 0 档
    expect(_cellColor(tester, 13, 2), HeatmapCard.ramp[0], reason: '未来日期不该有色');
    expect(_cellColor(tester, 13, 6), HeatmapCard.ramp[0], reason: '未来日期不该有色');
  });

  testWidgets('⑤ 四档分档：0 / 有学 / 过半 / 达标', (tester) async {
    await _pump(
      tester,
      const {
        '2026-09-20': 0, // 周日，末列上一周 d=6 → 没学
        '2026-09-19': 1, // 周六 d=5 → 1/5 = 20% → 第 1 档
        '2026-09-18': 3, // 周五 d=4 → 3/5 = 60% ≥ 50% → 第 2 档
        '2026-09-17': 5, // 周四 d=3 → 达标 → 第 3 档
        '2026-09-16': 9, // 周三 d=2 → 超额也算达标 → 第 3 档
      },
      target: 5,
    );

    expect(_cellColor(tester, 12, 6), HeatmapCard.ramp[0]);
    expect(_cellColor(tester, 12, 5), HeatmapCard.ramp[1]);
    expect(_cellColor(tester, 12, 4), HeatmapCard.ramp[2]);
    expect(_cellColor(tester, 12, 3), HeatmapCard.ramp[3]);
    expect(_cellColor(tester, 12, 2), HeatmapCard.ramp[3]);
  });

  testWidgets('⑥ 目标为 0 或异常时不崩、不出现非法颜色', (tester) async {
    await _pump(tester, const {monday: 3}, target: 0);
    expect(_cellColor(tester, 13, 0), HeatmapCard.ramp[1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('⑦ 窄屏（320dp）不溢出', (tester) async {
    await _pump(tester, const {}, width: 320 * 2.625);
    expect(tester.takeException(), isNull);
    final s = _cellSize(tester, 0, 0);
    expect(s.width, greaterThan(6), reason: '窄屏格子太小：${s.width}');
    expect(s.width, equals(s.height));
  });

  testWidgets('⑧ 导出渲染图（真机像素，供人工核对）', (tester) async {
    final key = GlobalKey();
    tester.view.physicalSize = kPhysical;
    tester.view.devicePixelRatio = kDpr;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: RepaintBoundary(
        key: key,
        child: Scaffold(
          backgroundColor: AppColors.bg,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              HeatmapCard(
                log: const {
                  '2026-09-21': 1,
                  '2026-09-19': 1,
                  '2026-09-18': 3,
                  '2026-09-17': 5,
                  '2026-09-16': 9,
                  '2026-09-15': 2,
                  '2026-09-13': 4,
                  '2026-09-11': 1,
                  '2026-09-09': 5,
                  '2026-09-06': 3,
                  '2026-09-03': 5,
                },
                dailyTarget: 5,
                today: kToday,
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final img = await boundary.toImage(pixelRatio: kDpr);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });

    final out = File('logs/heatmap_1080x2340.png');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(bytes!);
    expect(out.lengthSync() > 2000, isTrue);
    debugPrint('渲染图 → ${out.absolute.path}');
  });
}
