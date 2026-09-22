import 'dart:async';

import 'package:flutter/material.dart';

/// 标记图的资源路径。
const String kBrandMarkAsset = 'assets/icons/glyph_mark.png';

/// 预热：把标记图**解码进 image cache**，供 `main()` 在 `runApp` 之前调用。
///
/// 不预热会闪一下：`Image.asset` 的解码是异步的，首帧拿到的是 `_image == null`，
/// `RenderImage` 于是按**宽度 0** 布局 —— 系统启动页的标记刚消失、
/// Flutter 这边还是空的，冷启动就出现"标记不见了一瞬"。
/// 这点耗时只是让原生启动页多停十几毫秒，肉眼看不到。
///
/// （测试里也要调，否则测出来标记宽度是 0，见 `test/splash_page_test.dart`）
Future<void> warmUpBrandMark() async {
  final stream = const AssetImage(kBrandMarkAsset)
      .resolve(ImageConfiguration.empty);
  final done = Completer<void>();
  late ImageStreamListener listener;
  listener = ImageStreamListener(
    (_, _) {
      if (!done.isCompleted) done.complete();
      stream.removeListener(listener);
    },
    // 加载失败也不能卡住启动：标记画不出来也得让用户进得去
    onError: (_, _) {
      if (!done.isCompleted) done.complete();
    },
  );
  stream.addListener(listener);
  await done.future;
}

/// 品牌标记 —— 与 App 图标**同一个图形母版**。
///
/// 母版链路（形状只在一处定义，其余全是派生）：
/// ```
/// AI 出图 keyhole_L
///   → _extract_glyph.py   抽成无色 alpha 形状母版  assets/icons/ic_glyph_white.png
///       ├→ make_icon.py        出 Android 图标（自适应 + legacy）
///       └→ make_glyph_mark.py  裁到外接框  assets/icons/glyph_mark.png  ← 本组件用的
/// ```
///
/// ⚠️ **不要在 Dart 里用 CustomPainter 再画一个"差不多的"**。踩过：
/// 启动页标记曾经是手画的"拱门+锁孔"，和图标是两个形状，一眼就是两个品牌。
/// 要改形状就改母版重跑脚本，图标/启动页/顶栏一起变。
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.height = 120,
    this.color = Colors.white,
  });

  /// 图形外接框高度（dp）。
  final double height;

  /// 着色。母版是纯白剪影，用 [BlendMode.srcIn] 换成任意色都不掉边。
  final Color color;

  /// 图形宽高比。母版裁切后固定，算水平占位用它，别另写魔数。
  static const double aspect = 475 / 538;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      kBrandMarkAsset,
      height: height,
      color: color,
      colorBlendMode: BlendMode.srcIn,
      filterQuality: FilterQuality.high,
    );
  }
}
