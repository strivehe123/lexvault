import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/word.dart';
import '../models/word_book.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'book_detail_page.dart';
import 'study/study_session_page.dart';

class WordBooksPage extends StatelessWidget {
  /// 预留：从首页「我的收藏」进入时展示收藏单词。
  final bool openFavorites;
  const WordBooksPage({super.key, this.openFavorites = false});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.ink),
        title: Text(openFavorites ? '我的收藏' : '我的单词本',
            style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800)),
      ),
      body: openFavorites ? _FavoritesList() : _BooksGrid(books: app.books),
    );
  }
}

class _BooksGrid extends StatelessWidget {
  final List<WordBook> books;
  const _BooksGrid({required this.books});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
      children: [
        const Text('管理和练习你的单词本，制定学习计划，系统化提升词汇量和记忆效果。',
            style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth;
          final cardWidth = width > 700 ? (width - 16) / 2 : width;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final b in books)
                SizedBox(
                  width: cardWidth,
                  child: _BookCard(book: b),
                ),
              SizedBox(width: cardWidth, child: const _AddBookCard()),
            ],
          );
        }),
      ],
    );
  }
}

class _BookCard extends StatelessWidget {
  final WordBook book;
  const _BookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final learned = app.learnedCount(book);
    final isPlan = app.planBook?.id == book.id;
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面
          Container(
            height: 110,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: book.gradient,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (book.badge.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(book.badge,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                      ),
                    const Spacer(),
                    if (isPlan)
                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  ],
                ),
                const Spacer(),
                Text(book.name,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                Text(book.fullName,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('已学习 $learned', style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
                    const Spacer(),
                    Text('总量 ${book.words.length}',
                        style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            app.setPlanBook(book);
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
                          },
                          child: const Text('开始学习',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.chipBorder),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => BookDetailPage(book: book)),
                          ),
                          child: const Text('查看详情',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.inkSoft,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddBookCard extends StatelessWidget {
  const _AddBookCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.chipBorder, style: BorderStyle.solid),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_circle_outline_rounded, size: 30, color: AppColors.primary),
            SizedBox(height: 8),
            Text('添加单词本', style: TextStyle(fontSize: 13, color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }
}

class _FavoritesList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final favs = app.progress.favorites;
    final all = <String, Word>{
      for (final b in app.books)
        for (final w in b.words) w.word: w
    };
    final words = favs.map((key) => all[key]).whereType<Word>().toList();
    if (words.isEmpty) {
      return const Center(
        child: Text('还没有收藏的单词', style: TextStyle(color: AppColors.inkSoft)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(18),
      itemCount: words.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final w = words[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w.word,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    Text('${w.phonetic}  ${w.chinese}',
                        style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.volume_up_rounded, color: AppColors.primary),
                onPressed: () => app.tts.speakWord(w.word, audio: w.audio),
              ),
            ],
          ),
        );
      },
    );
  }
}
