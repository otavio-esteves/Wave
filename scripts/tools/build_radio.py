"""Render the three original Wave radio arrangements to stereo Ogg Vorbis."""

from array import array
from functools import lru_cache
from math import cos, exp, pi, sin, sqrt, tau
from pathlib import Path
from random import Random

from audio_files import write_vorbis

RATE = 32000
ROOT = Path(__file__).resolve().parents[2] / "assets" / "audio"

# Each voicing starts with the bass note. The remaining notes are spread
# across the middle register to leave room for the melody and the car.
BRISA = (
    (45, 55, 60, 64, 71), (50, 57, 60, 65, 69),
    (43, 53, 59, 62, 69), (48, 55, 59, 64, 67),
    (41, 52, 57, 60, 67), (46, 53, 57, 62, 65),
    (47, 53, 57, 62, 69), (40, 50, 56, 62, 65),
    (41, 48, 52, 57, 64), (44, 53, 59, 62, 65),
    (43, 55, 60, 64, 69), (45, 55, 59, 64, 72),
    (50, 57, 60, 65, 69), (43, 53, 59, 62, 65),
    (48, 55, 59, 64, 67), (40, 52, 56, 62, 65),
)
ALAMEDA = (
    (38, 53, 57, 60, 64), (38, 52, 57, 60, 65),
    (43, 53, 57, 62, 69), (43, 53, 59, 64, 67),
    (41, 53, 57, 60, 67), (41, 52, 57, 62, 65),
    (45, 55, 61, 64, 69), (45, 55, 60, 64, 68),
    (46, 57, 60, 65, 69), (48, 55, 58, 62, 67),
    (38, 53, 57, 62, 64), (41, 52, 57, 60, 64),
    (43, 53, 57, 62, 67), (43, 53, 59, 62, 69),
    (45, 55, 61, 65, 71), (45, 55, 61, 64, 67),
)
CHUVA = (
    (42, 49, 52, 57, 61), (38, 49, 54, 57, 64),
    (45, 52, 56, 61, 64), (40, 52, 56, 59, 66),
    (42, 52, 57, 61, 66), (35, 50, 54, 57, 61),
    (38, 49, 54, 57, 64), (40, 50, 56, 59, 65),
    (47, 54, 57, 61, 64), (38, 50, 54, 57, 61),
    (37, 52, 56, 59, 64), (42, 52, 57, 61, 66),
    (35, 50, 54, 57, 64), (38, 49, 54, 57, 62),
    (40, 50, 55, 59, 66), (40, 50, 56, 62, 65),
)

# The second passage answers the first. Long notes leave space between phrases.
BRISA_MELODY = (
    ((0.25, 76, 0.80), (1.50, 79, 0.33), (2.00, 76, 1.02), (3.50, 71, 0.38)),
    ((0.00, 77, 0.55), (0.75, 76, 0.68), (2.50, 74, 1.08)),
    ((1.00, 74, 0.48), (2.00, 77, 0.55), (2.75, 81, 0.72)),
    ((0.50, 79, 0.85), (2.00, 76, 1.20)),
    ((0.25, 76, 1.08), (1.75, 72, 0.32), (2.25, 69, 1.15)),
    ((0.75, 74, 0.64), (1.75, 77, 0.32), (2.50, 81, 0.90)),
    ((0.50, 77, 0.77), (1.75, 74, 0.80), (3.00, 71, 0.65)),
    ((0.00, 68, 0.74), (2.25, 74, 0.45), (3.25, 71, 0.45)),
)
ALAMEDA_MELODY = (
    ((0.52, 74, 0.48), (1.27, 77, 0.23), (1.78, 81, 0.55), (2.73, 84, 0.33), (3.25, 81, 0.34)),
    ((0.24, 77, 0.48), (1.00, 76, 0.34), (1.70, 72, 0.70), (3.3, 74, 0.43)),
    ((0.55, 74, 0.43), (1.25, 77, 0.31), (2.22, 81, 0.58), (3.5, 77, 0.28)),
    ((0.25, 76, 0.40), (0.96, 79, 0.77), (2.54, 83, 0.52), (3.52, 79, 0.28)),
    ((0.49, 81, 0.42), (1.22, 84, 0.55), (2.52, 79, 0.37), (3.08, 77, 0.51)),
    ((0.26, 76, 0.45), (1.20, 72, 0.52), (2.23, 74, 0.64)),
    ((0.50, 73, 0.49), (1.18, 76, 0.51), (2.56, 79, 0.64), (3.46, 81, 0.33)),
    ((0.28, 80, 0.42), (1.23, 79, 0.53), (2.24, 76, 0.46), (3.31, 72, 0.49)),
)
CHUVA_MELODY = (
    ((0.18, 76, 1.19), (2.35, 73, 0.94)),
    ((1.15, 78, 0.72), (2.45, 76, 1.11)),
    ((0.43, 73, 0.87), (1.90, 76, 0.50), (3.12, 80, 0.67)),
    ((0.56, 78, 1.57), (3.11, 71, 0.60)),
    ((0.30, 73, 0.54), (1.14, 76, 0.51), (2.23, 78, 1.20)),
    ((0.55, 81, 0.88), (2.49, 78, 1.03)),
    ((0.81, 76, 0.96), (2.58, 74, 1.04)),
    ((0.60, 71, 0.95), (2.18, 68, 0.65), (3.38, 71, 0.50)),
)
LEADS = {
    "brisa": (0.10, "nylon", BRISA_MELODY),
    "alameda": (0.52, "keys", ALAMEDA_MELODY),
    "chuva": (0.26, "bell", CHUVA_MELODY),
}


@lru_cache(maxsize=120)
def tone(instrument, midi, length):
    duration = length / RATE
    increment = tau * (440.0 * 2 ** ((midi - 69) / 12.0)) / RATE
    audio = array("f")
    for frame in range(length):
        t = frame / RATE
        phase = increment * frame
        if instrument == "nylon":
            body = (sin(phase) + 0.43 * sin(2.0 * phase + 0.4)
                    + 0.19 * sin(3.0 * phase - 0.6)
                    + (0.27 * sin(4.0 * phase) + 0.15 * sin(7.0 * phase)) * exp(-8.0 * t))
            body *= exp(-2.7 * t)
            attack, release = 0.008, 0.18
        elif instrument == "bass":
            body = (sin(phase) + (0.26 * sin(2.0 * phase) + 0.095 * sin(3.0 * phase))
                    * exp(-6.0 * t)) * exp(-1.7 * t)
            attack, release = 0.014, 0.12
        elif instrument == "pad":
            body = (sin(phase) * 0.58 + sin(phase * 1.0027) * 0.29
                    + sin(phase * 1.9946) * 0.10 + sin(phase * 3.0) * 0.035)
            attack, release = 0.35, 0.57
        else:
            ratio = 2.007 if instrument == "bell" else 1.004
            body = sin(phase + sin(phase * ratio) * (0.18 + 1.05 * exp(-8.5 * t)))
            body += 0.21 * sin(phase * 2.0 + 0.7) * exp(-1.6 * t)
            body *= exp(-(2.25 if instrument == "bell" else 1.55) * t)
            attack, release = 0.012, 0.27
        edge = min(1.0, t / attack) * min(1.0, (duration - t) / release)
        audio.append(body * edge)
    return audio


def percussion(seed, kind):
    rng = Random(seed)
    duration = {"kick": 0.34, "rim": 0.15, "clap": 0.23, "shaker": 0.091}[kind]
    audio = array("f")
    color = 0.0
    for frame in range(round(duration * RATE)):
        t = frame / RATE
        noise = rng.uniform(-1.0, 1.0)
        color += 0.46 * (noise - color)
        grain = noise - color
        if kind == "kick":
            phase = tau * (54.0 * t + 1.4 * (1.0 - exp(-51.0 * t)))
            value = 0.95 * sin(phase) * exp(-14.0 * t) + grain * 0.07 * exp(-120.0 * t)
        elif kind == "rim":
            wood = sin(tau * 395.0 * t) * 0.42 + sin(tau * 719.0 * t) * 0.18
            value = wood * exp(-83.0 * t) + grain * 0.34 * exp(-61.0 * t)
        elif kind == "clap":
            slap = exp(-abs(t - 0.009) * 260.0) + 0.68 * exp(-abs(t - 0.022) * 170.0)
            value = grain * (slap * 0.54 + exp(-28.0 * t)) + color * 0.29 * exp(-45.0 * t)
        else:
            value = grain * min(t / 0.013, 1.0) * exp(-33.0 * t)
        audio.append(value * min(1.0, t / 0.003, (duration - t) / 0.024))
    return audio


class Arrangement:
    def __init__(self, bpm, bars, seed):
        self.beat = 60.0 / bpm
        frames = round((bars * 4 * self.beat + 1.1) * RATE)
        self.left = array("f", [0.0]) * frames
        self.right = array("f", [0.0]) * frames
        self.rng = Random(seed)
        self.drums = {kind: [percussion(seed + number, kind) for number in range(4)]
                      for kind in ("kick", "rim", "clap", "shaker")}

    def mix(self, audio, beat, gain, pan):
        position = round((beat * self.beat + self.rng.uniform(-0.007, 0.007)) * RATE)
        pan = (pan + 1.0) * pi / 4.0
        left = gain * cos(pan)
        right = gain * sin(pan)
        for i in range(max(0, -position), min(len(audio), len(self.left) - position)):
            value = audio[i]
            j = position + i
            self.left[j] += value * left
            self.right[j] += value * right

    def note(self, instrument, beat, midi, duration, gain, pan=0.0):
        # Quantize note lengths for reuse without quantizing their timing.
        length = round(duration * self.beat * 50.0) * (RATE // 50)
        self.mix(tone(instrument, midi, length), beat, gain * self.rng.uniform(0.91, 1.07), pan)

    def drum(self, kind, beat, gain, pan=0.0):
        self.mix(self.rng.choice(self.drums[kind]), beat, gain, pan)

    def finish(self, filename):
        # Stereo early reflections, damped at each repeat.
        delay_left = round(0.126 * RATE)
        delay_right = round(0.181 * RATE)
        wet_left = wet_right = 0.0
        for i in range(delay_right, len(self.left)):
            wet_left += (self.right[i - delay_right] - wet_left) * 0.18
            wet_right += (self.left[i - delay_left] - wet_right) * 0.18
            self.left[i] += wet_left * 0.12
            self.right[i] += wet_right * 0.10
        square_sum = sum(v * v for v in self.left) + sum(v * v for v in self.right)
        rms = sqrt(square_sum / (2 * len(self.left)))
        peak = max(max(map(abs, self.left)), max(map(abs, self.right)))
        gain = min(0.135 / rms, 0.86 / peak)
        for i in range(len(self.left)):
            fade = min(1.0, i / (RATE * 0.045), (len(self.left) - 1 - i) / (RATE * 0.75))
            self.left[i] *= gain * fade
            self.right[i] *= gain * fade
        write_vorbis(ROOT / filename, self.left, self.right, RATE)
        print(f"{filename}: {len(self.left) / RATE:.1f}s, stereo, RMS {rms * gain:.3f}, peak {peak * gain:.3f}")


def build(style, filename, bpm, progression, seed):
    timeline = list(range(16)) + (list(range(8)) if style != "alameda" else list(range(8)) * 2)
    recording = Arrangement(bpm, len(timeline), seed)
    instrument = {"brisa": "nylon", "alameda": "keys", "chuva": "keys"}[style]
    pan, lead, melody = LEADS[style]
    for bar, chord_index in enumerate(timeline):
        start = bar * 4.0
        root, *notes = progression[chord_index]
        next_root = progression[timeline[min(bar + 1, len(timeline) - 1)]][0]
        final = bar == len(timeline) - 1
        if final:
            root, *notes = progression[0]
        bass = [(0.0, root, 1.12), (2.0, root + 7, 0.66), (3.40, next_root - 1, 0.41)]
        if style == "alameda":
            bass = [(0.0, root, 0.70), (0.88, root + 12, 0.43), (1.50, root, 0.46),
                    (2.28, root + 7, 0.52), (3.20, root + 12, 0.25), (3.53, next_root - 1, 0.39)]
        elif style == "chuva":
            bass = [(0.0, root, 2.1), (2.68, next_root, 1.02)]
        if final:
            bass = [(0.0, root, 3.9)]
        for offset, midi, duration in bass:
            recording.note("bass", start + offset, midi, duration, 0.32)

        if style == "brisa":
            accents = (0.0, 0.76, 1.50, 2.48, 3.25)
        elif style == "alameda":
            accents = (0.50, 1.26, 2.00, 2.77, 3.55)
        else:
            accents = (0.12, 2.14)
        if final:
            accents = (0.11,)
        for offset in accents:
            for string, note in enumerate(notes):
                stagger = string * (0.032 if style == "brisa" else 0.015)
                length = 3.8 if final else (1.7 if style == "chuva" else 0.69)
                recording.note(instrument, start + offset + stagger, note, length,
                               0.071 if style == "brisa" else 0.062, -0.41 + string * 0.15)
        if style == "chuva" or 8 <= bar < 16:
            for voice, note in enumerate(notes[1:]):
                recording.note("pad", start + 0.04, note, 4.3, 0.041, (voice - 1) * 0.46)

        if 2 <= bar < len(timeline) - 1:
            for phrase, (offset, note, duration) in enumerate(melody[chord_index % 8]):
                pitch = note
                if 8 <= bar < 16:
                    pitch = notes[(phrase + bar % 2) % len(notes)] + 12
                recording.note(lead, start + offset, pitch, duration * (1.35 if style == "chuva" else 1.0),
                               0.118 if style == "brisa" else 0.105, pan)
        if final:
            recording.note(lead, start + 0.65, notes[-1] + 12, 2.6, 0.105, pan)
            continue
        if bar < (4 if style == "chuva" else 1):
            continue
        kick = {"brisa": (0.0, 2.46), "alameda": (0.0, 1.74, 2.5), "chuva": (0.0, 2.79)}[style]
        backbeat = (1.0, 3.0) if style != "brisa" else (1.48, 3.10)
        for offset in kick:
            recording.drum("kick", start + offset, 0.25 if style == "alameda" else 0.16)
        for offset in backbeat:
            recording.drum("rim" if style == "brisa" else "clap", start + offset,
                           0.080 if style == "chuva" else 0.13, -0.10)
        for beat in range(4 if style == "chuva" else 8):
            offset = beat + 0.53 if style == "chuva" else beat * 0.5 + (0.024 if beat % 2 else 0.0)
            recording.drum("shaker", start + offset, 0.051 + (beat % 2) * 0.029, 0.43)
    recording.finish(filename)


if __name__ == "__main__":
    build("brisa", "wave-radio-brisa.ogg", 96, BRISA, 92)
    build("alameda", "wave-radio-alameda.ogg", 116, ALAMEDA, 116)
    build("chuva", "wave-radio-chuva.ogg", 84, CHUVA, 211)
