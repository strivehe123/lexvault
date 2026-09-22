/// 单词数据模型。
///
/// 对应词库 JSON 中 words 数组里的每一项：
/// {
///   "word": "replace",
///   "phonetic": "/rɪˈpleɪs/",
///   "pos": "verb",
///   "chinese": "替换",
///   "definition": "To take the place of something or someone.",
///   "examples": ["\"I need to replace the old batteries.\""],
///   "image": null   // 可空：assets 路径或网络 URL；为空时用渐变占位图
/// }
class Word {
  final String word;
  final String phonetic;
  final String pos;
  final String chinese;
  final String definition;
  final List<String> examples;

  /// 预留字段：后续接入 AI 双图 / 用户图片。支持 assets/ 与 http(s)。
  final String? image;

  /// 本地发音音频（assets 路径，如 "assets/audio/pet/abroad.mp3"）；
  /// 为空或播放失败时回退系统 TTS。
  final String? audio;

  const Word({
    required this.word,
    this.phonetic = '',
    this.pos = '',
    this.chinese = '',
    this.definition = '',
    this.examples = const [],
    this.image,
    this.audio,
  });

  factory Word.fromJson(Map<String, dynamic> json) => Word(
        word: (json['word'] as String).trim(),
        phonetic: json['phonetic'] as String? ?? '',
        pos: json['pos'] as String? ?? '',
        chinese: json['chinese'] as String? ?? '',
        definition: json['definition'] as String? ?? json['definitionEn'] as String? ?? '',
        examples: (json['examples'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        image: json['image'] as String?,
        audio: json['audio'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'word': word,
        'phonetic': phonetic,
        'pos': pos,
        'chinese': chinese,
        'definition': definition,
        'examples': examples,
        if (image != null) 'image': image,
        if (audio != null) 'audio': audio,
      };

  /// 仅保留字母的小写形式，用于语音识别比对（忽略空格/标点）。
  String get spellKey =>
      word.toLowerCase().replaceAll(RegExp(r"[^a-zà-ÿ']"), '').replaceAll("'", '');

  /// 拼写练习目标：仅保留小写字母与单个空格。
  /// 空格保留为"词边界"，拼写槽在该处显示更大间距，输入时自动补入；
  /// 撇号/连字符等标点忽略（键盘上没有这些键）。
  String get spellTarget {
    final t = word.toLowerCase().replaceAll(RegExp(r'[^a-z ]'), ' ');
    return t.replaceAll(RegExp(r' +'), ' ').trim();
  }

  /// 例句中把目标词（含词形变化）染蓝时使用的匹配正则。
  RegExp get highlightRegex {
    final escaped = RegExp.escape(word);
    return RegExp('$escaped[a-zA-Z]*', caseSensitive: false);
  }
}
