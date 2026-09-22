import 'dart:math';

import 'package:flutter/material.dart';

import '../data/word_repository.dart';
import '../models/word.dart';
import '../models/word_book.dart';
import '../services/progress_service.dart';
import '../services/sound_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    WordRepository? repository,
    ProgressService? progress,
    TtsService? tts,
    SoundService? sounds,
    SpeechService? speech,
  })  : _repository = repository ?? WordRepository(),
        progress = progress ?? ProgressService(),
        tts = tts ?? TtsService(),
        sounds = sounds ?? SoundService(),
        speech = speech ?? SpeechService();

  final WordRepository _repository;
  final ProgressService progress;
  final TtsService tts;
  final SoundService sounds;
  final SpeechService speech;

  List<WordBook> books = [];
  WordBook? planBook;

  Future<void> init() async {
    await progress.init();
    await Future.wait([sounds.init(), tts.init(), speech.init()]);
    books = await _repository.loadBooks();
    final savedId = progress.planBookId;
    planBook = books.where((b) => b.id == savedId).isNotEmpty
        ? books.firstWhere((b) => b.id == savedId)
        : (books.where((b) => b.id == 'cet4').isNotEmpty
            ? books.firstWhere((b) => b.id == 'cet4')
            : (books.isNotEmpty ? books.first : null));
    notifyListeners();
  }

  void setPlanBook(WordBook book) {
    planBook = book;
    progress.setPlanBook(book.id);
    notifyListeners();
  }

  @override
  void dispose() {
    tts.dispose();
    super.dispose();
  }

  /// 切换词书并设置每日目标。
  Future<void> setPlan(WordBook book, int dailyWords) async {
    planBook = book;
    await progress.setPlanBook(book.id);
    await progress.setDailyWords(book.id, dailyWords);
    notifyListeners();
  }

  /// 仅更新当前词书的每日目标。
  Future<void> updateDailyWords(int dailyWords) async {
    final book = planBook;
    if (book == null) return;
    await progress.setDailyWords(book.id, dailyWords);
    notifyListeners();
  }

  /// 取当前词书的每日目标（用户设置优先，否则用词书默认值）。
  int dailyWordsOf(WordBook book) {
    final saved = progress.dailyWords(book.id);
    return saved > 0 ? saved : book.dailyWords;
  }

  /// 今日已学单词数。
  int todayLearned(WordBook book) => progress.todayLearnedCount(book.id);

  /// 今日任务是否已完成。
  bool isTodayDone(WordBook book) => todayLearned(book) >= dailyWordsOf(book);

  WordBook? bookById(String id) {
    final matches = books.where((b) => b.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  int learnedCount(WordBook book) => progress.learnedCount(book.id);

  double progressOf(WordBook book) =>
      book.words.isEmpty ? 0 : progress.learnedCount(book.id) / book.words.length;

  bool isFavorite(Word w) => progress.isFavorite(w.word);

  Future<void> toggleFavorite(Word w) async {
    await progress.toggleFavorite(w.word);
    notifyListeners();
  }

  /// 学习阶段取词：优先取未学过的词；不足一组时从头补齐（新一轮复习）。
  /// 每组内随机排序，避免总是按 a-b-c 字典顺序出词。
  List<Word> buildSessionWords(WordBook book) {
    final count = dailyWordsOf(book).clamp(1, book.words.length);
    final learned = progress.learnedWords(book.id);
    final fresh = book.words.where((w) => !learned.contains(w.word)).toList()..shuffle(Random());
    if (fresh.length >= count) return fresh.take(count).toList();
    final result = <Word>[...fresh];
    for (final w in book.words) {
      if (result.length >= count) break;
      result.add(w);
    }
    return result..shuffle(Random());
  }

  /// 学习阶段完成：登记已学 + 打卡 + 累加今日学习量。
  Future<void> completeStudy(WordBook book, List<Word> sessionWords) async {
    await progress.markLearned(book.id, sessionWords.map((w) => w.word).toList());
    await progress.addTodayLearned(book.id, sessionWords.length);
    await progress.markToday();
    notifyListeners();
  }

  /// 单个单词学习完成（进入详情页时调用），实时保存进度。
  /// 这样用户中途退出也能记住已学过的单词。
  Future<void> markWordLearned(WordBook book, Word word) async {
    await progress.markLearned(book.id, [word.word]);
    await progress.addTodayLearned(book.id, 1);
    await progress.addTodayWord(book.id, word.word);
    await progress.markToday();
    notifyListeners();
  }

  /// 今天学过的所有单词（按学习顺序，保持去重），用于强化阶段。
  List<Word> todayLearnedWords(WordBook book) {
    final names = progress.todayWordList(book.id);
    final byWord = {for (final w in book.words) w.word: w};
    return names.map((s) => byWord[s]).whereType<Word>().toList();
  }

  /// 强化阶段完成：轮次 +1、记录正确数、打卡。
  Future<void> completeReview(WordBook book, int correct, int total) async {
    await progress.incrementRound(book.id);
    await progress.setLastResult(book.id, correct, total);
    await progress.markToday();
    notifyListeners();
  }
}
