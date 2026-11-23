"""Build Wave's original audio using only Python's standard library.

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


def road_engine():
    # A four-stroke inline four fires four times in two revolutions. Each
    # band has a different exhaust/induction balance and an integer number
    # of complete cycles so changing the playback rate never exposes a seam.
    bands = (
        ("wave-gol-idle.wav", 960, 0.07, 102, 225),
        ("wave-gol-load.wav", 2640, 0.15, 128, 315),
        ("wave-gol-high.wav", 5040, 0.23, 160, 450),
        ("wave-gol-coast.wav", 2400, 0.04, 108, 238),
    )
    for index, (name, rpm, intake, exhaust_peak, intake_peak) in enumerate(bands):
        rng = random.Random(240 + index)
        firing = rpm / 30
        harmonics = []
        for order in range(1, 18):
            frequency = order * firing
            exhaust = math.exp(-((frequency - exhaust_peak) / 119) ** 2) * 0.70
            induction = math.exp(-((frequency - intake_peak) / 160) ** 2) * intake * 1.9
            harmonics.append((frequency, (0.22 + exhaust + induction) / order ** 0.91,
                              -0.28 * order + rng.uniform(-0.12, 0.12)))
        texture = [(rng.randrange(310, 1550), rng.random() * TAU) for _ in range(17)]
        samples = []
        for sample in range(RATE):
            t = sample / RATE
            crank = TAU * firing * t
            cylinder = 1.0 + 0.066 * math.sin(crank / 4) + 0.038 * math.cos(crank / 2 + 1.2)
            pulses = sum(level * math.sin(TAU * hz * t + phase) for hz, level, phase in harmonics)
            breath = sum(math.sin(TAU * hz * t + phase) for hz, phase in texture) / len(texture)
            chatter = math.sin(crank / 2 - 0.18) * (0.15 if index == 0 else 0.078)
            samples.append(pulses * cylinder + chatter + breath * intake * (1.2 + 0.7 * math.cos(crank)))
        rms = math.sqrt(sum(value * value for value in samples) / len(samples))
        save(name, [0.67 * math.tanh(value * (0.22 / rms) / 0.67) for value in samples])


def vehicle_contacts():
    profiles = (
        ("wave-hit-masonry.wav", 622, 0.36, [(57, 0.47, 24), (108, 0.18, 38)], 0.42, 0.70),
        ("wave-hit-bodywork.wav", 641, 0.48, [(69, 0.45, 19), (225, 0.16, 22),
                                              (347, 0.20, 16), (613, 0.11, 31)], 0.30, 0.85),
        ("wave-hit-suspension.wav", 651, 0.26, [(46, 0.53, 26), (96, 0.22, 38)], 0.16, 0.28),
    )
    for name, seed, duration, resonances, grit, snap in profiles:
        rng = random.Random(seed)
        filtered = 0.0
        samples = []
        for index in range(round(duration * RATE)):
            t = index / RATE
            noise = rng.uniform(-1.0, 1.0)
            filtered += (noise - filtered) * 0.21
            body = sum(math.sin(TAU * hz * t) * level * math.exp(-decay * t)
                       for hz, level, decay in resonances)
            crack = (noise - filtered) * snap * math.exp(-115 * t)
            debris = filtered * grit * math.exp(-24 * t) * (0.7 + 0.3 * math.sin(TAU * 93 * t))
            edge = min(1.0, t / 0.002, (duration - t) / 0.025)
            samples.append((body + crack + debris) * edge)
        save(name, samples)

    rng = random.Random(708)
    partials = [(rng.randint(165, 2900), rng.random() * TAU, rng.uniform(0.55, 1.0))
                for _ in range(39)]
    samples = []
    for index in range(RATE):
        t = index / RATE
        roughness = sum(math.sin(TAU * hz * t + phase) * level for hz, phase, level in partials) / 19
        ring = 0.047 * math.sin(TAU * 935 * t + 2.3 * math.sin(TAU * 7 * t))
        samples.append((roughness + ring) * (0.86 + 0.14 * math.sin(TAU * 31 * t)))
    save("wave-scrape.wav", samples)


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


def road_surfaces():
    """Three rolling beds with the same 3-second seamless phase."""
    duration = 3 * RATE
    overlap = RATE // 4
    profiles = (
        ("wave-roll-asphalt.wav", 49, 0.039, 0.089, 0.19),
        ("wave-roll-cobbles.wav", 83, 0.064, 0.065, 0.27),
        ("wave-roll-loose.wav", 96, 0.082, 0.114, 0.21),
    )
    for profile, (name, seed, grit_gain, bass_gain, response) in enumerate(profiles):
        rng = random.Random(seed)
        color = body = 0.0
        recording = []
        for index in range(duration + overlap):
            t = index / RATE
            noise = rng.uniform(-1.0, 1.0)
            color += (noise - color) * response
            body += (color - body) * 0.021
            grain = color - body
            if profile == 1:
                # Stagger the front/rear pattern instead of making a metronome.
                impact = max(0.0, math.sin(TAU * 11.0 * t + 0.27 * math.sin(TAU * 3 * t))) ** 7
                underbody = math.sin(TAU * 83.0 * t) * 0.21 + math.sin(TAU * 116.0 * t) * 0.08
                grain = grain * (0.34 + impact * 1.4) + underbody * impact
            elif profile == 2:
                flecks = max(0.0, math.sin(TAU * 17.0 * t + math.sin(TAU * 5.0 * t))) ** 4
                grain = grain * (0.51 + flecks) + (noise - color) * flecks * 0.20
            recording.append(grain * grit_gain + body * bass_gain)
        samples = recording[overlap:]
        for index in range(overlap):
            fade = 0.5 - 0.5 * math.cos(math.pi * (index + 1) / overlap)
            tail = duration - overlap + index
            samples[tail] = samples[tail] * (1.0 - fade) + recording[index] * fade
        rms = math.sqrt(sum(sample * sample for sample in samples) / len(samples))
        gain = (0.105, 0.137, 0.116)[profile] / max(rms, 0.001)
        save(name, [0.69 * math.tanh(sample * gain / 0.69) for sample in samples])


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


def rainfall():
    """A soft bed with brief, irregular drops and a crossfaded loop."""
    rng = random.Random(7031)
    length = 6 * RATE
    overlap = RATE // 5
    recording = []
    bed = drop = 0.0
    for _ in range(length + overlap):
        noise = rng.uniform(-1.0, 1.0)
        bed += (noise - bed) * 0.14
        drop *= 0.982
        if rng.random() < 0.018:
            drop = rng.uniform(0.016, 0.23)
        recording.append(0.33 * bed + (noise - bed) * (0.056 + drop))
    samples = recording[overlap:]
    for index in range(overlap):
        fade = 0.5 - 0.5 * math.cos(math.pi * (index + 1) / overlap)
        target = length - overlap + index
        samples[target] = samples[target] * (1.0 - fade) + recording[index] * fade
    save("wave-rain.wav", samples)


if __name__ == "__main__":
    OUTPUT.mkdir(parents=True, exist_ok=True)
    import sys
    if "--creek-only" in sys.argv:
        creek()
    elif "--lake-only" in sys.argv:
        lakeshore()
    elif "--vehicle-feedback-only" in sys.argv:
        vehicle_feedback()
    elif "--road-surface-only" in sys.argv:
        road_surfaces()
    elif "--rain-only" in sys.argv:
        rainfall()
    elif "--road-audio-only" in sys.argv:
        road_engine()
        vehicle_contacts()
    else:
        engine()
        road_engine()
        vehicle_contacts()
        evening()
        sunset()
        vehicle_feedback()
        road_surfaces()
        lakeshore()
        creek()
        rainfall()
