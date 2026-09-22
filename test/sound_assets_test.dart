import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vacmaster/services/sound_service.dart';

/// 音效素材 + 音效服务的回归测试。
///
/// 起因是真机事故：荣耀平板上"拼写时输入字母没有音效"。查下来是两件事叠在一起——
///
/// 1. `SoundService` 用 `seek(Duration.zero)` 重播。Android 的 MediaPlayer 在
///    "已暂停且位置本来就是 0"时不会回调 onSeekComplete，而 audioplayers 的
///    `seek()` 内部要 `await onSeekComplete.first.timeout(30 秒)`。于是每次按键
///    都先挂 30 秒再抛异常，串在它后面的 `resume()` 永远执行不到，声音一句都出不来，
///    还被 catch 吞了。表现为"某些机型完全没有音效，别的机型正常"。
///    → 已改成 `stop()` + `resume()`，本文件守住"不许再出现 seek 重播"。
/// 2. `tick.wav` 峰值只有 0.20 满刻度（-14 dBFS），平板外放上跟没响一样；
///    而且波形结尾是硬切的（最后一帧还有 56% 峰值），放大后就是一声爆音。
///    → 已由 `tools/normalize_sfx.py` 归一到 0.9 FS 并补了收尾淡出。
///
/// 这里断言的是"素材本身够响、够长、收尾干净"，因为这类问题在代码里看不出来，
/// 只在耳朵里。素材被人换掉时，这几条能立刻拦住。

const _assets = <String, String>{
  '成功音': 'assets/sounds/success.wav',
  '错误音': 'assets/sounds/error.wav',
  '按键音': 'assets/sounds/tick.wav',
};

/// 满刻度（16-bit 有符号）。
const int _fullScale = 32767;

class _Wav {
  _Wav(this.audioFormat, this.channels, this.sampleRate, this.bits, this.samples);

  final int audioFormat;
  final int channels;
  final int sampleRate;
  final int bits;
  final Int16List samples;

  double get durationMs => samples.length / sampleRate * 1000;

  int get peak =>
      samples.fold(0, (max, v) => v.abs() > max ? v.abs() : max);

  /// 最后 1ms 的峰值。硬切（波形没衰减到 0 就被截断）会让这个值偏高，
  /// 放大音量后就是"啪"的一声。
  int get tailPeak {
    final tail = (sampleRate / 1000).round();
    final start = samples.length - tail;
    var max = 0;
    for (var i = start < 0 ? 0 : start; i < samples.length; i++) {
      final a = samples[i].abs();
      if (a > max) max = a;
    }
    return max;
  }
}

/// 极简 WAV 解析：够解析自家这三个素材用（RIFF/WAVE + fmt + data）。
_Wav _parseWav(Uint8List bytes) {
  String tag(int at) => ascii.decode(bytes.sublist(at, at + 4));
  expect(tag(0), 'RIFF', reason: '不是 RIFF 文件');
  expect(tag(8), 'WAVE', reason: '不是 WAVE 格式');

  final view = ByteData.sublistView(bytes);
  int audioFormat = 0, channels = 0, sampleRate = 0, bits = 0;
  Uint8List? data;

  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = tag(offset);
    final size = view.getUint32(offset + 4, Endian.little);
    final body = offset + 8;
    if (id == 'fmt ') {
      audioFormat = view.getUint16(body, Endian.little);
      channels = view.getUint16(body + 2, Endian.little);
      sampleRate = view.getUint32(body + 4, Endian.little);
      bits = view.getUint16(body + 14, Endian.little);
    } else if (id == 'data') {
      data = Uint8List.fromList(bytes.sublist(body, body + size));
    }
    // chunk 按偶数字节对齐
    offset = body + size + (size.isOdd ? 1 : 0);
  }

  expect(data, isNotNull, reason: '缺 data chunk');
  final samples = Int16List.view(data!.buffer, data.offsetInBytes, data.length ~/ 2);
  return _Wav(audioFormat, channels, sampleRate, bits, samples);
}

Future<Uint8List> _load(String path) async {
  // 走 rootBundle 而不是 File：这样"asset 没在 pubspec 里声明 / 没打进包"
  // 也会被这套测试拦住，而磁盘读取永远读得到。
  final data = await rootBundle.load(path);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('音效素材', () {
    for (final entry in _assets.entries) {
      test('${entry.key}：格式正确、够响、够长、收尾干净', () async {
        final wav = _parseWav(await _load(entry.value));
        final name = entry.key;

        // 格式：audioplayers 的 MediaPlayer 对 16-bit PCM 单声道最稳
        expect(wav.audioFormat, 1, reason: '$name 必须是未压缩 PCM');
        expect(wav.channels, 1, reason: '$name 必须是单声道');
        expect(wav.bits, 16, reason: '$name 必须是 16-bit');
        expect(wav.sampleRate, 44100, reason: '$name 采样率应为 44100');

        // 时长：太短的提示音在平板外放上会被"吞"掉，尤其按键音
        expect(wav.durationMs, greaterThanOrEqualTo(40),
            reason: '$name 只有 ${wav.durationMs.toStringAsFixed(1)}ms，太短会听不见');

        // 响度：低于 70% 满刻度就有听不见的风险（tick 原本只有 20%）
        expect(wav.peak, greaterThanOrEqualTo((_fullScale * 0.7).round()),
            reason: '$name 峰值只有 ${(wav.peak / _fullScale * 100).toStringAsFixed(1)}% 满刻度，'
                '偏轻；跑 tools/normalize_sfx.py 归一化一下');

        // 收尾：最后 1ms 必须已经衰减到接近静音，否则是硬切，放大后会爆音
        expect(wav.tailPeak, lessThanOrEqualTo((_fullScale * 0.05).round()),
            reason: '$name 结尾被硬切（最后 1ms 峰值 '
                '${(wav.tailPeak / _fullScale * 100).toStringAsFixed(1)}% 满刻度），会有爆音');
      });
    }

    test('三个素材的响度差不超过一档，不会一个震耳一个听不见', () async {
      final peaks = <String, int>{};
      for (final entry in _assets.entries) {
        peaks[entry.key] = _parseWav(await _load(entry.value)).peak;
      }
      final values = peaks.values.toList()..sort();
      expect(values.last / values.first, lessThan(1.35),
          reason: '素材响度不齐：$peaks');
    });
  });

  group('SoundService', () {
    test('初始化失败不抛异常，并把原因留在 diagnose() 里', () async {
      // 测试环境没有真实的 audioplayers 插件，init() 必然失败——
      // 正好用来钉住"音效挂掉不许把整个 App 初始化拖下水"这条。
      final service = SoundService();
      await expectLater(service.init(), completes);
      expect(service.ready, isFalse);
      expect(service.initError, isNotNull);
      expect(service.diagnose(), contains('初始化'));

      await service.dispose();
    });

    test('播放失败不抛异常（拼写页每次按键都会调它）', () async {
      final service = SoundService();
      await service.init();

      // 播放调用点在 UI 里是 fire-and-forget，一抛就是未捕获异步异常
      await expectLater(service.tick(), completes);
      await expectLater(service.success(), completes);
      await expectLater(service.error(), completes);

      // 一声音都没出去，计数必须是 0 —— 自检面板就是靠这个判断"到底响没响"
      expect(service.playCount, 0);

      await service.dispose();
    });
  });
}
