import 'package:flutter_test/flutter_test.dart';
import 'package:vacmaster/models/word.dart';

void main() {
  test('Word.fromJson parses word fields', () {
    final w = Word.fromJson({
      'word': 'Replace',
      'phonetic': '/rɪˈpleɪs/',
      'pos': 'verb',
      'chinese': '替换',
      'definition': 'To take the place of something or someone.',
      'examples': ['"I need to replace the old batteries."'],
    });
    expect(w.word, 'Replace');
    expect(w.spellKey, 'replace');
    expect(w.examples.length, 1);
  });

  test('spellKey strips spaces and punctuation for phrases', () {
    expect(const Word(word: 'video clip').spellKey, 'videoclip');
    expect(const Word(word: 'Goodbye').spellKey, 'goodbye');
  });
}
