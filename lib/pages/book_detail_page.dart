import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/word.dart';
import '../models/word_book.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/word_image.dart';

class BookDetailPage extends StatefulWidget {
  final WordBook book;
  const BookDetailPage({super.key, required this.book});

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  static const _pageSize = 10;
  late final List<Word> _all;
  late List<Word> _filtered;
  Word? _selected;
  int _page = 1;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _all = widget.book.words;
    _filtered = _all;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _search(String kw) {
    final k = kw.trim().toLowerCase();
    setState(() {
      _filtered = k.isEmpty
          ? _all
          : _all
              .where((w) =>
                  w.word.toLowerCase().contains(k) ||
                  w.chinese.contains(kw.trim()) ||
                  w.definition.toLowerCase().contains(k))
              .toList();
      _page = 1;
    });
  }

  int get _pageCount => (_filtered.length / _pageSize).ceil().clamp(1, 1 << 31);

  List<Word> get _pageWords {
    final start = (_page - 1) * _pageSize;
    return _filtered.skip(start).take(_pageSize).toList();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: LayoutBuilder(builder: (context, c) {
                final wide = c.maxWidth > 820;
                final listPanel = Container(
                  margin: const EdgeInsets.all(14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      _searchBar(),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _pageWords.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final w = _pageWords[i];
                            final learned = app.progress.isLearned(widget.book.id, w.word);
                            final selected = wide && _selected?.word == w.word;
                            return Material(
                              color: selected ? AppColors.primarySoft : const Color(0xFFF5F7FB),
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  if (wide) {
                                    setState(() => _selected = w);
                                  } else {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => _WordDetailRoute(book: widget.book, word: w),
                                      ),
                                    );
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(w.word,
                                                style: const TextStyle(
                                                    fontSize: 13, fontWeight: FontWeight.w800)),
                                            Text(w.chinese,
                                                style: const TextStyle(
                                                    fontSize: 11, color: AppColors.inkSoft)),
                                          ],
                                        ),
                                      ),
                                      if (learned)
                                        const Icon(Icons.check_circle_rounded,
                                            size: 16, color: AppColors.primary),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      _pager(),
                    ],
                  ),
                );
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (wide)
                      SizedBox(width: 320, child: listPanel)
                    else
                      Expanded(child: listPanel),
                    if (wide)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(0, 14, 14, 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: _selected == null
                                  ? const Center(
                                      child: Text('请从左侧选择一个单词查看详情',
                                          style: TextStyle(color: AppColors.inkHint, fontSize: 12)),
                                    )
                                  : WordDetailBody(word: _selected!),
                        ),
                      ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, const Color(0xFFEFF4FF)],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.book.badge.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(widget.book.badge,
                          style: const TextStyle(fontSize: 9, color: AppColors.primary)),
                    ),
                  const SizedBox(height: 4),
                  Text(widget.book.name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  Text('系列 ${widget.book.fullName} · ${widget.book.words.length} 个单词',
                      style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
                ],
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('开始练习', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 38,
            child: TextField(
              controller: _searchCtrl,
              onChanged: _search,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                hintText: '搜索单词或释义…',
                hintStyle: const TextStyle(fontSize: 12, color: AppColors.inkHint),
                prefixIcon: const Icon(Icons.search_rounded, size: 17),
                filled: true,
                fillColor: const Color(0xFFF5F7FB),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 38,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _search(_searchCtrl.text),
            child: const Text('搜索', style: TextStyle(fontSize: 12)),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 18),
          onPressed: () {
            _searchCtrl.clear();
            _search('');
          },
        ),
      ],
    );
  }

  Widget _pager() {
    final pages = _pageCount;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _pageBtn(Icons.chevron_left_rounded, _page > 1 ? () => setState(() => _page--) : null),
          const SizedBox(width: 6),
          for (var p = 1; p <= pages && p <= 3; p++) _pageNum(p),
          if (pages > 4) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('…', style: TextStyle(fontSize: 11, color: AppColors.inkHint)),
            ),
            _pageNum(pages),
          ],
          const SizedBox(width: 6),
          _pageBtn(Icons.chevron_right_rounded,
              _page < pages ? () => setState(() => _page++) : null),
        ],
      ),
    );
  }

  Widget _pageNum(int p) => GestureDetector(
        onTap: () => setState(() => _page = p),
        child: Container(
          width: 26,
          height: 26,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            color: p == _page ? AppColors.primary : const Color(0xFFF5F7FB),
          ),
          child: Center(
            child: Text('$p',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: p == _page ? Colors.white : AppColors.inkSoft,
                )),
          ),
        ),
      );

  Widget _pageBtn(IconData icon, VoidCallback? onTap) => GestureDetector(
        onTap: onTap,
        child: Icon(icon, size: 18, color: onTap == null ? AppColors.inkHint : AppColors.inkSoft),
      );
}

class _WordDetailRoute extends StatelessWidget {
  final WordBook book;
  final Word word;
  const _WordDetailRoute({required this.book, required this.word});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.ink),
        title: Text(word.word, style: const TextStyle(color: AppColors.ink)),
      ),
      body: SafeArea(child: WordDetailBody(word: word)),
    );
  }
}

/// 单词详情内容（词书本详情页与学习流程详情页共用）。
class WordDetailBody extends StatelessWidget {
  final Word word;

  /// 是否显示内嵌配图。学习流程详情页顶部已有大图时传 false。
  final bool showImage;
  const WordDetailBody({super.key, required this.word, this.showImage = true});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final wordColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(word.word,
                    maxLines: 1,
                    style: const TextStyle(
                        fontSize: 30, fontWeight: FontWeight.w900, fontFamily: 'serif')),
              ),
            ),
            GestureDetector(
              onTap: () => app.tts.speakWord(word.word, audio: word.audio),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
        Text(word.phonetic,
            style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
        const SizedBox(height: 8),
        Text(word.chinese,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ],
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showImage)
            Row(
              children: [
                SizedBox(width: 150, height: 150, child: WordImage(word: word, size: 150)),
                const SizedBox(width: 20),
                Expanded(child: wordColumn),
              ],
            )
          else
            SizedBox(width: double.infinity, child: wordColumn),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 110,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    const Text('词性',
                        style: TextStyle(fontSize: 10, color: AppColors.inkHint)),
                    const SizedBox(height: 6),
                    Text(word.pos,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.chipBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('● 定义',
                          style: TextStyle(fontSize: 10, color: AppColors.inkHint)),
                      const SizedBox(height: 6),
                      Builder(builder: (_) {
                        final parts = word.definition.split('|');
                        final en = parts[0];
                        final zh = parts.length > 1 ? parts[1] : '';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(en,
                                style: const TextStyle(fontSize: 13, height: 1.5)),
                            if (zh.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(zh,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      height: 1.4,
                                      color: AppColors.inkHint)),
                            ],
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.chipBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.format_quote_rounded, size: 14, color: AppColors.inkHint),
                    SizedBox(width: 6),
                    Text('例句', style: TextStyle(fontSize: 11, color: AppColors.inkHint)),
                  ],
                ),
                const SizedBox(height: 10),
                ...word.examples.map((e) {
                      final parts = e.split('|');
                      final en = parts[0];
                      final zh = parts.length > 1 ? parts[1] : '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 6, right: 8),
                              child: Icon(Icons.circle, size: 5, color: AppColors.primary),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _HighlightedText(sentence: en, word: word),
                                  if (zh.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(zh,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              height: 1.4,
                                              color: AppColors.inkHint)),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 例句中目标词染蓝（供学习详情页也复用）。
class _HighlightedText extends StatelessWidget {
  final String sentence;
  final Word word;
  const _HighlightedText({required this.sentence, required this.word});

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final matches = word.highlightRegex.allMatches(sentence).toList();
    var last = 0;
    for (final m in matches) {
      spans.add(TextSpan(text: sentence.substring(last, m.start)));
      spans.add(TextSpan(
        text: sentence.substring(m.start, m.end),
        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
      ));
      last = m.end;
    }
    spans.add(TextSpan(text: sentence.substring(last)));
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 13, height: 1.6, color: AppColors.ink),
        children: spans,
      ),
    );
  }
}
