#!/usr/bin/env python3
"""Generate licensing-free test WAVs (known chord progressions) for the BYO-song
analyze harness. Clean synth — validates the decode→recognize pipeline on device.

Usage: python3 scripts/gen_test_audio.py [out_dir]
"""
import sys, os, wave, struct, math

SR = 44100

def note(f, t):
    return sum((1.0 / k) * math.sin(2 * math.pi * k * f * t) for k in range(1, 6))

def freqs(pcs, base=48):  # triad around octave 3
    return [440 * 2 ** ((base + pc - 69) / 12) for pc in pcs]

CHORDS = {  # name -> pitch classes (root, 3rd, 5th)
    "C": [0, 4, 7], "G": [7, 11, 2], "Am": [9, 0, 4], "F": [5, 9, 0],
    "D": [2, 6, 9], "Em": [4, 7, 11],
}

def render(progression, bar=2.0):
    buf = []
    for ch in progression:
        fs = freqs(CHORDS[ch])
        for i in range(int(bar * SR)):
            t = i / SR
            env = math.exp(-t * 1.4)  # re-strum each bar
            buf.append(env * sum(note(f, t) for f in fs) / len(fs))
    m = max((abs(x) for x in buf), default=1.0) or 1.0
    return b"".join(struct.pack("<h", int(max(-1, min(1, x / m)) * 32767)) for x in buf)

def write(path, progression, bar=2.0):
    w = wave.open(path, "w")
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes(render(progression, bar)); w.close()
    print("wrote", path)

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/Downloads")
    write(os.path.join(out, "Strumbuddy-Test-CGAmF.wav"), ["C", "G", "Am", "F"] * 2)
    write(os.path.join(out, "Strumbuddy-Test-EmD.wav"), ["Em", "D"] * 4)          # Drunken Sailor-ish
    write(os.path.join(out, "Strumbuddy-Test-GCD.wav"), ["G", "C", "G", "D"] * 2) # I-IV-I-V
