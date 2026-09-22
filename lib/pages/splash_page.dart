import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/brand_mark.dart';

// ═══════════════════════════════════════════════════════════════════
// 为什么要有这一页
//
// Android 12+ 换了系统启动页机制：只画 **背景色 + 一个图标**，
// `windowSplashScreenAnimatedIcon` 之外的东西（字标、tagline）一律不显示。
// 工程里 launch_background.xml 那套完整版式（splash.png 含 logo+字标+副标）
// 在 12+ 上**根本不参与绘制** —— 真机冷启动连拍 8 帧验证过：
// 只有标记和底部横线，没有任何文字。
//
// 所以字标必须由 Flutter 首帧来补。这一页就是那一帧。
//
// 版式的硬约束：**标记必须落在系统启动页的同一个位置、同一个尺寸**。
// 实测（SM-S9060 / Android 16 / 1080×2340 / density 2.625）：
//   系统把图标画在 288dp 画布内，内容高 120.4dp、宽 106.3dp，
//   中心正好压在屏幕中心（实测 1169.5 vs 1170），水平正中。
// 于是这里：标记高 [_markH]、整屏居中。**系统启动页消失时标记一动都不动**，
// 观感是"字浮出来"，而不是"换了一屏"。
//
// 三个数字都不能随手改，改了就会出现"启动页跳一下"。
// ═══════════════════════════════════════════════════════════════════

/// 标记外接框高度 —— 系统启动页图标内容的实测高度（120.4dp）。**别改。**
const double _markH = 120;

/// 设计稿比例尺：版式全部取自 `make_splash.py` 的 1024² 画布（那里 `MARK_H = 300`）。
/// 所有字号/间距都按"设计像素 × _k"换算，改标记大小整组等比跟着走。
const double _k = _markH / 300;

/// 标记下沿 → 字标。设计值 84，再减掉 Flutter 文本框比 PIL ink 框多出的那半截
/// （字号 46.4 的框比字形高约 0.14×，上下各多 0.07 → ≈3.3dp）
const double _gapMark = 84 * _k - 3.5;

/// 字标字号（设计 116）。
const double _titleSize = 116 * _k;

/// 字标下沿 → 副标。设计值 56；同样减掉字标下缘与副标上缘各自的框-字形差。
const double _gapTag = 56 * _k - 4.5;

/// 副标字号（设计 40）。
const double _tagSize = 40 * _k;

/// 底部细横线：与 Android 端 branding.png 同位同尺寸
/// （细横线底沿距屏幕底 119.5dp，宽 73.3dp、高 1.5dp，右端约 3.3dp 渐隐）。
const double _lineBottom = 119.5;
const double _lineW = 73.3;
const double _lineH = 1.5;
const double _lineSolidW = 70;

/// LexVault 品牌启动页（Flutter 首帧）
///
/// 用法：初始化没跑完时先显示它，跑完再换首页（见 `main.dart`）。
/// 它自己不做任何加载 —— 纯展示，所以能立刻出现在首帧上。
class SplashPage extends StatelessWidget {
  const SplashPage({super.key, this.tagline = 'Build your word vault.'});

  final String tagline;

  /// 测试锚点：几何校验要按名字取到这几个元素（见 `test/splash_page_test.dart`）
  static const markKey = ValueKey('splash.mark');
  static const titleKey = ValueKey('splash.title');
  static const taglineKey = ValueKey('splash.tagline');
  static const lineKey = ValueKey('splash.line');

  @override
  Widget build(BuildContext context) {
    // 状态栏图标用浅色（白），底色是深蓝紫 —— 系统启动页也是这样
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      // 不用 Scaffold：要的是"整屏"坐标系。
      // Scaffold 的 body 会被状态栏/导航栏内边距影响，标记就对不准系统启动页了。
      child: ColoredBox(
        color: AppColors.splashBg,
        child: LayoutBuilder(
          builder: (context, c) {
            final textTop = c.maxHeight / 2 + _markH / 2 + _gapMark;
            return Stack(
              children: [
                // ① 标记：整屏居中，与系统启动页逐像素对齐
                const Positioned.fill(
                  child: Center(
                    child: BrandMark(key: markKey, height: _markH),
                  ),
                ),

                // ② 字标 + 副标：从标记下方浮出
                //    起始 opacity 0 —— 交接那一瞬屏幕上只有标记，
                //    正是系统启动页的画面，所以看不出切换
                Positioned(
                  top: textTop,
                  left: 0,
                  right: 0,
                  child: _Lockup(tagline: tagline),
                ),

                // ③ 底部细横线（与 branding.png 对齐）
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: _lineBottom,
                  child: Center(child: _BrandLine(key: lineKey)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 字标 + 副标。进场只做一次淡入 + 微上浮，不做循环动画
/// （`TweenAnimationBuilder` 首帧自动跑一遍，不需要 controller）。
class _Lockup extends StatelessWidget {
  const _Lockup({required this.tagline});

  final String tagline;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 14),
          child: child,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'LexVault',
            key: SplashPage.titleKey,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _titleSize,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.0,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: _gapTag),
          Text(
            tagline,
            key: SplashPage.taglineKey,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _tagSize,
              fontWeight: FontWeight.w400,
              // 白 85%：压在 #4D7CFF 上 3.13:1，过大字线 3:1。
              // 纯白 70% 只有 2.62:1，真机上看着发灰发虚。
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.2,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// 底部细横线 —— 精确复刻 Android 端 `branding.png` 的画法：
/// 左边一段实线，右端收一个渐隐的尾巴。
class _BrandLine extends StatelessWidget {
  const _BrandLine({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: _lineW,
      height: _lineH,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _lineSolidW,
            child: ColoredBox(color: Colors.white),
          ),
          Positioned(
            left: _lineSolidW,
            right: 0,
            top: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.white, Color(0x00FFFFFF)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
