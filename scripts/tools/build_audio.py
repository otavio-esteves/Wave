"""Build Wave's original placeholder audio using only Python's standard library.

Deterministic synthesis; no recordings, samples or third-party compositions.
Run from any directory: python3 scripts/tools/build_audio.py
"""

from array import array
import math
from pathlib import Path
import random
import wave

RATE = 22050
TAU = math.tau
OUTPUT = Path(__file__).resolve().parents[2] / "assets" / "audio"


def save(name, samples):
    peak = max(abs(value) for value in samples)
    gain = min(0.8 / max(peak, 0.001), 1.0)
    pcm = array("h", (round(value * gain * 32767) for value in samples))
    import sys
    if sys.byteorder != "little":
        pcm.byteswap()
    with wave.open(str(OUTPUT / name), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())
    print(f"{name}: {len(samples) / RATE:.1f}s, peak {peak * gain:.3f}")


def engine():
    # All frequencies are integer multiples, so the one-second loop is seamless.
    samples = []
    for index in range(RATE):
        t = index / RATE
        pulse = sum(math.sin(TAU * 55 * harmonic * t + harmonic * 0.2) / harmonic
                    for harmonic in range(1, 9))
        samples.append(0.24 * pulse * (0.9 + 0.1 * math.cos(TAU * 5 * t)))
    save("wave-engine.wav", samples)


def evening():
    rng = random.Random(2718)
    duration = 20
    samples = [0.0] * (RATE * duration)
    low = 0.0
    for index in range(len(samples)):
        t = index / RATE
        low = low * 0.97 + rng.uniform(-1, 1) * 0.03
        edge = min(1.0, t / 0.5, (duration - t) / 0.5)
        samples[index] = low * 0.35 * edge * (0.8 + 0.2 * math.sin(TAU * t / 10))
    for start in [1.4, 2.0, 5.7, 6.0, 10.1, 14.5, 15.0, 18.2]:
        phase = 0.0
        for index in range(int(0.24 * RATE)):
            t = index / RATE
            frequency = 2400 + 700 * math.sin(t * 18) + 180 * math.sin(t * 85)
            phase += TAU * frequency / RATE
            envelope = math.sin(math.pi * t / 0.24) ** 2
            samples[int(start * RATE) + index] += math.sin(phase) * envelope * 0.13
    save("wave-evening.wav", samples)


def sunset():
    samples = [0.0] * (RATE * 32)

    def note(start, midi, duration, gain):
        frequency = 440 * 2 ** ((midi - 69) / 12)
        for index in range(int(duration * RATE)):
            t = index / RATE
            attack = min(1, t / 0.025)
            release = min(1, (duration - t) / 0.25)
            envelope = attack * release * math.exp(-t * 1.4)
            tone = math.sin(TAU * frequency * t) + 0.2 * math.sin(TAU * frequency * 2 * t)
            target = (int(start * RATE) + index) % len(samples)
            samples[target] += gain * envelope * tone

    chords = [(48, 55, 64), (45, 52, 60), (53, 60, 69), (55, 62, 67),
              (48, 55, 64), (45, 52, 60), (53, 60, 69), (55, 62, 71)]
    melody = [(76, 79, 76, 72), (76, 72, 69, 72), (77, 76, 72, 69), (74, 79, 74, 71),
              (76, 79, 84, 79), (76, 72, 69, 72), (77, 81, 77, 76), (74, 71, 67, 72)]
    for bar, chord in enumerate(chords):
        note(bar * 4, chord[0] - 12, 3.7, 0.13)
        for beat in range(8):
            note(bar * 4 + beat * 0.5, chord[beat % 3], 2.0, 0.085)
        for beat, midi in enumerate(melody[bar]):
            note(bar * 4 + beat + 0.25, midi, 1.8, 0.06)
    save("wave-sunset.wav", samples)


def vehicle_feedback():
    # Periodic Fourier noise gives seamless original loops without recordings.
    for name, seed, low, high in [("wave-tires.wav", 713, 240, 2200),
                                  ("wave-wind.wav", 714, 45, 650)]:
        rng = random.Random(seed)
        partials = [(rng.randint(low * 2, high * 2) / 2,
                     rng.random() * TAU, rng.uniform(0.3, 1.0))
                    for _ in range(48)]
        samples = []
        for index in range(RATE * 2):
            t = index / RATE
            tone = sum(math.sin(TAU * frequency * t + phase) * gain
                       for frequency, phase, gain in partials) / 24
            if name == "wave-tires.wav":
                tone *= 0.8 + 0.2 * math.sin(TAU * 13 * t)
            samples.append(tone)
        save(name, samples)


def lakeshore():
    rng = random.Random(4187)
    duration = 10 * RATE
    overlap = RATE // 2
    foam = swell = 0.0
    recording = []
    for index in range(duration + overlap):
        t = index / RATE
        foam += (rng.uniform(-1.0, 1.0) - foam) * 0.24
        swell += (foam - swell) * 0.023
        lap = (0.5 + 0.5 * math.sin(TAU * (0.5 * t + 0.057 * math.sin(TAU * 0.2 * t)))) ** 3
        recording.append((foam - swell) * (0.045 + 0.12 * lap) + swell * 0.24)
    samples = recording[overlap:]
    for index in range(overlap):
        fade = 0.5 - 0.5 * math.cos(math.pi * (index + 1) / overlap)
        target = duration - overlap + index
        samples[target] = samples[target] * (1.0 - fade) + recording[index] * fade
    save("wave-lakeshore.wav", samples)


def creek():
    rng = random.Random(11903)
    duration = RATE * 8
    overlap = RATE // 3
    hiss = bed = 0.0
    recording = []
    for index in range(duration + overlap):
        t = index / RATE
        hiss += (rng.uniform(-1.0, 1.0) - hiss) * 0.31
        bed += (hiss - bed) * 0.041
        stream = 0.66 + 0.17 * math.sin(TAU * 1.25 * t) + 0.14 * math.sin(TAU * 3.1 * t + 1.7)
        bubbles = math.sin(TAU * (52.0 * t + 0.12 * math.sin(TAU * 6.4 * t)))
        recording.append((hiss - bed) * stream * 0.20 + bed * 0.24 + bubbles * abs(bed) * 0.10)
    samples = recording[overlap:]
    for index in range(overlap):
        fade = 0.5 - 0.5 * math.cos(math.pi * (index + 1) / overlap)
        target = duration - overlap + index
        samples[target] = samples[target] * (1.0 - fade) + recording[index] * fade
    save("wave-creek.wav", samples)


if __name__ == "__main__":
    OUTPUT.mkdir(parents=True, exist_ok=True)
    import sys
    if "--creek-only" in sys.argv:
        creek()
    elif "--lake-only" in sys.argv:
        lakeshore()
    elif "--vehicle-feedback-only" in sys.argv:
        vehicle_feedback()
    else:
        engine()
        evening()
        sunset()
        vehicle_feedback()
        lakeshore()
        creek()
