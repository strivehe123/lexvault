import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/word_book.dart';
import '../state/app_state.dart';

class CompletePage extends StatelessWidget {
  final WordBook book;
  final int correct;
  final int total;

  const CompletePage({
    super.key,
    required this.book,
    required this.correct,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final rounds = context.watch<AppState>().progress.rounds(book.id);
    final rate = total == 0 ? 100 : (correct * 100 / total).round();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _Starfield(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                size: 13, color: Color(0xFF7BE0B0)),
                            SizedBox(width: 5),
                            Text('练习完成',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF7BE0B0),
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF9EC5FF), Color(0xFF7A5AF8)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7A5AF8).withValues(alpha: 0.5),
                        blurRadius: 40,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 46),
                ),
                const SizedBox(height: 24),
                const Text('练习完成',
                    style: TextStyle(
                        fontSize: 26, color: Colors.white, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(
                  '坚持就是胜利，每一步都在悄悄进步。',
                  style: TextStyle(
                      fontSize: 13, color: Colors.white.withValues(alpha: 0.65)),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StatCard(
                      icon: Icons.shuffle_rounded,
                      iconColor: const Color(0xFF7BE0B0),
                      value: '$rounds',
                      label: '练习轮次',
                    ),
                    const SizedBox(width: 14),
                    _StatCard(
                      icon: Icons.local_fire_department_rounded,
                      iconColor: const Color(0xFFFFC26B),
                      value: '$rate%',
                      label: '完成率',
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF36D1DC), Color(0xFF7A5AF8)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: TextButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  duration: Duration(seconds: 1),
                                  content: Text('分享图功能占位，后续接入'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.share_rounded, color: Colors.white, size: 17),
                            label: const Text('分享打卡成果',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: TextButton(
                            onPressed: () => Navigator.of(context)
                                .popUntil((route) => route.isFirst),
                            child: const Text('返回首页',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
        ],
      ),
    );
  }
}

/// 星空 + 星云背景。
class _Starfield extends StatefulWidget {
  const _Starfield();

  @override
  State<_Starfield> createState() => _StarfieldState();
}

class _StarfieldState extends State<_Starfield> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        painter: _SkyPainter(_c.value),
        size: Size.infinite,
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  final double t;
  _SkyPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0B1026), Color(0xFF171C3A), Color(0xFF241B3D)],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    // 星云光斑
    final nebulae = [
      (Offset(size.width * 0.22, size.height * 0.72), 260.0, const Color(0xFF1E6FE0)),
      (Offset(size.width * 0.78, size.height * 0.66), 300.0, const Color(0xFF7A3FF2)),
      (Offset(size.width * 0.55, size.height * 0.82), 220.0, const Color(0xFFB5542E)),
    ];
    for (final n in nebulae) {
      final p = Paint()
        ..shader = RadialGradient(colors: [
          n.$3.withValues(alpha: 0.32),
          n.$3.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: n.$1, radius: n.$2));
      canvas.drawCircle(n.$1, n.$2, p);
    }

    // 星星（确定性伪随机，随时间缓慢闪烁）
    final rnd = math.Random(42);
    final starPaint = Paint()..color = Colors.white;
    for (var i = 0; i < 130; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final r = rnd.nextDouble() * 1.3 + 0.3;
      final twinkle = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * 2 * math.pi + i));
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = Colors.white.withValues(alpha: twinkle * 0.85),
      );
    }
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.18),
      1.6,
      starPaint..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant _SkyPainter oldDelegate) => oldDelegate.t != t;
}
