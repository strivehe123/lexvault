import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 本地学习进度：已学单词、收藏、练习轮次、打卡日期、最近一次强化结果。
class ProgressService {
  static const _kPlanBook = 'plan_book_id';
  static const _kActiveDays = 'active_days';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ---- 当前学习计划 ----
  String? get planBookId => _prefs.getString(_kPlanBook);
  Future<void> setPlanBook(String id) => _prefs.setString(_kPlanBook, id);

  // ---- 已学单词（按词书本）----
  Set<String> learnedWords(String bookId) =>
      _prefs.getStringList('learned_$bookId')?.toSet() ?? <String>{};

  bool isLearned(String bookId, String word) => learnedWords(bookId).contains(word);

  Future<void> markLearned(String bookId, List<String> words) async {
    final set = learnedWords(bookId);
    set.addAll(words);
    await _prefs.setStringList('learned_$bookId', set.toList());
  }

  int learnedCount(String bookId) => learnedWords(bookId).length;

  // ---- 收藏 ----
  Set<String> get favorites => _prefs.getStringList('favorites')?.toSet() ?? <String>{};

  bool isFavorite(String key) => favorites.contains(key);

  Future<void> toggleFavorite(String key) async {
    final set = favorites;
    set.contains(key) ? set.remove(key) : set.add(key);
    await _prefs.setStringList('favorites', set.toList());
  }

  // ---- 强化练习轮次 / 完成率 ----
  int rounds(String bookId) => _prefs.getInt('rounds_$bookId') ?? 0;
  Future<void> incrementRound(String bookId) =>
      _prefs.setInt('rounds_$bookId', rounds(bookId) + 1);

  /// 最近一次强化的正确数 / 总数。
  (int, int) lastResult(String bookId) {
    final raw = _prefs.getString('last_result_$bookId');
    if (raw == null) return (0, 0);
    final l = jsonDecode(raw) as List<dynamic>;
    return (l[0] as int, l[1] as int);
  }

  Future<void> setLastResult(String bookId, int correct, int total) =>
      _prefs.setString('last_result_$bookId', jsonEncode([correct, total]));

  // ---- 每日学习日志（按全局汇总所有词书，供热力图使用）----
  /// 按日期聚合的学习次数（JSON map，键 YYYY-MM-DD，值 int）。
  Map<String, int> get studyLog {
    final raw = _prefs.getString('study_log');
    if (raw == null) return {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  Future<void> _incStudyLog(int delta) async {
    if (delta <= 0) return;
    final log = studyLog;
    final key = DateTime.now().toIso8601String().substring(0, 10);
    log[key] = (log[key] ?? 0) + delta;
    await _prefs.setString('study_log', jsonEncode(log));
  }

  /// 连续打卡天数（截至今天）：activeDays 倒序连到今天的计数。
  int get streakDays {
    final set = activeDays.toSet();
    int streak = 0;
    DateTime d = DateTime.now();
    // 今天没打卡则从昨天算（activeDays 在 markToday 时加入）
    while (true) {
      final k = d.toIso8601String().substring(0, 10);
      if (set.contains(k)) {
        streak++;
        d = d.subtract(const Duration(days: 1));
      } else if (streak == 0 && k == DateTime.now().toIso8601String().substring(0, 10)) {
        // 今天还没打卡，看昨天
        d = d.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  // ---- 打卡日历 ----
  List<String> get activeDays => _prefs.getStringList(_kActiveDays) ?? [];

  Future<void> markToday() async {
    final days = activeDays.toSet();
    days.add(DateTime.now().toIso8601String().substring(0, 10));
    await _prefs.setStringList(_kActiveDays, days.toList());
  }

  // ---- 今日已学单词数（按词书本，按日期）----
  /// 返回今天已学的单词数；若不是今天则返回 0。
  int todayLearnedCount(String bookId) {
    final raw = _prefs.getString('today_$bookId');
    if (raw == null) return 0;
    final idx = raw.indexOf(':');
    if (idx < 0) return 0;
    final date = raw.substring(0, idx);
    if (date != DateTime.now().toIso8601String().substring(0, 10)) return 0;
    return int.tryParse(raw.substring(idx + 1)) ?? 0;
  }

  /// 累加今日已学单词数。
  Future<void> addTodayLearned(String bookId, int count) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final current = todayLearnedCount(bookId);
    await _prefs.setString('today_$bookId', '$today:${current + count}');
    await _incStudyLog(count);
  }

  // ---- 今日已学单词列表（按词书本，供强化阶段使用）----
  /// 今天学过的单词（有序、去重）；若记录不是今天则返回空列表。
  List<String> todayWordList(String bookId) {
    final date = _prefs.getString('today_words_date_$bookId');
    if (date != DateTime.now().toIso8601String().substring(0, 10)) return [];
    return _prefs.getStringList('today_words_$bookId') ?? [];
  }

  /// 记录今天学的一个单词（跨天自动清空，同词去重）。
  Future<void> addTodayWord(String bookId, String word) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final dateKey = 'today_words_date_$bookId';
    if (_prefs.getString(dateKey) != today) {
      await _prefs.setString(dateKey, today);
      await _prefs.setStringList('today_words_$bookId', [word]);
    } else {
      final list = _prefs.getStringList('today_words_$bookId') ?? [];
      if (!list.contains(word)) list.add(word);
      await _prefs.setStringList('today_words_$bookId', list);
    }
  }

  // ---- 每日目标（用户覆盖词书默认值）----
  /// 返回用户设置的每日目标；0 表示使用词书默认值。
  int dailyWords(String bookId) => _prefs.getInt('daily_$bookId') ?? 0;

  Future<void> setDailyWords(String bookId, int count) =>
      _prefs.setInt('daily_$bookId', count);
}
