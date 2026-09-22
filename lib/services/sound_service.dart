import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 成功 / 失败 / 按键 三种提示音。
///
/// ⚠️ 这个文件里有两处真机踩出来的坑，改动之前务必读完，很容易踩回去。
///
/// **坑 1：重播只能用 `stop()` + `resume()`，绝对不许用 `seek(Duration.zero)`。**
///
/// `AudioPlayer.seek()` 的内部实现是：
///
/// ```dart
/// final futureSeekComplete =
///     onSeekComplete.first.timeout(AudioPlayer.seekingTimeout);  // 默认 30 秒
/// await Future.wait([futureSeek, futureSeekComplete]);
/// ```
///
/// 而 Android 侧的 `MediaPlayer` 在**已暂停、且当前播放位置本来就是 0** 时
/// 不会再回调 `onSeekComplete`。偏偏每次按键都正好落在这个状态上——上一声播完时
/// 原生 `WrappedPlayer.onCompletion()` 已经调过 `stop()`，而 `stop()` 内部就
/// 把位置 `seekTo(0)` 了。
///
/// 于是那次 `await` 要**挂满 30 秒**才抛 `TimeoutException`。又因为原先是
/// "先 seek 再 resume"的串行写法，seek 一抛，resume 永远轮不到执行——
/// 结果是**一声都出不来**，还被 `catch (_) {}` 悄悄吞掉，日志里干干净净。
///
/// 真机表现就是最坑的那种：**某些机型（荣耀 / 华为平板）完全没有音效，
/// 换一台手机却一切正常**，代码看起来还人畜无害。
///
/// 正确做法是 `stop()` + `resume()`：原生 `stop()` 自己会做 pause + seekTo(0)，
/// 走的是原生同步路径，不经过 Dart 那层 seek 超时。
///
/// **坑 2：必须显式给 `AudioContext`，且 `audioFocus` 用 `none`。**
///
/// audioplayers 的默认值是 `AUDIOFOCUS_GAIN`——每响一声都要抢一次音频焦点。
/// 而拼写页同时还在用 TTS 读单词，两边来回抢焦点，提示音就会被吞掉。
/// 提示音本来也不该抢焦点，跟 TTS 混音共存才对。
///
/// 素材侧另有一个问题：`tick.wav` 原始峰值只有 0.2 满刻度（-14 dBFS）、
/// 时长 50ms 且结尾硬切，平板外放上基本等于静音。已在
/// `tools/normalize_sfx.py` 里统一归一到 0.9 FS 并补了收尾淡出，
/// 回归测试见 `test/sound_assets_test.dart`。
class SoundService {
  /// 提示音走 media 音量（用户按音量键调的就是这一路），
  /// 内容类型标成 sonification——"伴随用户操作的一声提示"，
  /// 不参与音乐流的 ducking 判定。
  /// `audioFocus: none` = 不抢焦点，与 TTS 混音共存（见坑 2）。
  static final AudioContext _ctx = AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: false,
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  final _Sfx _success = _Sfx('成功音', 'sounds/success.wav', volume: 1.0);
  final _Sfx _error = _Sfx('错误音', 'sounds/error.wav', volume: 0.6);
  final _Sfx _tick = _Sfx('按键音', 'sounds/tick.wav', volume: 0.6);

  /// `_success/_error/_tick` 必须先声明，这里才能引用到它们。
  late final List<_Sfx> _all = [_success, _error, _tick];

  bool _ready = false;

  /// 初始化是否成功。自检面板会显示它。
  bool get ready => _ready;

  /// 初始化失败原因，正常为 null。
  String? initError;

  /// 累计成功播出的次数。点了很多下字母却始终是 0，就说明真的没响。
  int get playCount => _all.fold(0, (sum, s) => sum + s.plays);

  /// 真机自检用：把音效子系统的状态摊平成几行文本。
  ///
  /// 这台荣耀平板连不上 adb，`logcat` / `flutter run` 全用不了，
  /// "没声音"这类问题没法看日志——所以把状态直接摆到屏幕上。
  String diagnose() {
    final buffer = StringBuffer()
      ..writeln('初始化：${_ready ? '成功' : '未完成或失败'}')
      ..writeln('累计播出：$playCount 次');
    if (initError != null) {
      buffer.writeln('初始化报错：$initError');
    }
    for (final sfx in _all) {
      buffer.writeln(
        '${sfx.name}：${sfx.error == null ? '正常（已播 ${sfx.plays} 次）' : '失败 → ${sfx.error}'}',
      );
    }
    return buffer.toString();
  }

  Future<void> init() async {
    if (_ready) return;
    try {
      for (final sfx in _all) {
        // 顺序要紧：AudioContext / 音量必须在 setSource 之前设好。
        // 原生侧 updateContext 只作用于 reset 之后的对象，晚设会多走一次重 prepare。
        await sfx.player.setAudioContext(_ctx);
        await sfx.player.setReleaseMode(ReleaseMode.stop);
        await sfx.player.setVolume(sfx.volume);
      }
      // setSource 内部会等 prepared 事件返回，回来时三个音都已经是"装填好"状态，
      // 之后每次播放只要 stop + resume 即可，不必再 prepare。
      await Future.wait([
        for (final sfx in _all) sfx.player.setSource(AssetSource(sfx.asset)),
      ]);
      _ready = true;
    } catch (e, st) {
      // 不往外抛：音效挂掉不该连累整个 App 初始化（main 里的 Future.wait
      // 会因为一个子任务报错而整体抛错）。但也绝不能静默——留痕 + 记进
      // initError，自检面板上要看得见。
      initError = '$e';
      debugPrint('[SoundService] 初始化失败：$e\n$st');
    }
  }

  /// 播一个音效。
  ///
  /// 不 await `seek()`，全程不碰那条 30 秒超时的路径（见坑 1）。
  Future<void> _play(_Sfx sfx) async {
    sfx.error = null;
    try {
      // 原生 stop()：pause + seekTo(0)，同步返回，没有 Dart 侧的超时。
      await sfx.player.stop();
      // resume() 从 0 位置起播；init() 已经 prepare 过，无需再 seek。
      await sfx.player.resume();
      sfx.plays++;
      return;
    } catch (e) {
      debugPrint('[SoundService] ${sfx.asset} stop/resume 失败，回退整段重放：$e');
    }
    // 兜底：整段重放（setSource 会等 prepared，同样不经过 seek）。
    // 覆盖 init() 失败、播放器状态异常等情况。
    try {
      await sfx.player.play(AssetSource(sfx.asset));
      sfx.plays++;
    } catch (e) {
      sfx.error = '$e';
      debugPrint('[SoundService] ${sfx.asset} 播放失败：$e');
    }
  }

  Future<void> success() => _play(_success);
  Future<void> error() => _play(_error);
  Future<void> tick() => _play(_tick);

  Future<void> dispose() async {
    for (final sfx in _all) {
      try {
        await sfx.player.dispose();
      } catch (_) {
        // 释放失败无所谓，进程本来就要退了
      }
    }
  }
}

/// 一个音效 = 一个播放器 + 它的音量 + 它的战况统计。
class _Sfx {
  _Sfx(this.name, this.asset, {required this.volume});

  final String name;
  final String asset;
  final double volume;
  final AudioPlayer player = AudioPlayer();

  /// 成功播出的次数。
  int plays = 0;

  /// 最近一次失败原因，正常为 null。
  String? error;
}
