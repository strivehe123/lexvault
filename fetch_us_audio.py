# Fetch American phonetics (Youdao usphone) + US audio (dictvoice type=2) for KET.
# Updates ket.json phonetic in place and replaces assets/audio/ket/*.mp3 content.
# Words missing audio ("their poss"/"his poss") query the base word.
import json, os, time, wave, io, urllib.request, urllib.parse
from concurrent.futures import ThreadPoolExecutor

import lameenc

ROOT = r'd:\study_hxt\luffy_spider\vacmaster'
BOOK = os.path.join(ROOT, 'assets', 'data', 'books', 'ket.json')
AUD = os.path.join(ROOT, 'assets', 'audio', 'ket')
UA = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}

# query word -> display word
QUERY_FIX = {'their poss': 'their', 'his poss': 'his'}


def get(url, timeout=20, retries=3):
    last = None
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers=UA)
            return urllib.request.urlopen(req, timeout=timeout).read()
        except Exception as e:  # noqa: BLE001
            last = e
            time.sleep(0.8 * (i + 1))
    raise last


def wav_to_mp3(data: bytes) -> bytes:
    w = wave.open(io.BytesIO(data))
    enc = lameenc.Encoder()
    enc.set_bit_rate(128)
    enc.set_in_sample_rate(w.getframerate())
    enc.set_channels(w.getnchannels())
    enc.set_quality(2)
    mp3 = enc.encode(w.readframes(w.getnframes()))
    mp3 += enc.flush()
    w.close()
    return mp3


def looks_like_audio(data: bytes) -> bool:
    if len(data) < 1200:
        return False
    if data[:3] == b'ID3':
        return True
    if data[:4] == b'RIFF':
        return True
    return data[0] == 0xFF and (data[1] & 0xE0) == 0xE0


def process(item):
    idx, w = item
    word = w['word']
    q = QUERY_FIX.get(word, word)
    uq = urllib.parse.quote(q)

    # 1) usphone
    try:
        d = json.loads(get(f'https://dict.youdao.com/jsonapi?dictno=dict&q={uq}'))
        ecw = d.get('ec', {}).get('word')
        if isinstance(ecw, list) and ecw and ecw[0].get('usphone'):
            w['phonetic'] = '/' + ecw[0]['usphone'].strip('/') + '/'
    except Exception:
        pass

    # 2) US audio (type=2)
    try:
        data = get(f'https://dict.youdao.com/dictvoice?type=2&audio={uq}&le=eng')
        if looks_like_audio(data):
            if data[:4] == b'RIFF':
                data = wav_to_mp3(data)
            fn = word.replace(' ', '_') + '.mp3'
            with open(os.path.join(AUD, fn), 'wb') as f:
                f.write(data)
            w['audio'] = f'assets/audio/ket/{fn}'
            return idx, True, False
        return idx, False, False
    except Exception:
        return idx, False, False


def main():
    book = json.load(open(BOOK, encoding='utf-8'))
    words = book['words']
    n = len(words)

    audio_ok = 0
    phon_before = sum(1 for w in words)
    fails = []
    results = [None] * n

    with ThreadPoolExecutor(max_workers=4) as ex:
        for idx, a_ok, _ in ex.map(process, list(enumerate(words))):
            results[idx] = a_ok
            done = sum(1 for r in results if r is not None)
            if a_ok:
                audio_ok += 1
            if done % 100 == 0:
                print(f'{done}/{n} audio_ok={audio_ok}', flush=True)

    fails = [w['word'] for w, r in zip(words, results) if not r]
    phon_after = sum(1 for w in words if w.get('phonetic'))

    with open(BOOK, 'w', encoding='utf-8') as f:
        json.dump(book, f, ensure_ascii=False, indent=2)

    print(f'DONE audio={audio_ok}/{n} phon={phon_after}/{phon_before}')
    print('fails:', fails[:30])


if __name__ == '__main__':
    main()
