import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/word.dart';
import '../../models/word_book.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/word_image.dart';
import '../complete_page.dart';

class ReviewQuestion {
  final Word answer;
  final List<Word> options;
  final bool imageToWord; // true=看图选词，false=看词选图
  ReviewQuestion({required this.answer, required this.options, required this.imageToWord});
}

class ReviewSessionPage extends StatefulWidget {
  final WordBook book;
  final List<Word> words;
  const ReviewSessionPage({super.key, required this.book, required this.words});

  @override
  State<ReviewSessionPage> createState() => _ReviewSessionPageState();
}

class _ReviewSessionPageState extends State<ReviewSessionPage> {
  final _rand = Random();
  late final List<ReviewQuestion> _questions;

  int _index = 0;
  Word? _selected;
  bool _answered = false;
  int _correctCount = 0;
  bool _redFlash = false;
  int _shakeTick = 0;
  int _playedIndex = -1;

  ReviewQuestion get _q => _questions[_index];

  @override
  void initState() {
    super.initState();
    _questions = widget.words.map(_buildQuestion).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playCurrent());
  }

  void _playCurrent() {
    if (_playedIndex == _index) return;
    _playedIndex = _index;
    context.read<AppState>().tts.speakWord(_q.answer.word, audio: _q.answer.audio);
  }

  ReviewQuestion _buildQuestion(Word answer) {
    // 干扰项：先取本词书本，不足时从其他词书本补
    final pool = <Word>{...widget.book.words}..remove(answer);
    final distractors = <Word>[];
    final poolList = pool.toList()..shuffle(_rand);
    distractors.addAll(poolList.take(3));
    if (distractors.length < 3) {
      final app = context.read<AppState>();
      for (final b in app.books) {
        if (b.id == widget.book.id) continue;
        for (final w in b.words) {
          if (distractors.length >= 3) break;
          if (w.word != answer.word) distractors.add(w);
        }
      }
    }
    final options = <Word>[answer, ...distractors.take(3)]..shuffle(_rand);
    return ReviewQuestion(
      answer: answer,
      options: options,
      imageToWord: _rand.nextBool(),
    );
  }

  Future<void> _choose(Word option) async {
    if (_answered) return;
    final correct = option.word == _q.answer.word;
    setState(() {
      _answered = true;
      _selected = option;
      if (correct) {
        _correctCount++;
        context.read<AppState>().sounds.success();
      } else {
        context.read<AppState>().sounds.error();
        _redFlash = true;
        _shakeTick++;
      }
    });
    if (!correct) {
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted) setState(() => _redFlash = false);
      });
    }
    await Future.delayed(Duration(milliseconds: correct ? 850 : 1400));
    if (!mounted) return;
    if (_index == _questions.length - 1) {
      final app = context.read<AppState>();
      await app.completeReview(widget.book, _correctCount, _questions.length);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CompletePage(
            book: widget.book,
            correct: _correctCount,
            total: _questions.length,
          ),
        ),
      );
    } else {
      setState(() {
        _index++;
        _selected = null;
        _answered = false;
      });
      _playCurrent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _q;
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.bg,
          body: SafeArea(
            child: Column(
              children: [
                StageHeader(
                  stageLabel: '强化阶段',
                  current: _index + 1,
                  total: _questions.length,
                  review: true,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: q.imageToWord ? _imageToWord(q) : _wordToImage(q),
                  ),
                ),
              ],
            ),
          ),
        ),
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _redFlash ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: Container(color: AppColors.errorBg),
          ),
        ),
      ],
    );
  }

  /// 题型一：看图片选单词。
  Widget _imageToWord(ReviewQuestion q) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ShakeBox(tick: _shakeTick, child: WordImage(word: q.answer, size: 220)),
        const SizedBox(height: 50),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: q.options.map((w) => _wordOption(q, w)).toList(),
        ),
      ],
    );
  }

  Widget _wordOption(ReviewQuestion q, Word w) {
    Color border = AppColors.chipBorder;
    Color bg = Colors.white;
    bool faded = false;
    if (_answered) {
      if (w.word == q.answer.word) {
        border = AppColors.success;
        bg = AppColors.successBg;
      } else if (w.word == _selected?.word) {
        border = AppColors.error;
        bg = AppColors.errorBg;
      } else {
        faded = true;
      }
    }
    return Opacity(
      opacity: faded ? 0.45 : 1,
      child: GestureDetector(
        onTap: () => _choose(w),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 158,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: border,
              width: _answered && (w.word == q.answer.word || w.word == _selected?.word) ? 2.5 : 1.2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 固定高度区域：长单词等比缩到一行，保证四张卡片视觉对齐
              SizedBox(
                height: 44,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(w.word,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(w.phonetic,
                  style: const TextStyle(fontSize: 12, color: AppColors.inkHint)),
            ],
          ),
        ),
      ),
    );
  }

  /// 题型二：看单词选图片。
  Widget _wordToImage(ReviewQuestion q) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(q.answer.word,
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, fontFamily: 'serif')),
        const SizedBox(height: 4),
        Text(q.answer.phonetic,
            style: const TextStyle(fontSize: 13, color: AppColors.inkHint)),
        const SizedBox(height: 34),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          alignment: WrapAlignment.center,
          children: q.options.map((w) => _imageOption(q, w)).toList(),
        ),
      ],
    );
  }

  Widget _imageOption(ReviewQuestion q, Word w) {
    ImageStatus status = ImageStatus.none;
    bool faded = false;
    if (_answered) {
      if (w.word == q.answer.word) {
        status = ImageStatus.success;
      } else if (w.word == _selected?.word) {
        status = ImageStatus.error;
      } else {
        faded = true;
      }
    }
    return Opacity(
      opacity: faded ? 0.45 : 1,
      child: GestureDetector(
        onTap: () => _choose(w),
        child: SizedBox(
          width: 158,
          child: Column(
            children: [
              ShakeBox(
                tick: w.word == _selected?.word && w.word != q.answer.word ? _shakeTick : 0,
                child: WordImage(word: w, size: 158, status: status),
              ),
              if (_answered) ...[
                const SizedBox(height: 6),
                Text(w.word,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: w.word == q.answer.word
                          ? AppColors.success
                          : w.word == _selected?.word
                              ? AppColors.error
                              : AppColors.inkHint,
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
