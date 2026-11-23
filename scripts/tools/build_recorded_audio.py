"""Edit the CC0 recordings listed in assets/audio/credits.md into game clips."""

from argparse import ArgumentParser
from math import atan2, cos, exp, pi, sin, sqrt, tanh, tau

from audio_files import read_mono
from build_audio import RATE, save


ENGINE = (
    ("idle", 269771, 0.34, 29.4, 960, 20, 3600),
    ("low", 152661, 22.56, 56.5, 1710, 39, 4400),
    ("mid", 152661, 10.04, 108.0, 2880, 52, 5300),
    ("high", 152661, 18.77, 133.0, 4080, 66, 6500),
    ("redline", 152661, 19.15, 135.0, 5550, 90, 6600),
    ("overrun", 808203, 90.55, 47.8, 2160, 50, 3400),
)


def filter_band(samples, rate, bass, treble):
    slow = fast = 0.0
    low_cut = 1.0 - exp(-tau * bass / rate)
    high_cut = 1.0 - exp(-tau * treble / rate)
    result = []
    for value in samples:
        slow += (value - slow) * low_cut
        fast += (value - slow - fast) * high_cut
        result.append(fast)
    return result


def interpolate(samples, position):
    position = min(max(position, 0.0), len(samples) - 1.01)
    index = int(position)
    return samples[index] + (samples[index + 1] - samples[index]) * (position - index)


def level(samples, rms, ceiling=0.74):
    measured = sqrt(sum(value * value for value in samples) / len(samples))
    gain = rms / max(measured, 1e-5)
    return [ceiling * tanh(value * gain / ceiling) for value in samples]


def pitch_mark(samples, rate, center, hint):
    # Estimate the dominant firing frequency and its phase around this grain.
    radius = round(rate * 0.095)
    frames = range(-radius, radius, 12)
    data = [samples[center + i] * (0.5 + 0.5 * cos(pi * i / radius)) for i in frames]
    best_power = -1.0
    pitch = hint
    shift = 0.0
    for offset in range(-16, 17):
        frequency = hint * (1.0 + offset * 0.008)
        phase = tau * frequency / rate
        real = sum(signal * cos(i * phase) for signal, i in zip(data, frames))
        imag = sum(signal * sin(i * phase) for signal, i in zip(data, frames))
        power = real * real + imag * imag
        if power > best_power:
            best_power = power
            pitch = frequency
            shift = atan2(imag, real) / phase
    return center + shift, pitch


def engine_clip(source, hint, rpm, bass, treble):
    rate, raw = source
    filtered = filter_band(raw, rate, bass, treble)
    firing = rpm / 30.0
    # Each grain covers two strides. Their raised-cosine windows sum to one.
    # Align the centers to whole firing cycles so the layers don't flutter.
    stride = round(round(firing * 0.185) * RATE / firing)
    grains = 6
    output = [0.0] * (stride * grains)
    for grain in range(grains):
        center = round((0.29 + grain * 0.149) * rate)
        site, hz = pitch_mark(filtered, rate, center, hint)
        step = rate * firing / (RATE * hz)
        for i in range(-stride, stride):
            window = 0.5 + 0.5 * cos(pi * i / stride)
            output[(grain * stride + i) % len(output)] += interpolate(filtered, site + i * step) * window
    return level(output, 0.25 if rpm <= 1000 else 0.22)


def edit(source, seconds, bass, treble, speed=1.0):
    rate, samples = source
    filtered = filter_band(samples, rate, bass, treble)
    step = rate * speed / RATE
    return [interpolate(filtered, i * step) for i in range(round(seconds * RATE))]


def loop(source, seconds, bass, treble, rms, speed=1.0):
    overlap = min(0.24, seconds * 0.21)
    raw = edit(source, seconds + overlap, bass, treble, speed)
    fade_length = round(overlap * RATE)
    samples = raw[fade_length:]
    for i in range(fade_length):
        fade = 0.5 - 0.5 * cos(pi * (i + 1) / fade_length)
        last = len(samples) - fade_length + i
        samples[last] = samples[last] * (1.0 - fade) + raw[i] * fade
    return level(samples, rms)


def hit(source, kind, heavy):
    if kind == "bodywork":
        duration, bass, speed, decay = (0.43, 43, 0.79, 6.0) if heavy else (0.28, 61, 1.11, 11.0)
        resonances = (65, 154, 264) if heavy else (88, 204, 359)
    elif kind == "wall":
        duration, bass, speed, decay = (0.39, 54, 0.88, 10.0) if heavy else (0.24, 80, 1.27, 15.0)
        resonances = (53, 98, 182) if heavy else (74, 138, 241)
    else:
        duration, bass, speed, decay = 0.23, 28, 0.84, 16.0
        resonances = (46, 72, 117)
    texture = level(edit(source, duration, bass, 3850, speed), 0.15)
    output = []
    for i, sample in enumerate(texture):
        t = i / RATE
        core = sum(weight * sin(tau * hz * t) for hz, weight in zip(resonances, (0.54, 0.19, 0.079)))
        edge = min(1.0, t / 0.003, (duration - t) / 0.030)
        output.append((core * exp(-decay * 2.0 * t) + sample * exp(-decay * t)) * edge)
    return output


def build(folder):
    def recording(identifier, start, seconds):
        return read_mono(folder / f"audio-source-{identifier}.mp3", start, seconds)

    for band, identifier, start, pitch, rpm, bass, treble in ENGINE:
        save(f"wave-motor-{band}.wav", engine_clip(recording(identifier, start, 1.42), pitch, rpm, bass, treble))

    save("wave-road-asphalt.wav", loop(recording(591079, 13.20, 5.0), 4.2, 120, 4000, 0.11))
    save("wave-road-pavers.wav", loop(recording(831720, 0.80, 3.42), 2.8, 92, 4600, 0.13))
    save("wave-road-gravel.wav", loop(recording(685231, 15.67, 5.5), 4.7, 118, 5900, 0.14))
    save("wave-road-wet.wav", loop(recording(342461, 21.0, 5.0), 3.7, 620, 7800, 0.10, 1.18))
    save("wave-rain-cabin.wav", loop(recording(342461, 12.0, 9.0), 8.0, 85, 4150, 0.12))
    save("wave-wheel-squeal.wav", loop(recording(104026, 0.30, 1.53), 1.42, 380, 4500, 0.16, 0.92))
    stone = recording(321488, 0.34, 2.01)
    door = recording(424031, 0.003, 0.307)
    save("wave-grind-wall.wav", loop(stone, 1.42, 190, 6200, 0.16))
    save("wave-grind-metal.wav", loop(stone, 1.30, 535, 7700, 0.14, 1.19))
    for heavy in (False, True):
        suffix = "hard" if heavy else "soft"
        save(f"wave-contact-wall-{suffix}.wav", hit(stone, "wall", heavy))
        save(f"wave-contact-bodywork-{suffix}.wav", hit(door, "bodywork", heavy))
    save("wave-contact-suspension.wav", hit(door, "suspension", False))
    click = edit(door, 0.13, 250, 2900, 1.53)
    save("wave-transmission-shift.wav", [value * min(1.0, i / (RATE * 0.003))
                                        * exp(-39.0 * i / RATE) for i, value in enumerate(click)])


if __name__ == "__main__":
    from pathlib import Path

    parser = ArgumentParser(description=__doc__)
    parser.add_argument("recordings", type=Path, help="directory containing the CC0 MP3 previews by sound ID")
    build(parser.parse_args().recordings)
