import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// GitHub 贡献图式的学习热力图。
///
/// 几何与配色对齐设计稿实测值：
/// - 格子近方形，**间隙 = 0.18 × 格径**、**圆角 = 0.17 × 格径**
/// - 四档配色：空 → 有学 → 过半 → 达标
/// - 图例靠**右下**（不是左下）
/// - 列按「周一到周日」排，首列一定是周一，左侧「一/三/五/日」才对得上行
///
/// ⚠️ 格子必须给**明确宽高**。上一版是
/// `Container(margin:…, decoration:…)` 塞进 `Row(spaceBetween)`，
/// 既没有 child 也没有 width → 固有宽度为 0 → 126 个格子一个都画不出来
/// （真机实测该区域非白像素 = 0，卡片是一片空白）。
/// 现在格径由 [LayoutBuilder] 解方程算出，再用 `SizedBox` 显式定尺寸；
/// `test/heatmap_card_test.dart` 钉着这条不许回退。
class HeatmapCard extends StatelessWidget {
  const HeatmapCard({
    super.key,
    required this.log,
    required this.dailyTarget,
    this.weeks = defaultWeeks,
    this.today,
  });

  /// 学习记录：`yyyy-MM-dd` → 当日学习词数。
  final Map<String, int> log;

  /// 每日目标。作为分档基准。
  final int dailyTarget;

  /// 展示周数。14 周 ≈ 三个半月，格子能撑到 ~19dp，再多就看不清了。
  final int weeks;

  /// 注入「今天」，便于测试与截图。
  final DateTime? today;

  static const int defaultWeeks = 14;
  static const int daysPerWeek = 7;

  /// 四档配色，取自设计稿图例。
  static const List<Color> ramp = [
    Color(0xFFEEF1F8), // 0 没学
    Color(0xFFC7D4F8), // 1 学了
    Color(0xFF8FA9F5), // 2 过半
    Color(0xFF4F6DF5), // 3 达标
  ];

  /// 星期标签只在 1/3/5/7 行显示（GitHub 惯例）。
  static const List<String> _dowLabels = ['一', '', '三', '', '五', '', '日'];

  static const double _gapRatio = 0.18;
  static const double _radiusRatio = 0.17;
  static const double _labelWidth = 16;
  static const double _labelGap = 6;
  static const double _legendSwatch = 11;

  @override
  Widget build(BuildContext context) {
    final now = DateUtils.dateOnly(today ?? DateTime.now());
    // 末列对齐到「本周周日」，再往前推 weeks 周 → 首列必然是周一。
    // 若直接取"最近 N 天"顺序切列，列与星期几是错位的，左侧标签就是假信息。
    final lastDay = now.add(Duration(days: DateTime.sunday - now.weekday));
    final firstDay =
        lastDay.subtract(Duration(days: weeks * daysPerWeek - 1));

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('学习活动',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('近 $weeks 周',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final gridWidth =
                  constraints.maxWidth - _labelWidth - _labelGap;
              // 解 weeks·cell + (weeks-1)·ratio·cell = gridWidth
              final cell = gridWidth / (weeks + (weeks - 1) * _gapRatio);
              final gap = cell * _gapRatio;
              final radius = cell * _radiusRatio;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 星期标签列：逐行用「与格子等高」的盒子对齐。
                  // 用 spaceBetween 是按文字高度均分，中心跟格子对不上。
                  SizedBox(
                    width: _labelWidth,
                    child: Column(
                      children: [
                        for (var d = 0; d < daysPerWeek; d++) ...[
                          SizedBox(
                            height: cell,
                            child: _dowLabels[d].isEmpty
                                ? null
                                : Center(
                                    child: Text(_dowLabels[d],
                                        style: const TextStyle(
                                            fontSize: 10,
                                            height: 1,
                                            color: AppColors.inkSoft)),
                                  ),
                          ),
                          if (d < daysPerWeek - 1) SizedBox(height: gap),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: _labelGap),
                  // 网格：每格显式给宽高
                  Column(
                    children: [
                      for (var d = 0; d < daysPerWeek; d++) ...[
                        Row(
                          children: [
                            for (var w = 0; w < weeks; w++) ...[
                              SizedBox(
                                key: ValueKey('cell-$w-$d'),
                                width: cell,
                                height: cell,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: ramp[
                                        _level(_valueAt(now, firstDay, w, d))],
                                    borderRadius: BorderRadius.circular(radius),
                                  ),
                                ),
                              ),
                              if (w < weeks - 1) SizedBox(width: gap),
                            ],
                          ],
                        ),
                        if (d < daysPerWeek - 1) SizedBox(height: gap),
                      ],
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('少',
                  style: TextStyle(fontSize: 11, color: AppColors.inkSoft)),
              const SizedBox(width: 8),
              for (var i = 0; i < ramp.length; i++) ...[
                Container(
                  width: _legendSwatch,
                  height: _legendSwatch,
                  decoration: BoxDecoration(
                    color: ramp[i],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                if (i < ramp.length - 1) const SizedBox(width: 4),
              ],
              const SizedBox(width: 8),
              const Text('多',
                  style: TextStyle(fontSize: 11, color: AppColors.inkSoft)),
            ],
          ),
        ],
      ),
    );
  }

  int _valueAt(DateTime today, DateTime firstDay, int w, int d) {
    final date = firstDay.add(Duration(days: w * daysPerWeek + d));
    // 还没到那天 —— 一律算「没学」。
    // 正常数据不会有未来记录（studyLog 只写当天），但时钟回拨/脏数据时
    // 不该在图上冒出"未来已经学过"的格子。
    if (date.isAfter(today)) return 0;
    return log[date.toIso8601String().substring(0, 10)] ?? 0;
  }

  /// 分档基准用**每日目标**，不用历史最大值。
  ///
  /// 用 max 的话，某天一旦爆量（比如复习日刷了 60 个），其余天会被全部
  /// 压到最浅档、整张图发白 —— 这是量化分档的经典坑。目标值稳定且对用户
  /// 有意义（"哪天达标了"），比相对最大值更好读。
  int _level(int v) {
    if (v <= 0) return 0;
    if (dailyTarget <= 0) return 1;
    if (v >= dailyTarget) return 3;
    if (v * 2 >= dailyTarget) return 2;
    return 1;
  }
}
