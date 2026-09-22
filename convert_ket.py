# Convert vocab-app reme_ket.js to LexVault ket.json + copy images/audio.
# Source: vocab-app/data/reme_ket.js + assets/reme/KET/{images,audios}/
# Target: vacmaster/assets/{data/books/ket.json,images/ket/,audio/ket/}
import json, os, re, shutil, wave, io

SRC_ROOT = r"C:\Users\coder\WorkBuddy\2026-09-19-10-38-06\vocab-app"
DST_ROOT = r"d:\study_hxt\luffy_spider\vacmaster"

SRC_JS  = os.path.join(SRC_ROOT, "data", "reme_ket.js")
SRC_IMG = os.path.join(SRC_ROOT, "assets", "reme", "KET", "images")
SRC_AUD = os.path.join(SRC_ROOT, "assets", "reme", "KET", "audios")

DST_JSON  = os.path.join(DST_ROOT, "assets", "data", "books", "ket.json")
DST_IMG   = os.path.join(DST_ROOT, "assets", "images", "ket")
DST_AUD   = os.path.join(DST_ROOT, "assets", "audio", "ket")

os.makedirs(DST_IMG, exist_ok=True)
os.makedirs(DST_AUD, exist_ok=True)

# ── 1) Parse JS → JSON ──
print("═══ Step 1: Parse reme_ket.js ═══")
with open(SRC_JS, "r", encoding="utf-8") as f:
    content = f.read()
start = content.find("[")
end = content.rfind("]") + 1
words_src = json.loads(content[start:end])
print(f"   Raw entries: {len(words_src)}")

# ── 2) Filter unspellable ──
BAD_RE = re.compile(r'[()/,;]')
words_clean = [w for w in words_src if not BAD_RE.search(w['word'])]
removed = len(words_src) - len(words_clean)
if removed:
    print(f"   Filtered unspellable: {removed}")
print(f"   After filter: {len(words_clean)}")

# ── 3) Convert each word ──
def split_examples(text):
    """Split example sentence string into array of sentences."""
    if not text:
        return []
    # Split on . ! ? followed by space or end
    parts = re.split(r'(?<=[.!?])\s+', text.strip())
    return [p.strip() for p in parts if p.strip()]

def copy_or_convert_audio(src_path, dst_path):
    """Copy MP3 directly; convert WAV→MP3 using lameenc."""
    src_ext = os.path.splitext(src_path)[1].lower()
    if src_ext == ".mp3":
        shutil.copy2(src_path, dst_path)
        return True
    elif src_ext == ".wav":
        try:
            import lameenc
            # Read WAV
            with wave.open(src_path, "rb") as w:
                nchannels = w.getnchannels()
                sampwidth = w.getsampwidth()
                framerate = w.getframerate()
                nframes = w.getnframes()
                raw = w.readframes(nframes)
            # Encode to MP3
            encoder = lameenc.Encoder()
            encoder.set_bit_rate(128)
            encoder.set_in_sample_rate(framerate)
            encoder.set_channels(nchannels)
            encoder.set_quality(2)  # high quality
            mp3_data = encoder.encode(raw) + encoder.flush()
            with open(dst_path, "wb") as f:
                f.write(mp3_data)
            return True
        except Exception as e:
            print(f"   ⚠️ WAV→MP3 failed {os.path.basename(src_path)}: {e}")
            # Fallback: just copy the WAV
            dst_wav = os.path.splitext(dst_path)[0] + ".wav"
            shutil.copy2(src_path, dst_wav)
            return False
    else:
        shutil.copy2(src_path, dst_path)
        return True

print("\n═══ Step 2: Convert + copy assets ═══")
converted = []
img_ok = aud_ok = aud_wav_conv = 0

for w in words_clean:
    word_text = w['word']

    # --- Image ---
    src_img_path = w.get('image', '')
    img_ok_flag = False
    if src_img_path:
        basename = os.path.basename(src_img_path)
        dst_img_path = os.path.join(DST_IMG, basename)
        src_full = os.path.join(SRC_ROOT, src_img_path.replace('assets/', 'assets/'))
        # Path is like "assets/reme/KET/images/a_few.webp"
        src_full = os.path.join(SRC_ROOT, src_img_path)
        if os.path.exists(src_full):
            shutil.copy2(src_full, dst_img_path)
            img_ok += 1
            img_ok_flag = True
    dst_img_field = f"assets/images/ket/{os.path.basename(src_img_path)}" if img_ok_flag else None

    # --- Audio ---
    src_aud_path = w.get('audio', '')
    aud_ok_flag = False
    dst_aud_field = None
    if src_aud_path:
        basename = os.path.basename(src_aud_path)
        dst_basename = basename
        src_full = os.path.join(SRC_ROOT, src_aud_path)
        if os.path.exists(src_full):
            # If WAV, convert to MP3
            if basename.lower().endswith('.wav'):
                dst_basename = os.path.splitext(basename)[0] + ".mp3"
            dst_full = os.path.join(DST_AUD, dst_basename)
            ok = copy_or_convert_audio(src_full, dst_full)
            if ok:
                aud_ok += 1
                if basename.lower().endswith('.wav'):
                    aud_wav_conv += 1
                aud_ok_flag = True
                dst_aud_field = f"assets/audio/ket/{dst_basename}"
            else:
                # WAV fallback case
                dst_wav = os.path.splitext(dst_full)[0] + ".wav"
                if os.path.exists(dst_wav):
                    aud_ok += 1
                    aud_ok_flag = True
                    dst_aud_field = f"assets/audio/ket/{os.path.basename(dst_wav)}"

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
print("\n═══ Step 3: Write ket.json ═══")
import random
# Shuffle like we do for PET
random.seed(42)
random.shuffle(converted)

ket_book = {
    "id": "ket",
    "name": "KET",
    "fullName": "KET 核心词汇",
    "badge": "CEFR",
    "description": "剑桥 KET 核心高频词，适合 A2 起步阶段。",
    "dailyWords": 5,
    "gradient": ["0xFF3B82F6", "0xFF8B5CF6"],  # violet-indigo (distinct from PET green)
    "words": converted,
}

with open(DST_JSON, "w", encoding="utf-8") as f:
    json.dump(ket_book, f, ensure_ascii=False, indent=2)
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

print(f"\n═══ Size Summary ═══")
print(f"   ket.json:       {json_kb:.0f} KB")
print(f"   images/ket/:    {img_mb:.1f} MB  ({len(os.listdir(DST_IMG))} files)")
print(f"   audio/ket/:     {aud_mb:.1f} MB  ({len(os.listdir(DST_AUD))} files)")
print(f"   TOTAL:          {json_kb/1024 + img_mb + aud_mb:.1f} MB")

print("\n✅ KET import complete!")
