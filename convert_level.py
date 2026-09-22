# Convert vocab-app reme_{level}.js to LexVault {level}.json + copy images/audio.
# Usage: python convert_level.py a1   (or a2 / awl)
import json, os, re, shutil, wave, io, random, sys

SRC_ROOT = r"C:\Users\coder\WorkBuddy\2026-09-19-10-38-06\vocab-app"
DST_ROOT = r"d:\study_hxt\luffy_spider\vacmaster"

BOOK_META = {
    "a1": {"name": "A1", "fullName": "CEFR A1 入门词汇", "badge": "CEFR",
           "desc": "CEFR A1 入门级核心词，适合英语零基础起步。",
           "gradient": ["0xFF10B981", "0xFF34D399"], "daily": 5},
    "a2": {"name": "A2", "fullName": "CEFR A2 基础词汇", "badge": "CEFR",
           "desc": "CEFR A2 基础级核心词，适合小学高年级~初中。",
           "gradient": ["0xFF3B82F6", "0xFF60A5FA"], "daily": 10},
    "awl": {"name": "AWL", "fullName": "AWL 学术词汇表", "badge": "Academic",
            "desc": "Academic Word List 学术英语高频词，适合雅思/托福/考研阅读。",
            "gradient": ["0xFF8B5CF6", "0xFFA78BFA"], "daily": 15},
}

level = sys.argv[1].lower() if len(sys.argv) > 1 else "a1"
if level not in BOOK_META:
    print(f"Unknown level: {level}. Use a1 / a2 / awl.")
    sys.exit(1)

meta = BOOK_META[level]
SRC_JS  = os.path.join(SRC_ROOT, "data", f"reme_{level}.js")
SRC_IMG = os.path.join(SRC_ROOT, "assets", "reme", level.upper(), "images")
SRC_AUD = os.path.join(SRC_ROOT, "assets", "reme", level.upper(), "audios")

DST_JSON  = os.path.join(DST_ROOT, "assets", "data", "books", f"{level}.json")
DST_IMG   = os.path.join(DST_ROOT, "assets", "images", level)
DST_AUD   = os.path.join(DST_ROOT, "assets", "audio", level)

os.makedirs(DST_IMG, exist_ok=True)
os.makedirs(DST_AUD, exist_ok=True)

# ── 1) Parse JS → JSON ──
print(f"═══ Step 1: Parse reme_{level}.js ═══")
with open(SRC_JS, "r", encoding="utf-8") as f:
    content = f.read()
start = content.find("[")
end = content.rfind("]") + 1
words_src = json.loads(content[start:end])
print(f"   Raw entries: {len(words_src)}")

# ── 2) Filter unspellable (parentheses/slashes/commas break custom keyboard) ──
BAD_RE = re.compile(r'[()/,;]')
words_clean = [w for w in words_src if not BAD_RE.search(w['word'])]
removed = len(words_src) - len(words_clean)
if removed:
    print(f"   Filtered unspellable: {removed}")
print(f"   After filter: {len(words_clean)}")

# ── 3) Convert each word ──
def split_examples(text):
    if not text:
        return []
    parts = re.split(r'(?<=[.!?])\s+', text.strip())
    return [p.strip() for p in parts if p.strip()]

def copy_or_convert_audio(src_path, dst_path):
    src_ext = os.path.splitext(src_path)[1].lower()
    if src_ext == ".mp3":
        shutil.copy2(src_path, dst_path)
        return True
    elif src_ext == ".wav":
        try:
            import lameenc
            with wave.open(src_path, "rb") as w:
                nchannels = w.getnchannels()
                sampwidth = w.getsampwidth()
                framerate = w.getframerate()
                nframes = w.getnframes()
                raw = w.readframes(nframes)
            encoder = lameenc.Encoder()
            encoder.set_bit_rate(128)
            encoder.set_in_sample_rate(framerate)
            encoder.set_channels(nchannels)
            encoder.set_quality(2)
            mp3_data = encoder.encode(raw) + encoder.flush()
            with open(dst_path, "wb") as f:
                f.write(mp3_data)
            return True
        except Exception as e:
            print(f"   ⚠️ WAV→MP3 failed {os.path.basename(src_path)}: {e}")
            dst_wav = os.path.splitext(dst_path)[0] + ".wav"
            shutil.copy2(src_path, dst_wav)
            return False
    else:
        shutil.copy2(src_path, dst_path)
        return True

print(f"\n═══ Step 2: Convert + copy assets ({level}) ═══")
converted = []
img_ok = aud_ok = aud_wav_conv = 0

for w in words_clean:
    word_text = w['word']

    # --- Image ---
    src_img_path = w.get('image', '')
    img_ok_flag = False
    if src_img_path:
        src_full = os.path.join(SRC_ROOT, src_img_path)
        if os.path.exists(src_full):
            basename = os.path.basename(src_img_path)
            dst_img_path = os.path.join(DST_IMG, basename)
            shutil.copy2(src_full, dst_img_path)
            img_ok += 1
            img_ok_flag = True
    dst_img_field = f"assets/images/{level}/{os.path.basename(src_img_path)}" if img_ok_flag else None

    # --- Audio ---
    src_aud_path = w.get('audio', '')
    aud_ok_flag = False
    dst_aud_field = None
    if src_aud_path:
        src_full = os.path.join(SRC_ROOT, src_aud_path)
        if os.path.exists(src_full):
            basename = os.path.basename(src_aud_path)
            dst_basename = basename
            if basename.lower().endswith('.wav'):
                dst_basename = os.path.splitext(basename)[0] + ".mp3"
            dst_full = os.path.join(DST_AUD, dst_basename)
            ok = copy_or_convert_audio(src_full, dst_full)
            if ok:
                aud_ok += 1
                if basename.lower().endswith('.wav'):
                    aud_wav_conv += 1
                aud_ok_flag = True
                dst_aud_field = f"assets/audio/{level}/{dst_basename}"
            else:
                dst_wav = os.path.splitext(dst_full)[0] + ".wav"
                if os.path.exists(dst_wav):
                    aud_ok += 1
                    aud_ok_flag = True
                    dst_aud_field = f"assets/audio/{level}/{os.path.basename(dst_wav)}"

    # --- Build Word entry ---
    pos = w.get('pos', '')
    definition = w.get('remMethod', '')
    chinese = w.get('meaning', '')
    examples = split_examples(w.get('example', ''))
    phonetic = w.get('phonetic', '')

    entry = {
        "word": word_text,
        "phonetic": phonetic,
        "pos": pos,
        "chinese": chinese,
        "definition": definition,
        "examples": examples,
    }
    if dst_img_field:
        entry["image"] = dst_img_field
    if dst_aud_field:
        entry["audio"] = dst_aud_field

    converted.append(entry)

print(f"   Words: {len(converted)}")
print(f"   Images copied: {img_ok}")
print(f"   Audio copied: {aud_ok} (WAV→MP3 converted: {aud_wav_conv})")

# ── 4) Assemble Book JSON ──
print(f"\n═══ Step 3: Write {level}.json ═══")
random.seed(42)
random.shuffle(converted)

book = {
    "id": level,
    "name": meta["name"],
    "fullName": meta["fullName"],
    "badge": meta["badge"],
    "description": meta["desc"],
    "dailyWords": meta["daily"],
    "gradient": meta["gradient"],
    "words": converted,
}

with open(DST_JSON, "w", encoding="utf-8") as f:
    json.dump(book, f, ensure_ascii=False, indent=2)
print(f"   → {DST_JSON}")
print(f"   Words in book: {len(converted)}")

# ── 5) Size summary ──
def dir_size(p):
    total = 0
    for root, dirs, files in os.walk(p):
        for f in files:
            total += os.path.getsize(os.path.join(root, f))
    return total

json_kb = os.path.getsize(DST_JSON) / 1024
img_mb  = dir_size(DST_IMG) / (1024 * 1024)
aud_mb  = dir_size(DST_AUD) / (1024 * 1024)

print(f"\n═══ Size Summary ({level}) ═══")
print(f"   {level}.json:       {json_kb:.0f} KB")
print(f"   images/{level}/:    {img_mb:.1f} MB  ({len(os.listdir(DST_IMG))} files)")
print(f"   audio/{level}/:     {aud_mb:.1f} MB  ({len(os.listdir(DST_AUD))} files)")
print(f"   TOTAL:              {json_kb/1024 + img_mb + aud_mb:.1f} MB")

print(f"\n✅ {level.upper()} import complete!")
