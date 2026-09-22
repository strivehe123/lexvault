# -*- coding: utf-8 -*-
"""One-off generator for success/error sfx used by the app."""
import wave
import math
import struct
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
SR = 44100


def write(name, samples):
    frames = b"".join(
        struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples
    )
    path = os.path.abspath(os.path.join(OUT, name))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)
    print("written", path)


def tone(freq, dur, vol=0.5, shape="sine"):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        attack = min(1.0, i / (SR * 0.01))
        release = 1 - 0.6 * max(0.0, (i - n + SR * 0.06) / (SR * 0.06))
        env = attack * release
        ph = 2 * math.pi * freq * t
        v = math.sin(ph) if shape == "sine" else (1.0 if math.sin(ph) >= 0 else -1.0)
        out.append(v * vol * env)
    return out


write("tick.wav", tone(1174.7, 0.05, vol=0.25))
write("success.wav", tone(1318.5, 0.12) + tone(1760.0, 0.22, vol=0.45))
write(
    "error.wav",
    tone(196.0, 0.16, vol=0.4, shape="square")
    + [0] * int(SR * 0.05)
    + tone(155.6, 0.28, vol=0.4, shape="square"),
)
