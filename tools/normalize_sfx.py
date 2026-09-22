#!/usr/bin/env python3
"""把 assets/sounds/*.wav 的响度统一归一到 0.9 满刻度，并补上收尾淡出。

为什么需要这个脚本
------------------
三个提示音素材的峰值差得离谱，平板外放上直接听不出来：

    success.wav  峰值 16383 (0.50 FS)  340ms
    error.wav    峰值  9830 (0.30 FS)  360ms
    tick.wav     峰值  6552 (0.20 FS)   50ms   ← 按字母的"嗒"声

`tick.wav` 只有 -14 dBFS，而且波形是被**硬切**断的（最后一帧还有 3658 的
振幅，约峰值的 56%）—— 一刀切下去就是一个 pop。在手机上勉强能听见，
在平板外放上基本等于没有声音，表现为"拼写时输入字母没有音效"。

处理内容
--------
1. 峰值归一化到 0.9 FS（等比例缩放，不改变音色，不会削顶）
2. 开头 1.5ms 淡入、结尾淡出到 0（消掉硬切产生的爆音）
3. 原地覆盖，格式保持 16-bit PCM 单声道 44.1kHz

原文件已在 git 里，需要回退用 `git checkout -- assets/sounds`。

用法
----
    python tools/normalize_sfx.py            # 就地处理
    python tools/normalize_sfx.py --check    # 只体检，不改文件
"""

from __future__ import annotations

import argparse
import array
import math
import sys
import wave
from pathlib import Path

TARGET_PEAK = 0.9          # 归一化目标（满刻度比例）
FADE_IN_MS = 1.5
FADE_OUT_RATIO = 0.25      # 结尾淡出占时长比例（上限 15ms）
FADE_OUT_MAX_MS = 15.0
FULL_SCALE = 32767
SOUNDS_DIR = Path(__file__).resolve().parent.parent / "assets" / "sounds"


def read_wav(path: Path) -> tuple[array.array, int]:
    with wave.open(str(path), "rb") as w:
        if w.getsampwidth() != 2:
            raise SystemExit(f"{path.name}: 只处理 16-bit PCM，实际 {w.getsampwidth() * 8}-bit")
        if w.getnchannels() != 1:
            raise SystemExit(f"{path.name}: 只处理单声道，实际 {w.getnchannels()} 声道")
        rate = w.getframerate()
        samples = array.array("h")
        samples.frombytes(w.readframes(w.getnframes()))
    return samples, rate


def write_wav(path: Path, samples: array.array, rate: int) -> None:
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(samples.tobytes())


def measure(samples: array.array) -> dict:
    peak = max((abs(x) for x in samples), default=0)
    rms = math.sqrt(sum(x * x for x in samples) / len(samples)) if samples else 0.0
    tail = samples[-int(0.001 * 44100):] or array.array("h", [0])
    return {
        "peak": peak,
        "peak_ratio": peak / FULL_SCALE,
        "rms": rms,
        "tail_peak": max((abs(x) for x in tail), default=0),
    }


def process(samples: array.array, rate: int) -> array.array:
    peak = max((abs(x) for x in samples), default=0)
    if peak == 0:
        return samples

    gain = (TARGET_PEAK * FULL_SCALE) / peak
    n = len(samples)
    fade_in = max(1, int(FADE_IN_MS / 1000 * rate))
    fade_out = max(1, min(int(FADE_OUT_RATIO * n), int(FADE_OUT_MAX_MS / 1000 * rate)))

    out = array.array("h", [0]) * n
    for i, v in enumerate(samples):
        g = gain
        if i < fade_in:
            g *= i / fade_in
        remaining = n - 1 - i
        if remaining < fade_out:
            g *= remaining / fade_out
        out[i] = int(round(v * g))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="只体检，不写回")
    args = ap.parse_args()

    files = sorted(SOUNDS_DIR.glob("*.wav"))
    if not files:
        print(f"没找到 wav：{SOUNDS_DIR}", file=sys.stderr)
        return 1

    failed = False
    for path in files:
        samples, rate = read_wav(path)
        before = measure(samples)
        duration_ms = len(samples) / rate * 1000

        print(f"{path.name:14s} {duration_ms:6.1f}ms  "
              f"峰值 {before['peak']:6d} ({before['peak_ratio'] * 100:5.1f}% FS)  "
              f"rms {before['rms']:8.1f}  "
              f"结尾1ms峰值 {before['tail_peak']:6d}")

        problems = []
        if before["peak_ratio"] < 0.7:
            problems.append(f"音量偏低（目标 ≥70% FS）")
        if before["tail_peak"] > FULL_SCALE * 0.05:
            problems.append("结尾被硬切，会有爆音")
        if duration_ms < 40:
            problems.append("时长过短")

        if args.check:
            if problems:
                failed = True
                print(f"    ✗ {'；'.join(problems)}")
            else:
                print("    ✓ 正常")
            continue

        if not problems:
            print("    ✓ 已达标，跳过")
            continue

        write_wav(path, process(samples, rate), rate)
        after = measure(read_wav(path)[0])
        print(f"    → 归一化后峰值 {after['peak']:6d} ({after['peak_ratio'] * 100:5.1f}% FS)，"
              f"结尾1ms峰值 {after['tail_peak']}")
        print(f"    （修正：{'；'.join(problems)}）")

    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
