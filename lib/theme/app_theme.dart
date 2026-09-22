import 'package:flutter/material.dart';

/// 与参考产品 REME AI 截图一致的配色与字体风格。
class AppColors {
  static const Color bg = Color(0xFFF5F8FD);
  static const Color card = Colors.white;
  static const Color ink = Color(0xFF1F2A44);
  static const Color inkSoft = Color(0xFF5E6B85);
  static const Color inkHint = Color(0xFF9AA6BD);

  static const Color primary = Color(0xFF3567F6);
  static const Color primaryDark = Color(0xFF274BDB);
  static const Color primarySoft = Color(0xFFE8EFFF);

  static const Color success = Color(0xFF1FC26A);
  static const Color successBg = Color(0xFFE9FAF1);
  static const Color error = Color(0xFFF04E5E);
  static const Color errorBg = Color(0xFFFDECEF);

  static const Color purpleMask = Color(0x885348B8);

  static const Color chipBorder = Color(0xFFE4E9F4);

  /// 品牌紫蓝渐变的两个端点。
  static const Color brandBlue = Color(0xFF4D7CFF);
  static const Color brandPurple = Color(0xFF6C5CE7);

  /// 启动页底色。
  ///
  /// ⚠️ 必须与 `android/app/src/main/res/values/colors.xml` 的
  /// `@color/splash_bg` **同值**，也要与 `windowSplashScreenBackground`
  /// 一致 —— 系统启动页 → Flutter 首帧的衔接全靠这个色相等，
  /// 差一点就会看到"底色跳一下"。
  static const Color splashBg = brandBlue;

  static const List<Color> primaryGradient = [brandBlue, brandPurple];
}

class AppTheme {
  static ThemeData build() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: Colors.white,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.bg,
      fontFamily: 'PingFang SC',
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      splashColor: AppColors.primarySoft,
    );
  }

  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(20));
  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(14));

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0xFF23304F).withValues(alpha: 0.06),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];
}
