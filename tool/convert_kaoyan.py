"""
将 KaoYan_3.json (JSONL) 转换为 VAC Master 词书格式 kaoyan.json。

源字段：
  headWord / content.word.content.{usphone, ukphone, trans[], sentence.sentences[]}
目标字段：
  word, phonetic, pos, chinese, definition, examples
"""
import json
import sys
from pathlib import Path

SRC = Path(r"C:\Users\coder\Downloads\1521164658897_KaoYan_3\KaoYan_3.json")
DST = Path(r"d:\study_hxt\luffy_spider\vacmaster\assets\data\books\kaoyan.json")

# 词性映射（词典里是 vt/vi/n/adj 等 → 显示用英文）
POS_MAP = {
    "n": "noun", "v": "verb", "vt": "verb", "vi": "verb",
    "adj": "adjective", "adv": "adverb", "pron": "pronoun",
    "prep": "preposition", "conj": "conjunction", "interj": "exclamation",
    "exclamation": "exclamation", "num": "numeral", "art": "article",
    "aux": "auxiliary", "modal": "modal",
}


def norm_pos(p: str) -> str:
    p = p.strip().lower().rstrip(".")
    return POS_MAP.get(p, p)


def fmt_phonetic(phone: str) -> str:
    p = (phone or "").strip()
    if not p:
        return ""
    if p.startswith("/") or p.startswith("["):
        return p
    return f"/{p}/"


def conv_word(raw: dict) -> dict:
    head = raw["headWord"]
    c = raw["content"]["word"]["content"]

    # 音标：优先美音
    phonetic = fmt_phonetic(c.get("usphone") or c.get("ukphone") or "")

    # 释义：所有 trans 合并
    trans = c.get("trans") or []
    chinese_parts = []
    def_parts = []
    pos_set = []
    for t in trans:
        cn = (t.get("tranCn") or "").strip().rstrip("<")
        en = (t.get("tranOther") or "").strip()
        pos = norm_pos(t.get("pos") or "")
        if cn:
            chinese_parts.append(cn)
        if en and en not in def_parts:
            def_parts.append(en)
        if pos and pos not in pos_set:
            pos_set.append(pos)

    chinese = "；".join(chinese_parts)
    definition = def_parts[0] if def_parts else ""
    pos = " & ".join(pos_set) if pos_set else ""

    # 例句：取 sContent，用引号包裹
    sentences = (c.get("sentence") or {}).get("sentences") or []
    examples = []
    for s in sentences:
        sc = (s.get("sContent") or "").strip()
        if not sc:
            continue
        examples.append(f'"{sc}"')

    return {
        "word": head,
        "phonetic": phonetic,
        "pos": pos,
        "chinese": chinese,
        "definition": definition,
        "examples": examples,
    }


def main():
    if not SRC.exists():
        print(f"源文件不存在: {SRC}", file=sys.stderr)
        sys.exit(1)

    words = []
    seen = set()
    with SRC.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            obj = json.loads(line)
            w = conv_word(obj)
            if w["word"] not in seen:
                seen.add(w["word"])
                words.append(w)

    book = {
        "id": "kaoyan",
        "name": "考研词汇",
        "fullName": "考研核心词汇",
        "badge": "KaoYan",
        "description": "考研英语核心词汇，收录 3728 高频词。",
        "dailyWords": 30,
        "gradient": ["0xFFF97316", "0xFFDC2626"],
        "words": words,
    }

    DST.parent.mkdir(parents=True, exist_ok=True)
    with DST.open("w", encoding="utf-8") as f:
        json.dump(book, f, ensure_ascii=False, indent=2)

    print(f"转换完成：{len(words)} 词 → {DST}")


if __name__ == "__main__":
    main()
