import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 快捷键小标签，如 Enter / Space / R。
class KeyChip extends StatelessWidget {
  final String text;
  const KeyChip(this.text, {super.key, this.dark = false});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: dark ? Colors.white24 : const Color(0xFFF0F3FA),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: dark ? Colors.white38 : AppColors.chipBorder),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: dark ? Colors.white : AppColors.inkSoft,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

/// 蓝色渐变主按钮。
class GradientButton extends StatelessWidget {
  final String label;
  final String? keyLabel;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool green;
  final bool danger;
  final bool expanded;

  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.keyLabel,
    this.icon,
    this.green = false,
    this.danger = false,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final List<Color> colors;
    if (green) {
      colors = const [AppColors.success, Color(0xFF14A85C)];
    } else if (danger) {
      colors = const [AppColors.error, Color(0xFFD63B4A)];
    } else {
      colors = AppColors.primaryGradient;
    }
    final child = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (keyLabel != null) ...[
              const SizedBox(width: 10),
              KeyChip(keyLabel!, dark: true),
            ],
          ],
        ),
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: expanded ? SizedBox(width: double.infinity, child: Center(child: child)) : child,
      ),
    );
  }
}

/// 白底描边次按钮。
class GhostButton extends StatelessWidget {
  final String label;
  final String? keyLabel;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool danger;

  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.keyLabel,
    this.icon,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.error : AppColors.inkSoft;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: danger ? AppColors.error : AppColors.chipBorder),
            color: Colors.white,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: color), const SizedBox(width: 6)],
              Text(
                label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
              ),
              if (keyLabel != null) ...[const SizedBox(width: 8), KeyChip(keyLabel!)],
            ],
          ),
        ),
      ),
    );
  }
}

/// 脉冲光晕：包裹子组件，在其背后绘制一个呼吸放大的半透明圆角背景。
class PulseGlow extends StatefulWidget {
  final Widget child;
  final Color color;
  final double borderRadius;

  const PulseGlow({
    super.key,
    required this.child,
    this.color = AppColors.primary,
    this.borderRadius = 28,
  });

  @override
  State<PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<PulseGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  late final Animation<double> _scale =
      Tween<double>(begin: 1.0, end: 1.18).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  late final Animation<double> _alpha =
      Tween<double>(begin: 0.28, end: 0.06).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: _scale.value,
              child: Container(
                width: 230,
                height: 70,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: _alpha.value),
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}

/// 左右摇头动画。[tick] 变化时触发一次。
class ShakeBox extends StatefulWidget {
  final int tick;
  final Widget child;
  const ShakeBox({super.key, required this.tick, required this.child});

  @override
  State<ShakeBox> createState() => _ShakeBoxState();
}

class _ShakeBoxState extends State<ShakeBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    // 如果首次构建时 tick > 0，说明是从失败页切过来的，立即播放摇头动画
    if (widget.tick > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _c.forward(from: 0));
    }
  }

  @override
  void didUpdateWidget(covariant ShakeBox old) {
    super.didUpdateWidget(old);
    // 只有 tick 递增时才触发摇头（失败次数增加），tick 递减（重置）不触发
    if (widget.tick > old.tick) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (context, child) {
        final t = _a.value;
        // 衰减正弦：约 1.5 次来回摆动
        final dx = 18 * (1 - t) * math.sin(t * 3 * math.pi);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}

/// 顶部学习阶段进度条（学习阶段 / 强化阶段通用）。
class StageHeader extends StatelessWidget {
  final String stageLabel;
  final int current;
  final int total;
  final bool review;

  const StageHeader({
    super.key,
    required this.stageLabel,
    required this.current,
    required this.total,
    this.review = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _logo(),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: review ? const Color(0xFFFFF4E0) : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              stageLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: review ? const Color(0xFFB97A1E) : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: total == 0
                    ? 0
                    : (current / total).clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: const Color(0xFFE7ECF6),
                valueColor: AlwaysStoppedAnimation(
                  review ? const Color(0xFF2B6FF5) : AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${current > total ? total : current}/$total 词',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _logo() => Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4D7CFF), Color(0xFF6C5CE7)],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text('L',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 10),
          const Text('LexVault',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink)),
        ],
      );
}
