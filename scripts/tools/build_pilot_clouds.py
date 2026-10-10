"""Bake original periodic value noise used by the pilot sky, without dependencies."""
import hashlib
import json
import math
from pathlib import Path
import struct
import zlib


def lattice(x, y, period):
    value = ((x % period) * 374761393 + (y % period) * 668265263 + 5547) & 0xffffffff
    value = ((value ^ (value >> 13)) * 1274126177) & 0xffffffff
    return (value ^ (value >> 16)) / 0xffffffff


def noise(x, y, period):
    ix, iy = math.floor(x), math.floor(y)
    fx, fy = x - ix, y - iy
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = lattice(ix, iy, period) * (1 - fx) + lattice(ix + 1, iy, period) * fx
    b = lattice(ix, iy + 1, period) * (1 - fx) + lattice(ix + 1, iy + 1, period) * fx
    return a * (1 - fy) + b * fy


def build():
    size = 512
    raw = bytearray()
    for y in range(size):
        raw.append(0)
        for x in range(size):
            value = sum(noise(x / size * frequency, y / size * frequency, frequency) * weight
                        for frequency, weight in [(16, .62), (32, .26), (64, .12)])
            raw.append(round(value * 255))
    def chunk(kind, data):
        return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', zlib.crc32(kind + data))
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!2I5B', size, size, 8, 0, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))


if __name__ == '__main__':
    output = Path(__file__).resolve().parents[2] / 'assets/textures/pilot'
    data = build()
    (output / 'cloud-noise.png').write_bytes(data)
    (output / 'cloud-noise-provenance.json').write_text(json.dumps({
        'author': 'Wave project', 'license': 'MIT (project)',
        'source': 'Original deterministic periodic value noise, three baked octaves, seed 5547',
        'generator': 'scripts/tools/build_pilot_clouds.py', 'sha256': hashlib.sha256(data).hexdigest()}, indent=2) + '\n')
    print('Pilot cloud noise:', len(data), 'bytes')
