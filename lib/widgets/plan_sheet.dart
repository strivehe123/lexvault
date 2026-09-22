import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/word_book.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// 更改计划底部弹窗：两步（选词书 → 设每日目标）。
class PlanSheet extends StatefulWidget {
  const PlanSheet({super.key});

  @override
  State<PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends State<PlanSheet> {
  static const _dailyOptions = [5, 10, 15, 20, 30, 40, 50];

  int _step = 0; // 0 = 选词书, 1 = 设目标
  WordBook? _selected;
  int _daily = 20;

  int get _dailyIndex => _dailyOptions.contains(_daily)
      ? _dailyOptions.indexOf(_daily)
      : 3; // 默认 20

  @override
  void initState() {
    super.initState();
    // 预选当前计划
    final app = context.read<AppState>();
    _selected = app.planBook;
    if (_selected != null) {
      final saved = app.dailyWordsOf(_selected!);
      _daily = _dailyOptions.contains(saved) ? saved : 20;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              _header(context),
              Expanded(
                child: _step == 0 ? _buildBookList(scroll) : _buildDailyGoal(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      child: Row(
        children: [
          if (_step == 1)
            GestureDetector(
              onTap: () => setState(() => _step = 0),
              child: const Row(
                children: [
                  Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.inkSoft),
                  SizedBox(width: 4),
                  Text('返回选择词库', style: TextStyle(fontSize: 13, color: AppColors.inkSoft)),
                ],
              ),
            )
          else
            Text(_step == 0 ? '选择词库' : '制定学习计划',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.inkSoft),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // ---------- Step 1: 选择词库 ----------
  Widget _buildBookList(ScrollController scroll) {
    final app = context.read<AppState>();
    final books = app.books;
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _Tab(label: '全部', active: true),
              SizedBox(width: 24),
              _Tab(label: 'CEFR', active: false),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.builder(
            controller: scroll,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: books.length,
            itemBuilder: (_, i) => _BookCard(
              book: books[i],
              selected: _selected?.id == books[i].id,
              onTap: () => setState(() => _selected = books[i]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                    _selected != null ? AppColors.primary : const Color(0xFFE4E9F4),
                foregroundColor: _selected != null ? Colors.white : AppColors.inkHint,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _selected != null ? () => setState(() => _step = 1) : null,
              child: const Text('下一步：设置每日目标',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Step 2: 设置每日目标 ----------
  Widget _buildDailyGoal() {
    final book = _selected!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(36),
            ),
            child: const Icon(Icons.menu_book_rounded, size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          const Text('制定你的学习计划',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
              children: [
                const TextSpan(text: '已选择 '),
                TextSpan(
                  text: book.name,
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: '，每天学习多少个新单词？'),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$_daily',
                  style: const TextStyle(
                      fontSize: 56, fontWeight: FontWeight.w900, color: AppColors.primary, height: 1)),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text('个/天', style: TextStyle(fontSize: 16, color: AppColors.inkSoft)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: const Color(0xFFE4E9F4),
              thumbColor: Colors.white,
              overlayColor: AppColors.primary.withValues(alpha: 0.12),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12, elevation: 2),
            ),
            child: Slider(
              value: _dailyIndex.toDouble(),
              min: 0,
              max: (_dailyOptions.length - 1).toDouble(),
              divisions: _dailyOptions.length - 1,
              label: '$_daily',
              onChanged: (v) => setState(() => _daily = _dailyOptions[v.round()]),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('5', style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                Text('10', style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                Text('15', style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                Text('20', style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                Text('30', style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                Text('40', style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                Text('50', style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('轻松', style: TextStyle(fontSize: 11, color: AppColors.inkHint)),
                Text('适中', style: TextStyle(fontSize: 11, color: AppColors.inkHint)),
                Text('挑战', style: TextStyle(fontSize: 11, color: AppColors.inkHint)),
              ],
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () async {
                await context.read<AppState>().setPlan(book, _daily);
                if (mounted) Navigator.pop(context);
              },
              child: const Text('开始我的学习之旅',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  const _Tab({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
              color: active ? AppColors.primary : AppColors.inkSoft,
            )),
        const SizedBox(height: 6),
        Container(
          width: 28,
          height: 3,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

class _BookCard extends StatelessWidget {
  final WordBook book;
  final bool selected;
  final VoidCallback onTap;
  const _BookCard({required this.book, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFEDEFF5),
            width: selected ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 封面
              Stack(
                children: [
                  Container(
                    height: 110,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: book.gradient.length >= 2
                            ? book.gradient
                            : [book.gradient.first, book.gradient.first],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        book.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.menu_book_rounded, size: 11, color: Colors.white),
                          const SizedBox(width: 3),
                          Text('${book.words.length} 词',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  if (selected)
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: AppColors.primary,
                        child: Icon(Icons.check_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: selected ? AppColors.primary : AppColors.ink,
                        )),
                    const SizedBox(height: 4),
                    Text(book.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppColors.inkSoft, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
