import 'dart:async';
import 'dart:js_interop';
// getProperty / setProperty / callMethod / callAsConstructor 这几个"编译器工具"
// 在 dart:js_interop 里没有，必须单独 import 这个库。
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';

/// Web 版跟读识别（供 GitHub Pages 演示站使用）。
///
/// 与原生版 `speech_service_io.dart` 的**公开 API 完全一致**，
/// 由 `speech_service.dart` 的 conditional export 在编译期二选一。
///
/// 两条路径：
/// 1. **真实识别**：浏览器提供 `SpeechRecognition` / `webkitSpeechRecognition`
///    （Chrome / Edge / Safari）时直接调用它。注意它把音频送去云端识别，
///    断网或访问不到时会走 onerror，此时自动降级到下面的演示模式。
/// 2. **演示模式**：不支持的浏览器（如 Firefox）或识别报错时启用 ——
///    松手后约 0.9 秒判定"识别成功"，保证"跟读 → 拼写 → 结算"整条流程
///    在网页上能完整走通，方便别人测试界面与手感。
class SpeechService {
  SpeechService() {
    _demo = _resolveCtor() == null;
  }

  /// 网页上总是允许进入跟读流程（真实识别或演示模式）。
  bool available = false;

  bool _busy = false;
  bool _demo = false;
  bool _finishedThisRound = true;
  String _target = '';
  String _heard = '';
  void Function(bool matched, String heard)? _onFinished;

  JSObject? _rec;
  Timer? _demoTimer;
  Timer? _maxTimer;
  Timer? _guardTimer;

  bool get isListening => _busy;

  /// 真机调试用的"模拟结果"入口。Web 上恒为 false：
  /// 演示模式已经能走完整条流程，界面上不需要再多两个调试按钮。
  bool get showSimulation => false;

  Future<bool> init() async {
    available = true;
    _demo = _resolveCtor() == null;
    debugPrint('[STT/web] init: demo=$_demo');
    return available;
  }

  /// 浏览器里权限由 Web Speech API 在首次 `start()` 时自己弹，
  /// 这里直接返回可用，让界面不要卡在"授权"这一步。
  Future<bool> ensurePermission() async {
    available = true;
    return true;
  }

  Future<void> start({
    required String targetWord,
    required void Function(bool matched, String heard) onFinished,
  }) async {
    if (_busy) return;
    _busy = true;
    _finishedThisRound = false;
    _target = targetWord;
    _heard = '';
    _onFinished = onFinished;

    // 兜底：无论识别卡在哪，15 秒后必须给结果（与原生端一致）
    _maxTimer?.cancel();
    _maxTimer = Timer(const Duration(seconds: 15), () {
      _finish(_matches(targetWord, _heard),
          _heard.isEmpty ? targetWord : _heard);
    });

    final ctor = _resolveCtor();
    if (ctor == null || _demo) {
      _demo = true;
      debugPrint('[STT/web] 演示模式（无 Web Speech API）');
      return;
    }

    try {
      final rec = ctor.callAsConstructor<JSObject>();
      _rec = rec;
      rec.setProperty('lang'.toJS, 'en-US'.toJS);
      rec.setProperty('interimResults'.toJS, true.toJS);
      rec.setProperty('maxAlternatives'.toJS, 5.toJS);
      rec.setProperty('continuous'.toJS, false.toJS);
      rec.setProperty('onresult'.toJS, ((JSAny e) => _onResult(e)).toJS);
      rec.setProperty('onerror'.toJS, ((JSAny e) => _onError(e)).toJS);
      rec.setProperty('onend'.toJS, ((JSAny e) => _onEnd()).toJS);
      rec.callMethod('start'.toJS);
    } catch (e) {
      debugPrint('[STT/web] 启动失败，转演示模式：$e');
      _demo = true;
      _rec = null;
    }
  }

  Future<void> stop() async {
    _maxTimer?.cancel();
    _maxTimer = null;

    final rec = _rec;
    _rec = null;
    if (rec != null) {
      try {
        rec.callMethod('stop'.toJS);
      } catch (_) {}
      // 给浏览器一点时间吐结果；到点还没来就按"没听清"结算
      _guardTimer?.cancel();
      _guardTimer = Timer(const Duration(milliseconds: 2500), () {
        _finish(_matches(_target, _heard), _heard.isEmpty ? _target : _heard);
      });
      return;
    }

    if (_demo) {
      // 演示模式：松手后短促"识别中"，然后判定成功
      _demoTimer?.cancel();
      _demoTimer = Timer(const Duration(milliseconds: 900), () {
        _finish(true, _target);
      });
      return;
    }

    _finish(false, '');
  }

  // ---------- Web Speech API 回调 ----------

  void _onResult(JSAny event) {
    try {
      final obj = event as JSObject;
      final results = obj.getProperty('results'.toJS) as JSObject;
      final len = (results.getProperty('length'.toJS) as JSNumber).toDartInt;
      final sb = StringBuffer();
      for (var i = 0; i < len; i++) {
        final res = results.getProperty(i.toString().toJS) as JSObject;
        final alt0 = res.getProperty('0'.toJS) as JSObject;
        final t = (alt0.getProperty('transcript'.toJS) as JSString).toDart;
        sb.write(' $t');
      }
      final text = sb.toString().trim();
      if (text.isNotEmpty) _heard = text;
      debugPrint('[STT/web] 识别到：$_heard');
    } catch (e) {
      debugPrint('[STT/web] 解析识别结果失败：$e');
    }
  }

  void _onError(JSAny event) {
    var code = '';
    try {
      code = ((event as JSObject).getProperty('error'.toJS) as JSString).toDart;
    } catch (_) {}
    debugPrint('[STT/web] 识别报错：$code → 转演示模式');
    _demo = true;
  }

  void _onEnd() {
    _guardTimer?.cancel();
    _guardTimer = null;
    if (_finishedThisRound) return;

    if (_demo && _heard.isEmpty) {
      // 识别过程出过错、又没拿到文本 → 演示模式下给成功，别把测试者卡住
      _finish(true, _target);
      return;
    }
    _finish(_matches(_target, _heard), _heard.isEmpty ? _target : _heard);
  }

  void _finish(bool matched, String heard) {
    if (_finishedThisRound) return;
    _finishedThisRound = true;
    _busy = false;

    _demoTimer?.cancel();
    _demoTimer = null;
    _guardTimer?.cancel();
    _guardTimer = null;
    _maxTimer?.cancel();
    _maxTimer = null;

    final rec = _rec;
    _rec = null;
    if (rec != null) {
      try {
        rec.callMethod('abort'.toJS);
      } catch (_) {}
    }

    final cb = _onFinished;
    _onFinished = null;
    debugPrint('[STT/web] 结算 matched=$matched heard="$heard"');
    cb?.call(matched, heard);
  }

  // ---------- 与原生端一致的匹配逻辑 ----------

  static JSFunction? _resolveCtor() {
    try {
      final g = globalContext;
      for (final name in const ['SpeechRecognition', 'webkitSpeechRecognition']) {
        final v = g.getProperty(name.toJS);
        if (v.isA<JSFunction>()) return v as JSFunction;
      }
    } catch (e) {
      debugPrint('[STT/web] 探测 Web Speech API 失败：$e');
    }
    return null;
  }

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z' ]"), ' ')
      .replaceAll("'", '')
      .trim();

  static bool _matches(String targetWord, String heard) {
    final key = _norm(targetWord).replaceAll(' ', '');
    final said = _norm(heard);
    if (key.isEmpty || said.isEmpty) return false;
    if (said == key) return true;

    final words = said.split(RegExp(r'\s+'));
    for (final w in words) {
      if (w == key) return true;
      if (w.length >= 4 && (w.contains(key) || key.contains(w))) {
        final shorter = w.length < key.length ? w.length : key.length;
        final longer = w.length > key.length ? w.length : key.length;
        if (shorter / longer > 0.65) return true;
      }
      if (_similarity(w, key) >= 0.65) return true;
    }
    return _similarity(said.replaceAll(' ', ''), key) >= 0.7;
  }

  /// 1 - 编辑距离 / 最长串长度
  static double _similarity(String a, String b) {
    if (a == b) return 1;
    if (a.isEmpty || b.isEmpty) return 0;
    final m = a.length, n = b.length;
    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
    for (var i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (var j = 0; j <= n; j++) {
      dp[0][j] = j;
    }
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
    }
    return 1 - dp[m][n] / (m > n ? m : n);
  }
}
