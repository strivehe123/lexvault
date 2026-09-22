import 'package:flutter/material.dart';
import 'word.dart';

/// 词书本（PET / 四级 / 考研 ……）。
///
/// JSON 示例见 assets/data/books/pet.json
class WordBook {
  final String id;
  final String name;
  final String fullName;
  final String badge;
  final String description;

  /// 每组（每日）学习的单词数，学习阶段与强化阶段都使用该数量。
  final int dailyWords;

  /// 封面 / 主题渐变色。
  final List<Color> gradient;
  final List<Word> words;

  const WordBook({
    required this.id,
    required this.name,
    required this.fullName,
    this.badge = '',
    this.description = '',
    this.dailyWords = 30,
    this.gradient = const [Color(0xFF34D399), Color(0xFF059669)],
    this.words = const [],
  });

  factory WordBook.fromJson(Map<String, dynamic> json) => WordBook(
        id: json['id'] as String,
        name: json['name'] as String,
        fullName: json['fullName'] as String? ?? json['name'] as String,
        badge: json['badge'] as String? ?? '',
        description: json['description'] as String? ?? '',
        dailyWords: (json['dailyWords'] as num?)?.toInt() ?? 30,
        gradient: (json['gradient'] as List<dynamic>? ?? [0xFF34D399, 0xFF059669])
            .map((e) => Color(int.parse(e.toString())))
            .toList(),
        words: (json['words'] as List<dynamic>? ?? [])
            .map((e) => Word.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
