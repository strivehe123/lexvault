import 'package:audioplayers/audioplayers.dart';

/// 成功 / 失败 / 字母正确 三种提示音。
class SoundService {
  final AudioPlayer _success = AudioPlayer();
  final AudioPlayer _error = AudioPlayer();
  final AudioPlayer _tick = AudioPlayer();

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    await Future.wait([
      _success.setSource(AssetSource('sounds/success.wav')),
      _error.setSource(AssetSource('sounds/error.wav')),
      _tick.setSource(AssetSource('sounds/tick.wav')),
    ]);
    for (final p in [_success, _error, _tick]) {
      await p.setReleaseMode(ReleaseMode.stop);
    }
    // 错误音整体再降一档，温和不刺耳
    await _error.setVolume(0.45);
    _ready = true;
  }

  Future<void> _play(AudioPlayer player) async {
    try {
      await player.seek(Duration.zero);
      await player.resume();
    } catch (_) {
      // 音效失败不影响学习流程
    }
  }

  Future<void> success() => _play(_success);
  Future<void> error() => _play(_error);
  Future<void> tick() => _play(_tick);

  Future<void> dispose() async {
    await _success.dispose();
    await _error.dispose();
    await _tick.dispose();
  }
}
