import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// 单词 / 英文释义朗读。
/// 优先播放词书自带的本地 MP3（AssetSource），失败或缺失时回退系统 TTS。
class TtsService {
  static const _methodCh = MethodChannel('com.vacmaster.vacmaster/audio');

  final AudioPlayer _mp3 = AudioPlayer();
  FlutterTts? _tts;
  bool _inited = false;
  String? _lastError;

  void _log(String msg) {
    try {
      _methodCh.invokeMethod('log', msg);
    } catch (_) {}
  }

  Future<void> _createTts() async {
    _tts?.stop();
    _tts = FlutterTts();
    _tts!.setErrorHandler((msg) {
      _lastError = msg?.toString();
      _log('tts error: $msg');
    });
    _tts!.setStartHandler(() => _log('tts start'));
    _tts!.setCompletionHandler(() => _log('tts complete'));
  }

  /// 真正初始化：创建实例 → 等待绑定 → 检测可用性。
  Future<bool> _tryInit() async {
    await _createTts();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    try {
      final lang = await _tts!.isLanguageAvailable('en-US');
      _log('tts isLanguageAvailable(en-US) = $lang');
      if (lang != true) {
        _inited = false;
        return false;
      }
      final r = await _tts!.setLanguage('en-US');
      _log('tts setLanguage(en-US) = $r');
      await _tts!.setSpeechRate(0.5);
      await _tts!.setPitch(1.1);
      await _tts!.setVolume(1.0);
      await _tts!.awaitSpeakCompletion(true);
      _inited = true;
      _log('tts init OK');
      return true;
    } catch (e) {
      _log('tts init exception: $e');
      _inited = false;
      return false;
    }
  }

  Future<void> init() async {
    if (_inited) return;
    await _tryInit();
  }

  /// speak 前确保引擎就绪，失败则重建实例重试一次。
  Future<void> _ensureReady() async {
    if (_inited && _tts != null) return;
    _log('tts not ready, retry init...');
    _inited = false;
    if (!await _tryInit()) {
      _log('tts retry 2: wait longer & recreate');
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await _createTts();
      await Future<void>.delayed(const Duration(milliseconds: 800));
      try {
        final ok = await _tts!.isLanguageAvailable('en-US');
        _log('tts retry2 isLanguageAvailable = $ok');
        if (ok == true) {
          await _tts!.setLanguage('en-US');
          await _tts!.setSpeechRate(0.5);
          await _tts!.setPitch(1.1);
          await _tts!.setVolume(1.0);
          await _tts!.awaitSpeakCompletion(true);
          _inited = true;
          _log('tts retry2 OK');
        }
      } catch (e) {
        _log('tts retry2 exception: $e');
      }
    }
    if (!_inited) {
      _log('tts still not ready after retries, lastError=$_lastError');
    }
  }

  /// 朗读文本。
  Future<void> speak(String text) async {
    await _ensureReady();
    try {
      await _tts!.stop();
      await _tts!.awaitSpeakCompletion(true);
      final r = await _tts!.speak(text);
      _log('tts speak("$text") -> $r inited=$_inited');
    } catch (e) {
      _log('tts speak exception: $e');
    }
  }

  /// 播放词书自带音频；等待自然播完（超时 8s 兜底）。
  Future<void> _playMp3(String assetPath) async {
    // rootBundle 的资产键带 assets/ 前缀；AssetSource 需要去掉前缀。
    final bundleKey = assetPath.startsWith('assets/')
        ? assetPath
        : 'assets/$assetPath';
    final sourcePath = bundleKey.substring('assets/'.length);
    await rootBundle.load(bundleKey); // 资产不存在 → 抛异常，走 TTS 回退
    final completer = Completer<void>();
    final sub = _mp3.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) completer.complete();
    });
    try {
      await _mp3.stop();
      await _mp3.play(AssetSource(sourcePath));
      _log('mp3 play OK: $bundleKey');
      await completer.future.timeout(const Duration(seconds: 8));
    } finally {
      await sub.cancel();
    }
  }

  /// 朗读单词：自带 MP3 优先，缺失/失败回退系统 TTS。
  Future<void> speakWord(String word, {double rate = 0.5, String? audio}) async {
    if (audio != null && audio.isNotEmpty) {
      try {
        await _playMp3(audio);
        return;
      } catch (e) {
        _log('mp3 play failed ($audio): $e, fallback to tts');
      }
    }
    await _ensureReady();
    try {
      await _tts!.stop();
      await _tts!.setSpeechRate(rate);
      await _tts!.awaitSpeakCompletion(true);
      final r = await _tts!.speak(word);
      _log('tts speakWord("$word") rate=$rate -> $r inited=$_inited');
      await _tts!.setSpeechRate(0.5);
    } catch (e) {
      _log('tts speakWord exception: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _mp3.stop();
    } catch (_) {}
    try {
      await _tts?.stop();
    } catch (_) {}
  }

  void dispose() {
    _mp3.stop();
    _mp3.dispose();
    _tts?.stop();
  }
}
