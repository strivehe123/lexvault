import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/word.dart';
import '../../models/word_book.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/word_image.dart';
import '../book_detail_page.dart';
import '../review/review_session_page.dart';

enum _Stage {
  intro,
  audioPlaying,
  recording,
  recognizing,
  recordSuccess,
  recordFail,
  spelling,
  spelled,
  detail
}

class StudySessionPage extends StatefulWidget {
  final WordBook book;
  final List<Word> words;
  final int dailyTarget;   // 每日目标总词数
  final int alreadyLearned; // 今日已学词数（本次 session 之前）

  const StudySessionPage({
    super.key,
    required this.book,
    required this.words,
    required this.dailyTarget,
    required this.alreadyLearned,
  });

  @override
  State<StudySessionPage> createState() => _StudySessionPageState();
}

class _StudySessionPageState extends State<StudySessionPage> {
  final FocusNode _kbNode = FocusNode();

  int _index = 0;
  _Stage _stage = _Stage.intro;
  bool _maskChinese = false;
  bool _recording = false;
  Timer? _recordTimer;
  int _recordElapsedMs = 0;
  int _failCount = 0;  // 连续跟读失败次数，满 3 次进入拼写
  bool _wordLearnedSaved = false;  // 当前单词是否已保存进度（避免重复保存）

  // 反馈
  bool _redFlash = false;
  int _shakeTick = 0;

  // 拼写
  String _accepted = '';
  String? _wrongLetter;
  int _spellFailCount = 0;  // 拼写失败次数，满 3 次进入详情页

  Word get _word => widget.words[_index];
  bool get _isLastWord => _index == widget.words.length - 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _kbNode.requestFocus();
      // 进入单词卡自动播放发音，帮助用户先听一遍
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && _stage == _Stage.intro) {
          context.read<AppState>().tts.speakWord(_word.word, audio: _word.audio);
        }
      });
    });
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _kbNode.dispose();
    context.read<AppState>().tts.stop();
    super.dispose();
  }

  // ---------------- 流程动作 ----------------

  void _toggleMask() {
    if (_stage != _Stage.intro) return;
    setState(() => _maskChinese = !_maskChinese);
  }

  Future<void> _startFollow() async {
    if (_stage != _Stage.intro) return;
    setState(() {
      _stage = _Stage.audioPlaying;
      _maskChinese = false;
    });
    await context.read<AppState>().tts.speakWord(_word.word, audio: _word.audio);
    if (!mounted) return;
    setState(() => _stage = _Stage.recording);
  }

  Future<void> _startRecording() async {
    if (_stage != _Stage.recording || _recording) return;
    final speech = context.read<AppState>().speech;
    if (!speech.available) return;
    HapticFeedback.lightImpact();
    setState(() {
      _recording = true;
      _recordElapsedMs = 0;
    });
    _recordTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() => _recordElapsedMs += 100);
    });
    await speech.start(
      targetWord: _word.word,
      onFinished: _onSpeechResult,
    );
  }

  Future<void> _stopRecording() async {
    if (!_recording) return;
    _recordTimer?.cancel();
    _recordTimer = null;
    setState(() {
      _recording = false;
      _stage = _Stage.recognizing;
    });
    await context.read<AppState>().speech.stop();
  }

  void _onSpeechResult(bool matched, String heard) {
    if (!mounted) return;
    if (matched) {
      // 跟读成功 1 次 → 进入拼写
      context.read<AppState>().sounds.success();
      _failCount = 0;
      setState(() => _stage = _Stage.recordSuccess);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        _enterSpelling();
      });
    } else {
      // 跟读失败，满 3 次 → 进入拼写（不再纠结语音）
      _failCount++;
      _fail();
      setState(() => _stage = _Stage.recordFail);
      if (_failCount >= 3) {
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (!mounted) return;
          _enterSpelling();
        });
      }
    }
  }

  Future<void> _replayAndRecord() async {
    setState(() => _stage = _Stage.audioPlaying);
    await context.read<AppState>().tts.speakWord(_word.word, audio: _word.audio);
    if (!mounted) return;
    setState(() => _stage = _Stage.recording);
  }

  /// 进入详情页并标记当前单词已学（实时保存进度）。
  void _enterDetailAsLearned() {
    if (!_wordLearnedSaved) {
      _wordLearnedSaved = true;
      context.read<AppState>().markWordLearned(widget.book, _word);
    }
    setState(() => _stage = _Stage.detail);
  }

  void _enterSpelling() {
    if (_stage != _Stage.recordSuccess && _stage != _Stage.recordFail) return;
    setState(() {
      _stage = _Stage.spelling;
      _accepted = '';
      _wrongLetter = null;
      _spellFailCount = 0;
      _shakeTick = 0;   // 关键：重置 shakeTick，避免 recordFail 残留值触发拼写页单词摇头
      _redFlash = false;
    });
    // 进入拼写页自动播放单词语音一次
    context.read<AppState>().tts.speakWord(_word.word, audio: _word.audio);
  }

  /// 内置键盘或硬件键盘输入一个字母
  void _inputLetter(String letter) {
    if (_stage != _Stage.spelling) return;
    if (_wrongLetter != null) return; // 错误展示中，忽略输入
    final key = _word.spellTarget;
    if (_accepted.length >= key.length) return; // 已满，不再接受输入

    // 短语词边界：自动补入空格并在需要时连续推进
    var changed = false;
    while (_accepted.length < key.length && key[_accepted.length] == ' ') {
      _accepted += ' ';
      changed = true;
    }
    if (changed && _accepted.length == key.length) {
      setState(() {});
      return;
    }
    if (_accepted.length >= key.length) {
      setState(() {});
      return;
    }

    final input = letter.toLowerCase();
    final expected = key[_accepted.length];
    if (input == expected) {
      // 正确字母
      _accepted += input;
      context.read<AppState>().sounds.tick();
      if (_accepted.length == key.length) {
        context.read<AppState>().sounds.success();
        setState(() => _stage = _Stage.spelled);
        // 全拼对后播放单词语音一次再跳转详情
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          context.read<AppState>().tts.speakWord(_word.word, audio: _word.audio);
        });
        Future.delayed(const Duration(milliseconds: 1800), () {
          if (mounted) _enterDetailAsLearned();
        });
      } else {
        setState(() {});
      }
    } else {
      // 错误字母
      _spellFailCount++;
      _fail();
      setState(() => _wrongLetter = input);

      // 统一反馈：输错后固定重播一遍单词发音（700ms 避开错误音效），保证每次都有
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted || _stage != _Stage.spelling) return;
        context.read<AppState>().tts.speakWord(_word.word, audio: _word.audio);
      });

      if (_spellFailCount >= 3) {
        // 拼写失败 3 次，进入详情页
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) _enterDetailAsLearned();
        });
        return;
      }

      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        setState(() => _wrongLetter = null);
      });
    }
  }

  void _fail() {
    context.read<AppState>().sounds.error();
    setState(() {
      _redFlash = true;
      _shakeTick++;
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _redFlash = false);
    });
  }

  Future<void> _nextWord() async {
    if (_stage != _Stage.detail) return;
    if (_isLastWord) {
      // 所有单词已在进入详情页时逐个保存进度，直接进入强化复习。
      // 强化范围 = 今天学的最后 N 个单词（N=每日目标，加练轮正好是本轮学的词）。
      if (!mounted) return;
      final app = context.read<AppState>();
      var reviewWords = app.todayLearnedWords(widget.book);
      if (reviewWords.length > widget.dailyTarget) {
        reviewWords = reviewWords.sublist(reviewWords.length - widget.dailyTarget);
      }
      if (reviewWords.isEmpty) reviewWords = widget.words;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReviewSessionPage(book: widget.book, words: reviewWords),
        ),
      );
      return;
    }
    setState(() {
      _index++;
      _stage = _Stage.intro;
      _maskChinese = false;
      _failCount = 0;
      _wordLearnedSaved = false;
      _shakeTick = 0;  // 新单词重置 tick，避免 intro 页误触发摇头
      _accepted = '';
      _wrongLetter = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _kbNode.requestFocus());
    // 新单词自动播放发音
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _stage == _Stage.intro) {
        context.read<AppState>().tts.speakWord(_word.word, audio: _word.audio);
      }
    });
  }

  // ---------------- 键盘 ----------------

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final isDown = event is KeyDownEvent;
    final isUp = event is KeyUpEvent;
    final space = event.logicalKey == LogicalKeyboardKey.space;
    final enter = event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    final rKey = event.logicalKey == LogicalKeyboardKey.keyR;

    if (_stage == _Stage.spelling) {
      // 拼写阶段：硬件键盘字母 → 输入（移动端主输入方式为内置键盘，
      // 此分支仅用于桌面/实体键盘测试场景；错误输入直接触发报错，无需退格）。
      if (isDown) {
        final label = event.logicalKey.keyLabel;
        if (label.length == 1) {
          final ch = label.toLowerCase();
          if (ch.codeUnitAt(0) >= 0x61 && ch.codeUnitAt(0) <= 0x7a) {
            _inputLetter(ch);
            return KeyEventResult.handled;
          }
        }
      }
      return KeyEventResult.ignored;
    }
    if (_stage == _Stage.spelled) {
      return KeyEventResult.ignored;
    }

    // KeyRepeatEvent 不会命中 isDown（按下重复是独立事件类型），天然防抖。
    if (isDown) {
      if (enter) {
        switch (_stage) {
          case _Stage.intro:
            _startFollow();
            return KeyEventResult.handled;
          case _Stage.recordSuccess:
            _enterSpelling();
            return KeyEventResult.handled;
          case _Stage.detail:
            _nextWord();
            return KeyEventResult.handled;
          default:
            break;
        }
      }
      if (space) {
        switch (_stage) {
          case _Stage.intro:
            _toggleMask();
            return KeyEventResult.handled;
          case _Stage.recording:
            _startRecording();
            return KeyEventResult.handled;
          case _Stage.recordFail:
            // Space = 直接重录（R = 重播后再录）
            setState(() {
              _shakeTick = 0;  // 重置 tick，避免 recording 页 ShakeBox 误触发摇头
              _stage = _Stage.recording;
            });
            return KeyEventResult.handled;
          default:
            break;
        }
      }
      if (rKey) {
        if (_stage == _Stage.recordSuccess || _stage == _Stage.recordFail) {
          _replayAndRecord();
          return KeyEventResult.handled;
        }
      }
    }
    if (isUp && space && _stage == _Stage.recording && _recording) {
      _stopRecording();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _kbNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Stack(
        children: [
          // 红屏底色：识别失败整屏持续浅红；拼写错误闪烁 600ms（内容绘制在其上方）
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              color: (_redFlash || _stage == _Stage.recordFail)
                  ? AppColors.errorBg
                  : AppColors.bg,
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Column(
                children: [
                  StageHeader(
                    stageLabel: '学习阶段',
                    // 今日目标已完成后的加练轮 → 从 1 重新计数
                    current: widget.alreadyLearned >= widget.dailyTarget
                        ? _index + 1
                        : widget.alreadyLearned + _index + 1,
                    total: widget.dailyTarget,
                  ),
                  Expanded(child: _body()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_stage) {
      case _Stage.intro:
        return _introView();
      case _Stage.audioPlaying:
        return _audioView();
      case _Stage.recording:
        return _recordingView();
      case _Stage.recognizing:
        return _recognizingView();
      case _Stage.recordSuccess:
        return _recordResultView(true);
      case _Stage.recordFail:
        return _recordResultView(false);
      case _Stage.spelling:
      case _Stage.spelled:
        return _spellingView();
      case _Stage.detail:
        return _detailView();
    }
  }

  // ---- 初始卡：图 + 英文释义 + 开始跟读 ----
  Widget _introView() {
    return Stack(
      children: [
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShakeBox(
                  tick: _shakeTick,
                  child: WordImage(
                    word: _word,
                    size: 240,
                    maskChinese: _maskChinese,
                  ),
                ),
                const SizedBox(height: 16),
                _DefinitionCard(
                  word: _word,
                  onPlay: () => context
                      .read<AppState>()
                      .tts
                      .speak(_word.definition.split('|').first),
                ),
                // 加大间距，把中文提示 + 开始跟读按钮区域往屏幕下方移
                const SizedBox(height: 110),
                const Text('中文提示',
                    style: TextStyle(fontSize: 12, color: AppColors.inkHint)),
                const SizedBox(height: 18),
                PulseGlow(
                  child: GradientButton(
                    label: '开始跟读',
                    onPressed: _startFollow,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _audioView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        WordImage(word: _word, size: 240),
        const SizedBox(height: 30),
        const Text('播放单词音频中...',
            style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _recordingView() {
    final speech = context.read<AppState>().speech;
    final totalSec = (_recordElapsedMs / 1000).floor();
    final ms = (_recordElapsedMs % 1000) ~/ 100;
    final mm = (totalSec ~/ 60).toString().padLeft(2, '0');
    final ss = (totalSec % 60).toString().padLeft(2, '0');
    final timerText = '$mm:$ss.$ms';

    return Stack(
      children: [
        // 上部图片居中 + 底部录音按钮固定在屏幕下方（稍上移）
        Column(
          children: [
            Expanded(
              child: Center(
                child: ShakeBox(tick: _shakeTick, child: WordImage(word: _word, size: 240)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: Column(
                children: [
                  Listener(
                    onPointerDown: (_) async {
                      if (_recording || _stage != _Stage.recording) return;
                      final speechSvc = context.read<AppState>().speech;
                      if (!speechSvc.available) {
                        // 未授权：本次点击触发系统授权框，授权后需再按一次开始录音
                        final ok = await speechSvc.ensurePermission();
                        if (mounted) setState(() {});
                        if (!ok) return;
                        return;
                      }
                      HapticFeedback.lightImpact();
                      setState(() {
                        _recording = true;
                        _recordElapsedMs = 0;
                      });
                      _recordTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
                        if (!mounted || !_recording) return;
                        setState(() => _recordElapsedMs += 200);
                      });
                      final speech = context.read<AppState>().speech;
                      Future.microtask(() async {
                        await speech.start(
                              targetWord: _word.word,
                              onFinished: _onSpeechResult,
                            );
                      });
                    },
                    onPointerUp: (_) {
                      if (!_recording) return;
                      _stopRecording();
                    },
                    onPointerCancel: (_) {
                      if (!_recording) return;
                      _stopRecording();
                    },
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _recording ? AppColors.error : AppColors.success,
                        boxShadow: [
                          BoxShadow(
                            color: (_recording ? AppColors.error : AppColors.success)
                                .withValues(alpha: 0.3),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Icon(
                        _recording ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _recording ? timerText : (speech.available ? '按住 开始录音' : '点击麦克风授予录音权限'),
                    style: TextStyle(
                      fontSize: _recording ? 22 : 13,
                      fontFamily: _recording ? 'monospace' : null,
                      color: _recording ? AppColors.error : AppColors.inkHint,
                      fontWeight: _recording ? FontWeight.w700 : FontWeight.normal,
                      letterSpacing: _recording ? 2 : 0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _recording
                        ? '松开手指结束录音'
                        : (speech.available ? '点击上方按钮开始' : '授权后按住按钮开始跟读'),
                    style: TextStyle(
                      fontSize: 11,
                      color: _recording ? AppColors.error.withValues(alpha: 0.7) : AppColors.inkHint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _recognizingView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        WordImage(word: _word, size: 240),
        const SizedBox(height: 40),
        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
        ),
        const SizedBox(height: 14),
        const Text('识别中...',
            style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _recordResultView(bool success) {
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          children: [
            WordImage(
              word: _word,
              size: 240,
              status: success ? ImageStatus.success : ImageStatus.error,
            ),
            if (success)
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.4),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 32),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 28),
        if (success) ...[
          const Text('跟读正确，进入拼写…',
              style: TextStyle(fontSize: 15, color: AppColors.success, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.success),
          ),
        ] else ...[
          Text(
            _failCount >= 3 ? '多次未识别，进入拼写…' : '跟读失败 $_failCount/3，再试一次',
            style: TextStyle(
              fontSize: 14,
              color: _failCount >= 3 ? AppColors.inkSoft : AppColors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          if (_failCount < 3)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GhostButton(
                  label: '重播',
                  icon: Icons.headset_rounded,
                  onPressed: () {
                    setState(() => _shakeTick = 0);
                    _replayAndRecord();
                  },
                ),
                // 加大间距，避免误触
                const SizedBox(width: 48),
                GradientButton(
                  label: '重录',
                  icon: Icons.mic_rounded,
                  danger: true,
                  onPressed: () {
                    setState(() {
                      _shakeTick = 0;
                      _stage = _Stage.recording;
                    });
                  },
                ),
              ],
            ),
        ],
      ],
    );

    // 只有失败页才摇头
    if (success) return content;
    return ShakeBox(tick: _shakeTick, child: content);
  }

  // ---- 拼写 ----
  Widget _spellingView() {
    final complete = _stage == _Stage.spelled;
    final disabled = complete || _wrongLetter != null;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShakeBox(
                    tick: _shakeTick,
                    child: WordImage(
                      word: _word,
                      size: 230,
                      status: complete
                          ? ImageStatus.success
                          : _wrongLetter != null
                              ? ImageStatus.error
                              : ImageStatus.none,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: 320,
                    child: Text(
                      _word.definition,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.inkSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  _letterSlots(complete),
                  const SizedBox(height: 18),
                  if (complete)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.successBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline_rounded,
                              size: 14, color: AppColors.success),
                          SizedBox(width: 4),
                          Text('拼写正确',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    )
                  else if (_wrongLetter != null)
                    Text(
                      _spellFailCount >= 3
                          ? '拼写失败 3 次，进入详情…'
                          : '拼写错误 $_spellFailCount/3，再试一次',
                      style: TextStyle(
                        fontSize: 11,
                        color: _spellFailCount >= 3 ? AppColors.inkSoft : AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else
                    const Text('在下方键盘输入字母…',
                        style: TextStyle(fontSize: 11, color: AppColors.inkHint)),
                ],
              ),
            ),
          ),
        ),
        // 内置练习键盘：仅保留字母键，错误输入直接触发报错，无需退格
        PracticeKeyboard(
          onLetter: _inputLetter,
          enabled: !disabled,
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _letterSlots(bool complete) {
    final key = _word.spellTarget;
    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据可用宽度和字母数动态计算每个字母槽的宽度；
        // 短语词边界（空格）使用明显更大的间距。
        final wordGap = 24.0;
        final letterCount = key.replaceAll(' ', '').length;
        final spaceCount = ' '.allMatches(key).length;
        final maxSlotWidth = 36.0;  // 每槽最大宽度（含 margin）
        final minSlotWidth = 22.0;  // 每槽最小宽度
        final available = constraints.maxWidth - spaceCount * wordGap;
        var slotWidth = (available / letterCount).clamp(minSlotWidth, maxSlotWidth);
        final letterSize = (slotWidth - 10).clamp(14.0, 22.0);
        final fontSize = (letterSize * 0.85).clamp(12.0, 22.0);

        final slots = <Widget>[];
        for (var i = 0; i < key.length; i++) {
          if (key[i] == ' ') {
            slots.add(SizedBox(width: wordGap));
            continue;
          }
          Color color = const Color(0xFFB9C2D6);
          String? letter;
          if (i < _accepted.length) {
            letter = _accepted[i].toUpperCase();
            color = complete ? AppColors.success : AppColors.primary;
          }
          if (!complete && _wrongLetter != null && i == _accepted.length) {
            letter = _wrongLetter!.toUpperCase();
            color = AppColors.error;
          }
          slots.add(AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: slotWidth - 10,
            child: Column(
              children: [
                Text(
                  letter ?? '',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    color: color,
                  ),
                ),
                Container(height: 2, margin: const EdgeInsets.only(top: 4), color: color),
              ],
            ),
          ));
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: slots,
          ),
        );
      },
    );
  }

  // ---- 单词详情 ----
  Widget _detailView() {
    final app = context.watch<AppState>();
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: LayoutBuilder(builder: (context, c) {
              final wide = c.maxWidth > 720;
              final image = WordImage(word: _word, size: wide ? 380 : 220);
              final info = Expanded(child: WordDetailBody(word: _word, showImage: false));
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 22, right: 28),
                      child: image,
                    ),
                    info,
                  ],
                );
              }
              return Column(
                children: [
                  image,
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, child: WordDetailBody(word: _word, showImage: false)),
                ],
              );
            }),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  app.isFavorite(_word) ? Icons.star_rounded : Icons.star_border_rounded,
                  color: app.isFavorite(_word) ? const Color(0xFFF5A623) : AppColors.inkHint,
                  size: 30,
                ),
                onPressed: () => app.toggleFavorite(_word),
              ),
              const Spacer(),
              GradientButton(
                label: _isLastWord ? '进入强化学习' : '继续下一个',
                icon: _isLastWord ? Icons.emoji_events_rounded : null,
                onPressed: _nextWord,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DefinitionCard extends StatelessWidget {
  final Word word;
  final VoidCallback onPlay;
  const _DefinitionCard({required this.word, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPlay,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primarySoft.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.graphic_eq_rounded, size: 13, color: AppColors.primary),
                const SizedBox(width: 5),
                const Text('Definition 点击即可播放',
                    style: TextStyle(fontSize: 10, color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 6),
            Text(word.definition,
                style: const TextStyle(fontSize: 12, height: 1.5, color: AppColors.ink)),
          ],
        ),
      ),
    );
  }
}

// 内置拼写练习键盘：仅保留字母键（错误输入直接触发报错，故无需退格），
// 去掉系统键盘的 123/符号/语音/中英切换等与拼写无关的按键，降低误触率；
// 字母键加大尺寸便于点按。
class PracticeKeyboard extends StatelessWidget {
  final ValueChanged<String> onLetter;
  final bool enabled;

  const PracticeKeyboard({
    super.key,
    required this.onLetter,
    this.enabled = true,
  });

  static const _row1 = ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'];
  static const _row2 = ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'];
  static const _row3 = ['z', 'x', 'c', 'v', 'b', 'n', 'm'];

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: !enabled,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.45,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              _buildRow(_row1),
              const SizedBox(height: 10),
              _buildRow(_row2),
              const SizedBox(height: 10),
              _buildRow(_row3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(List<String> letters) {
    final keys = <Widget>[];
    for (var i = 0; i < letters.length; i++) {
      keys.add(Expanded(
        child: _LetterKey(letter: letters[i], onTap: () => onLetter(letters[i])),
      ));
      if (i < letters.length - 1) keys.add(const SizedBox(width: 6));
    }
    return SizedBox(
      height: 72,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: keys,
      ),
    );
  }
}

class _LetterKey extends StatefulWidget {
  final String letter;
  final VoidCallback onTap;
  const _LetterKey({required this.letter, required this.onTap});

  @override
  State<_LetterKey> createState() => _LetterKeyState();
}

class _LetterKeyState extends State<_LetterKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() => _pressed = true);
        widget.onTap();
      },
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        decoration: BoxDecoration(
          color: _pressed ? const Color(0xFFD9DEEB) : const Color(0xFFF1F3F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            widget.letter.toUpperCase(),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
