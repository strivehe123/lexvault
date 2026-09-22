import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/sound_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// 打开"音效自检"面板（长按首页左上角 Logo 触发）。
///
/// 为什么要有这个面板：这台荣耀平板连不上 adb，`logcat` / `flutter run` /
/// 截图全用不了，遇到"拼写时没有音效"这种问题根本没日志可看。
/// 与其隔着一台看不见日志的设备猜，不如把状态和试听按钮直接摆到屏幕上：
/// 谁拿着设备都能当场分辨是"代码没响（状态里能看出来）"还是
/// "平板媒体音量是 0（状态正常，但点按钮也没声音）"。
Future<void> showSoundCheckDialog(BuildContext context) {
  final sounds = context.read<AppState>().sounds;
  return showDialog<void>(
    context: context,
    builder: (_) => _SoundCheckDialog(sounds: sounds),
  );
}

class _SoundCheckDialog extends StatefulWidget {
  final SoundService sounds;
  const _SoundCheckDialog({required this.sounds});

  @override
  State<_SoundCheckDialog> createState() => _SoundCheckDialogState();
}

class _SoundCheckDialogState extends State<_SoundCheckDialog> {
  /// 播一个音，播完刷新统计（次数会变，不刷新看着像没反应）。
  Future<void> _play(Future<void> Function() play) async {
    await play();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sounds;
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: const Row(
        children: [
          Icon(Icons.graphic_eq_rounded, size: 20, color: AppColors.primary),
          SizedBox(width: 8),
          Text('音效自检', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                s.diagnose(),
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.6,
                  fontFamily: 'monospace',
                  color: AppColors.inkSoft,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text('点一下试听，音效应当立刻响',
                style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _button('成功音', s.success),
                _button('错误音', s.error),
                _button('按键音', s.tick),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              '三个都听不到 → 先按平板音量键，确认「媒体音量」不是 0，'
              '并检查是否开了静音；只有按键音听不到 → 把上面这份状态发我。',
              style: TextStyle(fontSize: 11, height: 1.5, color: AppColors.inkHint),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Widget _button(String label, Future<void> Function() play) {
    return FilledButton.tonal(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primarySoft,
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      onPressed: () => _play(play),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}
