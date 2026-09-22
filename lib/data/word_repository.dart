import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/word_book.dart';

/// 从 assets/data/books/ 加载所有词书本。
/// 后续接入用户词库时，新增一个同结构 JSON 文件并在 library.json 注册即可。
class WordRepository {
  Future<List<WordBook>> loadBooks() async {
    final manifestRaw = await rootBundle.loadString('assets/data/books/library.json');
    final manifest = jsonDecode(manifestRaw) as Map<String, dynamic>;
    final files = (manifest['files'] as List<dynamic>).cast<String>();

    final books = <WordBook>[];
    for (final f in files) {
      final raw = await rootBundle.loadString('assets/data/books/$f');
      books.add(WordBook.fromJson(jsonDecode(raw) as Map<String, dynamic>));
    }
    return books;
  }
}
