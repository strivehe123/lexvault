import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/word.dart';
import '../theme/app_theme.dart';

/// 单词配图。
/// - 有真实图片（assets/ 或 http）时显示图片；
/// - 无图片时使用与单词绑定的渐变 + 词性图标占位；
/// - [maskChinese] 为 true 时盖上紫色蒙版并显示中文（对应按 Space 的效果）；
/// - [status] 控制成功绿框 / 失败红框。
class WordImage extends StatelessWidget {
  final Word word;
  final double size;
  final double aspectRatio;
  final bool maskChinese;
  final ImageStatus status;

  const WordImage({
    super.key,
    required this.word,
    this.size = 240,
    this.aspectRatio = 1,
    this.maskChinese = false,
    this.status = ImageStatus.none,
  });

  static const _palettes = [
    [Color(0xFF7FA8FF), Color(0xFF5C6BD6)],
    [Color(0xFFFFB26B), Color(0xFFFF7E7E)],
    [Color(0xFF43CEA2), Color(0xFF185A9D)],
    [Color(0xFFB06AB3), Color(0xFF4568DC)],
    [Color(0xFFF6D365), Color(0xFFFDA085)],
    [Color(0xFF5EE7DF), Color(0xFF2B6FF5)],
    [Color(0xFFF093FB), Color(0xFF4B66F2)],
    [Color(0xFF84FAB0), Color(0xFF28A777)],
  ];

  List<Color> get _gradient {
    var h = word.word.hashCode;
    if (h < 0) h = -h;
    final a = _palettes[h % _palettes.length];
    final b = _palettes[(h ~/ 7) % _palettes.length];
    return [a[0], b[1]];
  }

  Color get _borderColor => switch (status) {
        ImageStatus.success => AppColors.success,
        ImageStatus.error => AppColors.error,
        _ => Colors.transparent,
      };

  @override
  Widget build(BuildContext context) {
    final image = word.image;
    Widget content;

    // 渐变占位图（无图或加载失败时使用）— 词卡风格
    Widget placeholder() {
      final g = _gradient;
      final firstLetter = word.word.isNotEmpty ? word.word[0].toUpperCase() : '?';
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: g,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 背景大字水印
            Center(
              child: Text(
                firstLetter,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.12),
                  fontSize: size * 0.75,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'serif',
                ),
              ),
            ),
            // 顶部斜切高光
            ClipPath(
              clipper: _DiagonalClipper(),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Colors.white.withValues(alpha: 0.18),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // 居中内容：单词 + 中文
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      word.word,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: size * 0.1,
                      ),
                    ),
                  ),
                  if (word.chinese.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      word.chinese,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                        fontSize: size * 0.07,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (image != null && image.isNotEmpty) {
      if (image.startsWith('http')) {
        content = Image.network(
          image,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) => placeholder(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return placeholder();
          },
        );
      } else {
        content = Image.asset(
          image,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) => placeholder(),
        );
      }
    } else {
      content = placeholder();
    }

    content = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          content,
          if (maskChinese)
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 0.6, sigmaY: 0.6),
              child: Container(
                color: AppColors.purpleMask,
                alignment: Alignment.center,
                child: Text(
                  word.chinese,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: size,
      height: size / aspectRatio,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _borderColor,
          width: status == ImageStatus.none ? 0 : 3,
        ),
        boxShadow: AppTheme.softShadow,
      ),
      child: content,
    );
  }
}

enum ImageStatus { none, success, error }

class _DiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.35, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
