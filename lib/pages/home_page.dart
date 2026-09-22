import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/word_book.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/plan_sheet.dart';
import 'study/study_session_page.dart';
import 'word_books_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final book = app.planBook;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: book == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _TopBar(book: book),
                  const SizedBox(height: 18),
                  _TodayProgressCard(book: book),
                  const SizedBox(height: 16),
                  _QuickGrid(),
                  const SizedBox(height: 16),
                  _HeatmapCard(),
                ],
              ),
      ),
    );
  }
}

// ───────────────────────── 顶部栏 ─────────────────────────

class _TopBar extends StatelessWidget {
  final WordBook book;
  const _TopBar({required this.book});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final streak = app.progress.streakDays;
    return Row(
      children: [
        // Logo
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4D7CFF), Color(0xFF6C5CE7)],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text('L',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 10),
        const Text('LexVault',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink)),

        const Spacer(),

        // 词书下拉
        GestureDetector(
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WordBooksPage())),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.chipBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(book.name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(width: 2),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 18, color: AppColors.inkSoft),
              ],
            ),
          ),
        ),

        const SizedBox(width: 10),

        // 连续天数徽章
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  size: 14, color: AppColors.primary),
              const SizedBox(width: 3),
              Text('$streak 天',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary)),
            ],
          ),
        ),

        const SizedBox(width: 10),

        // 通知
        const Icon(Icons.notifications_none_rounded,
            size: 22, color: AppColors.inkSoft),
      ],
    );
  }
}

// ───────────────────────── 今日进度大卡 ─────────────────────────

class _TodayProgressCard extends StatelessWidget {
  final WordBook book;
  const _TodayProgressCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final daily = app.dailyWordsOf(book);
    final todayLearned = app.todayLearned(book);
    final percent = daily > 0 ? (todayLearned / daily).clamp(0.0, 1.0) : 0.0;
    final remain = (daily - todayLearned).clamp(0, daily);
    final done = remain == 0;

    final learned = app.learnedCount(book);
    final total = book.words.length;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              const Text('今日进度',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const Spacer(),
              // 每日目标下拉
              GestureDetector(
                onTap: () => _openPlanSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: 12, color: AppColors.primary),
                      const SizedBox(width: 3),
                      Text('每日 $daily 词',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                      const SizedBox(width: 2),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 14, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 大数字 + 百分比
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$todayLearned',
                  style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      height: 1)),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('/ ',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSoft)),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('$daily 词',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.inkSoft)),
              ),
              const Spacer(),
              Text('${(percent * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success)),
            ],
          ),

          const SizedBox(height: 10),

          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: const Color(0xFFE8ECF4),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),

          const SizedBox(height: 10),

          // 剩余提示
          Text(
            done ? '今日目标已达成！继续加油' : '还差 $remain 词完成今日目标',
            style: TextStyle(
              fontSize: 13,
              color: done ? AppColors.success : AppColors.inkSoft,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 18),

          // 继续学习按钮
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
              onPressed: () => _start(context),
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: Text(done ? '继续学习' : '开始学习',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),

          const SizedBox(height: 16),

          // 底部横条：连续天数 + 全书进度
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department_rounded,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text('连续 ${app.progress.streakDays} 天',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary)),
                  ],
                ),
              ),
              const Spacer(),
              Text('全书 $learned / $total',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft)),
            ],
          ),
        ],
      ),
    );
  }

  void _openPlanSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PlanSheet(),
    );
  }

  void _start(BuildContext context) {
    final app = context.read<AppState>();
    final words = app.buildSessionWords(book);
    final dailyTarget = app.dailyWordsOf(book);
    final alreadyLearned = app.progress.todayLearnedCount(book.id);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudySessionPage(
          book: book,
          words: words,
          dailyTarget: dailyTarget,
          alreadyLearned: alreadyLearned,
        ),
        fullscreenDialog: true,
      ),
    );
  }
}

// ───────────────────────── 四宫格 ─────────────────────────

class _QuickGrid extends StatelessWidget {
  const _QuickGrid();

  @override
  Widget build(BuildContext context) {
    final items = [
      _GridItem(Icons.menu_book_rounded, '单词本', AppColors.primary, () {
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const WordBooksPage()));
      }),
      _GridItem(Icons.quiz_rounded, '错题本', const Color(0xFFF04E5E), () {}),
      _GridItem(Icons.star_rounded, '收藏', const Color(0xFF8B5CF6), () {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const WordBooksPage(openFavorites: true)));
      }),
      _GridItem(Icons.bar_chart_rounded, '设置', AppColors.success, () {}),
    ];
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: items,
    );
  }
}

class _GridItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _GridItem(this.icon, this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── GitHub 式热力图 ─────────────────────────

class _HeatmapCard extends StatelessWidget {
  const _HeatmapCard();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final log = app.progress.studyLog;
    // 最大单日量 → 决定颜色深浅分档
    final max = log.values.fold<int>(0, (m, v) => v > m ? v : m);

    final now = DateTime.now();
    // 取最近 18 周（126 天）
    const weeks = 18;
    const daysPerWeek = 7;
    final totalDays = weeks * daysPerWeek;
    final cells = <int>[];
    for (int i = totalDays - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key = d.toIso8601String().substring(0, 10);
      cells.add(log[key] ?? 0);
    }
    // 按周重排：每周 7 天
    final cols = <List<int>>[];
    for (int w = 0; w < weeks; w++) {
      cols.add(cells.sublist(w * daysPerWeek, (w + 1) * daysPerWeek));
    }
    // 调换行/列→rows[dayOfWeek][weekIdx]
    final rows = List.generate(daysPerWeek, (d) {
      return List.generate(weeks, (w) => cols[w][d]);
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('学习活动',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('近 $weeks 周',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          // 热力图网格
          SizedBox(
            height: 130,
            child: Row(
              children: [
                // 左侧星期标签
                SizedBox(
                  width: 18,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('一',
                          style: TextStyle(
                              fontSize: 9, color: AppColors.inkHint)),
                      Text('', style: TextStyle(fontSize: 9)),
                      Text('三',
                          style: TextStyle(
                              fontSize: 9, color: AppColors.inkHint)),
                      Text('', style: TextStyle(fontSize: 9)),
                      Text('五',
                          style: TextStyle(
                              fontSize: 9, color: AppColors.inkHint)),
                      Text('', style: TextStyle(fontSize: 9)),
                      Text('日',
                          style: TextStyle(
                              fontSize: 9, color: AppColors.inkHint)),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    children: List.generate(daysPerWeek, (dow) {
                      return Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: List.generate(weeks, (w) {
                            final val = rows[dow][w];
                            return Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 1.5),
                              decoration: BoxDecoration(
                                color: _levelColor(val, max),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 图例
          Row(
            children: [
              const Text('少',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.inkHint)),
              const SizedBox(width: 8),
              for (int i = 0; i < 5; i++) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _legendColor(i),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              const SizedBox(width: 4),
              const Text('多',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.inkHint)),
            ],
          ),
        ],
      ),
    );
  }

  Color _levelColor(int v, int max) {
    if (v == 0) return const Color(0xFFF0F3F8);
    final ratio = max > 0 ? v / max : 0.1;
    if (ratio < 0.2) return const Color(0xFFD0DBFF);
    if (ratio < 0.4) return const Color(0xFF9FB4FF);
    if (ratio < 0.7) return const Color(0xFF6B8BFF);
    return AppColors.primary;
  }

  Color _legendColor(int i) {
    const colors = [
      Color(0xFFF0F3F8),
      Color(0xFFD0DBFF),
      Color(0xFF9FB4FF),
      Color(0xFF6B8BFF),
      Color(0xFF3567F6),
    ];
    return colors[i];
  }
}
