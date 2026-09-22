import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vosk_flutter/vosk_flutter.dart' as vosk;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/iflytek_config.dart';

/// 跟读识别。本地优先：Vosk 离线小模型（en-us，16kHz）；
/// Vosk 不可用时回退讯飞实时语音转写（大模型版 RTASR）。
///
/// 识别结果与目标词做模糊匹配。
/// 麦克风不可用时 [available] 为 false，
/// 界面会显示"模拟跟读成功 / 失败"按钮，方便桌面调试与无麦克风环境。
class SpeechService {
  static const _methodCh = MethodChannel('com.vacmaster.vacmaster/audio');
  static const _audioStream =
      EventChannel('com.vacmaster.vacmaster/audio/stream');

  WebSocketChannel? _ws;
  StreamSubscription? _audioSub;
  StreamSubscription? _wsSub;
  Timer? _startTimeoutTimer;
  Timer? _resultTimeoutTimer;
  final List<int> _pcmBuffer = [];
  String _sessionId = '';
  String _fullText = '';
  bool _ended = false;
  int _framesSent = 0;  // 已发送的音频帧数
  String _finishReason = '';  // finish 触发原因，用于调试

  bool available = false;
  bool _busy = false;
  String _target = '';
  void Function(bool matched, String heard)? _onFinished;

  // ---- Vosk 本地离线识别 ----
  static const _voskModelAsset =
      'assets/models/vosk-model-small-en-us-0.15.zip';
  vosk.Model? _vModel;
  vosk.Recognizer? _vRecognizer;
  vosk.SpeechService? _vSpeech;
  StreamSubscription<String>? _vResultSub;
  StreamSubscription<String>? _vPartialSub;
  Future<bool>? _vInitFuture;
  bool _vReady = false;
  String _vHeard = ''; // 本次录音 vosk 最近识别文本
  String _vPartial = ''; // 本次录音 vosk 最近 partial 文本（兜底用）
  String _engine = ''; // 本次会话引擎: 'vosk' / 'iflytek'
  int _vPartials = 0; // partial 结果日志节流计数

  void _log(String msg) {
    _methodCh.invokeMethod('log', msg);
  }

  Future<bool> init() async {
    debugPrint('[STT] init() called, configured=${IflytekConfig.isConfigured}');
    // 后台预加载 Vosk 本地模型（首次启动需解压约 40MB，不阻塞启动）
    unawaited(_initVosk());
    try {
      var perm = await _methodCh.invokeMethod<bool>('hasPermission');
      // 未授权时主动弹出系统授权框（清数据/首次安装后权限处于拒绝状态）
      if (perm != true) {
        debugPrint('[STT] permission not granted, requesting...');
        perm = await _methodCh.invokeMethod<bool>('requestPermission');
      }
      available = perm ?? false;
      debugPrint('[STT] permission=$perm, available=$available');
    } catch (e) {
      debugPrint('[STT] permission error: $e');
      available = false;
    }
    return available;
  }

  bool get isListening => _busy;

  /// 在录音页再次触发系统授权框（用户此前拒绝时的自愈入口）。
  Future<bool> ensurePermission() async {
    try {
      final perm = await _methodCh.invokeMethod<bool>('requestPermission');
      available = perm ?? false;
      debugPrint('[STT] ensurePermission -> $available');
    } catch (e) {
      debugPrint('[STT] ensurePermission error: $e');
      available = false;
    }
    return available;
  }

  /// 仅调试 / 不支持语音识别的平台使用。
  bool get showSimulation => kDebugMode || !available;

  Future<void> start({
    required String targetWord,
    required void Function(bool matched, String heard) onFinished,
  }) async {
    _log('start() available=$available busy=$_busy voskReady=$_vReady');
    if (!available || _busy) return;
    _busy = true;
    _ended = false;
    _framesSent = 0;
    _finishReason = '';
    _target = targetWord;
    _fullText = '';
    _onFinished = onFinished;

    try {
      // 本地优先：等待 Vosk 就绪（首次启动解压模型可能需要几秒）
      final voskOk = await _initVosk().timeout(
        const Duration(seconds: 30),
        onTimeout: () => false,
      );
      if (voskOk) {
        _engine = 'vosk';
        // 最长按住 15 秒，超时自动结束（与讯飞路径一致）
        _startTimeoutTimer = Timer(const Duration(seconds: 15), () {
          _finishReason = 'vosk max duration (15s)';
          _log('vosk max duration reached, finishing...');
          _finish(_matches(_target, _vHeard), _vHeard);
        });
        await _startVosk();
        return;
      }

      // Vosk 不可用 → 回退讯飞在线识别
      _engine = 'iflytek';
      _log('start() vosk unavailable → fallback iFlytek');
      if (!IflytekConfig.isConfigured) {
        _log('iflytek not configured, giving up');
        _finish(false, '');
        return;
      }
      _log('start() building auth URL...');
      final url = _buildAuthUrl();
      _log('start() connecting ws... url=${url.substring(0, url.length > 150 ? 150 : url.length)}...');
      _ws = WebSocketChannel.connect(Uri.parse(url));
      _log('start() WebSocketChannel.connect() returned');

      _wsSub = _ws!.stream.listen(
        (data) {
          final s = data.toString();
          _log('ws msg: ${s.substring(0, s.length > 300 ? 300 : s.length)}');
          _onMessage(data);
        },
        onError: (e) {
          _finishReason = 'ws error: $e';
          _log('ws ERROR: $e');
          _finish(false, _fullText);
        },
        onDone: () {
          _log('ws done (_ended=$_ended, _busy=$_busy, _fullText="$_fullText")');
          if (_busy && !_ended) {
            _finishReason = 'ws done without end signal';
            _finish(false, _fullText);
          } else {
            _finishReason = 'ws done after end (frames=$_framesSent)';
            _finish(_matches(_target, _fullText), _fullText);
          }
        },
      );

      // 启动超时：握手 + 录音总时长不超过 15 秒
      _startTimeoutTimer = Timer(const Duration(seconds: 15), () {
        _finishReason = 'start timeout (15s)';
        _log('start timeout! forcing finish...');
        _finish(false, _fullText);
      });
    } catch (e) {
      _log('start exception: $e');
      _finish(false, '');
    }
  }

  Future<void> stop() async {
    _log('stop() called, engine=$_engine, framesSent=$_framesSent, sessionId=$_sessionId');
    _startTimeoutTimer?.cancel();
    _startTimeoutTimer = null;

    // Vosk：停麦 + 冲刷识别管线取最终结果
    if (_engine == 'vosk') {
      await _stopVoskAndFinish();
      return;
    }

    // 停止录音，关掉 AudioRecord
    await _audioSub?.cancel();
    _audioSub = null;
    _log('stop() audioSub cancelled');

    // 发送结束信号给服务器
    if (_ws != null && _sessionId.isNotEmpty) {
      final endMsg = jsonEncode({'end': true, 'sessionId': _sessionId});
      _log('sending end signal: $endMsg (total frames=$_framesSent)');
      _ws!.sink.add(endMsg);
      _ended = true;
    } else {
      _finishReason = 'stop: no ws or sessionId';
      _log('stop: no ws or sessionId, forcing finish');
      _finish(false, _fullText);
      return;
    }

    // 结果等待超时：给服务器 6 秒返回最终结果
    _resultTimeoutTimer = Timer(const Duration(seconds: 6), () {
      _finishReason = 'result timeout (6s, frames=$_framesSent)';
      _log('result timeout! closing ws...');
      _finish(_matches(_target, _fullText), _fullText);
    });
  }

  // ---- Vosk 本地识别 ----

  /// 初始化 Vosk（解压模型 → Model → Recognizer → SpeechService）。幂等。
  Future<bool> _initVosk() => _vInitFuture ??= _doInitVosk();

  Future<bool> _doInitVosk() async {
    try {
      final sw = Stopwatch()..start();
      final loader = vosk.ModelLoader();
      final modelPath = await loader.loadFromAssets(_voskModelAsset);
      _log('vosk: model unpacked at ${sw.elapsedMilliseconds}ms -> $modelPath');
      final plugin = vosk.VoskFlutterPlugin.instance();
      _vModel = await plugin.createModel(modelPath);
      _log('vosk: model created at ${sw.elapsedMilliseconds}ms');
      _vRecognizer =
          await plugin.createRecognizer(model: _vModel!, sampleRate: 16000);
      _vSpeech = await plugin.initSpeechService(_vRecognizer!);
      _vReady = true;
      _log('vosk: READY (total ${sw.elapsedMilliseconds}ms)');
    } catch (e) {
      _log('vosk: init FAILED: $e');
      debugPrint('[STT] vosk init failed: $e');
      _vReady = false;
    }
    return _vReady;
  }

  Future<void> _startVosk() async {
    _vHeard = '';
    _vPartial = '';
    _vPartials = 0;
    _log('vosk: start listening (target="$_target")');

    // 用 grammar 约束识别范围：只识别目标词 + [unk]
    // 这样 Vosk 不会把 "sun" 听成 "some"——搜索空间被限定到目标词
    final targetNorm = _norm(_target);
    try {
      await _vRecognizer!.setGrammar([targetNorm, '[unk]']);
      _log('vosk: grammar set to ["$targetNorm", "[unk]"]');
    } catch (e) {
      _log('vosk: setGrammar error (will use free recognition): $e');
    }

    _vResultSub?.cancel();
    _vResultSub = _vSpeech!.onResult().listen(
      (jsonStr) {
        try {
          final text =
              ((jsonDecode(jsonStr) as Map<String, dynamic>)['text'] ?? '')
                  as String;
          if (text.isNotEmpty && text != '[unk]') {
            _vHeard = text;
            _log('vosk result: "$text"');
          }
        } catch (_) {}
      },
      onError: (Object e) {
        _finishReason = 'vosk result stream error';
        _log('vosk stream ERROR: $e');
        _finish(false, _vHeard);
      },
    );

    _vPartialSub?.cancel();
    _vPartialSub = _vSpeech!.onPartial().listen(
      (jsonStr) {
        try {
          final text =
              ((jsonDecode(jsonStr) as Map<String, dynamic>)['partial'] ?? '')
                  as String;
          if (text.isNotEmpty && text != '[unk]') _vPartial = text;
        } catch (_) {}
        if (++_vPartials % 6 == 1) _log('vosk partial: $jsonStr');
      },
      onError: (Object e) => _log('vosk partial stream error: $e'),
    );

    try {
      await _vSpeech!.reset();
      await _vSpeech!
          .start(onRecognitionError: (e) => _log('vosk error event: $e'));
      _log('vosk: listening started');
    } catch (e) {
      _finishReason = 'vosk start failed';
      _log('vosk start FAILED: $e');
      _finish(false, '');
    }
  }

  Future<void> _stopVoskAndFinish() async {
    // 先从 recognizer 直接取当前最佳结果（不依赖 stream 事件时序）
    // [unk] 表示"未命中 grammar"，等同空——留给后续 stream/partial 兜底
    String heard = _vHeard;
    try {
      final curJson = await _vRecognizer!.getResult();
      final curText =
          ((jsonDecode(curJson) as Map<String, dynamic>)['text'] ?? '')
              as String;
      if (curText.isNotEmpty && curText != '[unk]') heard = curText;
      _log('vosk getResult: "$curText"');
    } catch (e) {
      _log('vosk getResult error: $e');
    }

    // 停麦
    try {
      await _vSpeech?.stop();
    } catch (e) {
      _log('vosk stop error: $e');
    }

    // 等 stream 事件 flush（stop 可能触发最后一次 onResult）
    await Future.delayed(const Duration(milliseconds: 150));
    if (_vHeard.isNotEmpty && (heard.isEmpty || heard == '[unk]')) {
      heard = _vHeard;
      _log('vosk: picked up stream result after delay: "$heard"');
    }
    // partial 兜底：极短录音时 getResult/getFinalResult 都可能为空
    if ((heard.isEmpty || heard == '[unk]') && _vPartial.isNotEmpty) {
      heard = _vPartial;
      _log('vosk: using partial fallback: "$heard"');
    }
    // 再冲刷一次取最终结果
    try {
      final finalJson = await _vRecognizer!.getFinalResult();
      final text =
          ((jsonDecode(finalJson) as Map<String, dynamic>)['text'] ?? '')
              as String;
      if (text.isNotEmpty && text != '[unk]') heard = text;
      _log('vosk getFinalResult: "$text"');
    } catch (e) {
      _log('vosk getFinalResult error: $e');
    }
    _finishReason = 'vosk stop';
    _log('vosk final: "$heard" target="$_target"');
    _finish(_matches(_target, heard), heard);
  }

  // ---- 讯飞 WebSocket 通信 ----

  void _onMessage(dynamic raw) {
    try {
      final rawStr = raw.toString();
      final json = jsonDecode(rawStr) as Map<String, dynamic>;
      final msgType = json['msg_type'] as String?;

      if (msgType == 'action') {
        // 服务器动作事件：started / end
        final data = json['data'] as Map<String, dynamic>?;
        final action = data?['action'] as String?;
        if (action == 'started') {
          _sessionId = data?['sessionId'] as String? ?? '';
          _log('ws started, sessionId=$_sessionId → start recording');
          _startRecording();
        } else if (action == 'end') {
          final code = data?['code'] as String?;
          final message = data?['message'] as String?;
          _finishReason = 'server end (code=$code msg=$message)';
          _log('ws end code=$code msg=$message');
          // 服务器主动结束（可能是超时），直接 finish
          _finish(_matches(_target, _fullText), _fullText);
        } else {
          _log('ws unknown action=$action data=$data');
        }
      } else if (msgType == 'result') {
        final text = _extractText(json);
        final data = json['data'] as Map<String, dynamic>?;
        final ls = data?['ls'] as bool? ?? false;
        final cn = data?['cn'] as Map<String, dynamic>?;
        final st = cn?['st'] as Map<String, dynamic>?;
        final type = st?['type'] as String?;

        if (text.isNotEmpty) {
          _fullText = text;
          _log('ws result type=$type ls=$ls text="$text"');
        }

        // type=0 确定性结果 AND ls=true 最后一帧 → 可以 finish
        if (type == '0' && ls) {
          _finishReason = 'server final result (text="$text")';
          _log('ws final result matched=${_matches(_target, _fullText)} target="$_target" heard="$_fullText"');
          _finish(_matches(_target, _fullText), _fullText);
        }
      } else if (msgType == 'error') {
        _finishReason = 'server error msg';
        _log('ws error msg=$json');
        _finish(false, _fullText);
      } else {
        _log('ws unknown msg_type=$msgType json=$json');
      }
    } catch (e, stack) {
      _log('ws _onMessage exception: $e');
      debugPrint('[STT] _onMessage stack: $stack');
    }
  }

  void _startRecording() {
    _log('_startRecording() called');
    _audioSub = _audioStream.receiveBroadcastStream().listen(
      (data) {
        if (data is! List) return;
        final bytes = Uint8List.fromList(data.cast<int>());
        _pcmBuffer.addAll(bytes);
        // 每帧 1280 字节（40ms @ 16kHz 16bit mono）
        while (_pcmBuffer.length >= 1280) {
          final frame =
              Uint8List.fromList(_pcmBuffer.sublist(0, 1280));
          _pcmBuffer.removeRange(0, 1280);
          _framesSent++;
          _ws?.sink.add(frame);
          // 每 50 帧（2 秒）打一次日志
          if (_framesSent % 50 == 0) {
            _log('frames sent: $_framesSent');
          }
        }
      },
      onError: (e) {
        _finishReason = 'audio stream error: $e';
        _finish(false, _fullText);
      },
    );
  }

  Future<void> _finish(bool matched, String heard) async {
    if (!_busy) return;
    _busy = false;

    _startTimeoutTimer?.cancel();
    _startTimeoutTimer = null;
    _resultTimeoutTimer?.cancel();
    _resultTimeoutTimer = null;

    // Vosk 清理：先取消事件监听再停麦
    _vResultSub?.cancel();
    _vResultSub = null;
    _vPartialSub?.cancel();
    _vPartialSub = null;
    if (_engine == 'vosk') {
      try {
        await _vSpeech?.stop();
      } catch (_) {}
    }

    _audioSub?.cancel();
    _audioSub = null;
    _wsSub?.cancel();
    _wsSub = null;
    _ws?.sink.close();
    _ws = null;

    _pcmBuffer.clear();
    _sessionId = '';
    _ended = false;

    _log('_finish reason="$_finishReason" matched=$matched heard="$heard" target="$_target" frames=$_framesSent');

    final cb = _onFinished;
    _onFinished = null;
    cb?.call(matched, heard);
  }

  // ---- 讯飞鉴权 ----

  String _buildAuthUrl() {
    final utc = _formatUtc(DateTime.now());
    final uuid = _generateUuid();

    final params = <String, String>{
      'accessKeyId': IflytekConfig.accessKeyId,
      'appId': IflytekConfig.appId,
      'uuid': uuid,
      'utc': utc,
      'lang': 'autodialect',           // 中英+202种方言自动识别
      'pd': 'edu',                     // 教育领域，优化英语词汇识别
      'eng_vad_mdn': '2',              // 近场模式，手机麦克风更灵敏
      'audio_encode': 'pcm_s16le',
      'samplerate': '16000',
    };

    // 按参数名字典序排列
    final sortedKeys = params.keys.toList()..sort();

    // 拼接 baseString（键和值都 URL 编码）
    final baseString = sortedKeys.map((k) {
      return '${Uri.encodeComponent(k)}=${Uri.encodeComponent(params[k]!)}';
    }).join('&');

    // HMAC-SHA1
    final hmac = Hmac(sha1, utf8.encode(IflytekConfig.accessKeySecret));
    final digest = hmac.convert(utf8.encode(baseString));
    final signature = base64.encode(digest.bytes);

    params['signature'] = signature;

    // 构建最终 URL
    final query = params.entries.map((e) {
      return '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}';
    }).join('&');

    return 'wss://office-api-ast-dx.iflyaisol.com/ast/communicate/v1?$query';
  }

  /// 格式化时间为讯飞要求的格式: 2025-09-04T15:38:07+0800
  static String _formatUtc(DateTime dt) {
    final offset = dt.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final mins = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return '${dt.year.toString().padLeft(4, '0')}'
        '-${dt.month.toString().padLeft(2, '0')}'
        '-${dt.day.toString().padLeft(2, '0')}'
        'T${dt.hour.toString().padLeft(2, '0')}'
        ':${dt.minute.toString().padLeft(2, '0')}'
        ':${dt.second.toString().padLeft(2, '0')}'
        '$sign$hours$mins';
  }

  static String _generateUuid() {
    final rng = Random();
    final hex = StringBuffer();
    for (var i = 0; i < 32; i++) {
      hex.write(rng.nextInt(16).toRadixString(16));
    }
    final s = hex.toString();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}'
        '-${s.substring(12, 16)}-${s.substring(16, 20)}'
        '-${s.substring(20, 32)}';
  }

  /// 从讯飞返回 JSON 中提取识别文本。
  static String _extractText(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    if (data == null) return '';
    final cn = data['cn'] as Map<String, dynamic>?;
    if (cn == null) return '';
    final st = cn['st'] as Map<String, dynamic>?;
    if (st == null) return '';
    final rt = st['rt'];
    if (rt == null || rt is! List) return '';

    final sb = StringBuffer();
    for (final item in rt) {
      if (item is! Map<String, dynamic>) continue;
      final ws = item['ws'];
      if (ws == null || ws is! List) continue;
      for (final w in ws) {
        if (w is! Map<String, dynamic>) continue;
        final cw = w['cw'];
        if (cw == null || cw is! List) continue;
        for (final c in cw) {
          if (c is! Map<String, dynamic>) continue;
          sb.write(c['w'] ?? '');
        }
      }
    }
    return sb.toString();
  }

  // ---- 匹配逻辑 ----

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r"[^a-z' ]"), ' ').replaceAll("'", '').trim();

  static bool _matches(String targetWord, String heard) {
    final key = _norm(targetWord).replaceAll(' ', '');
    final said = _norm(heard);
    if (key.isEmpty || said.isEmpty) return false;
    if (said == key) return true;

    final words = said.split(RegExp(r'\s+'));
    for (final w in words) {
      if (w == key) return true;
      // 单复数 / 时态等轻微差异
      if (w.length >= 4 && (w.contains(key) || key.contains(w))) {
        final shorter = w.length < key.length ? w.length : key.length;
        if (shorter / (w.length > key.length ? w.length : key.length) > 0.65) {
          return true;
        }
      }
      final sim = _similarity(w, key);
      if (sim >= 0.65) return true;
    }
    // 整句相似度兜底
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
