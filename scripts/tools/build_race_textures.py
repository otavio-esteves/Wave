"""Original, reproducible tiling materials and foliage; Python standard library only.
No downloaded photographs or game assets. Colors deliberately muted for daylight.
"""
from pathlib import Path
import math
import random
import struct
import zlib

OUT = Path(__file__).resolve().parents[2] / 'assets/textures/race'
OUT.mkdir(parents=True, exist_ok=True)
SIZE = 512
rng = random.Random(2005)


def png(name, pixels, size=SIZE):
    def chunk(kind, data):
        return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', zlib.crc32(kind + data))
    raw = b''.join(b'\0' + bytes(pixels[y * size * 4:(y + 1) * size * 4]) for y in range(size))
    header = struct.pack('!2I5B', size, size, 8, 6, 0, 0, 0)
    (OUT / (name + '.png')).write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))


def noise_grid(cells):
    return [[rng.random() for _ in range(cells)] for _ in range(cells)]


def noise(grid, x, y):
    n = len(grid)
    u, v = x * n / SIZE, y * n / SIZE
    i, j = int(u), int(v)
    a, b = u - i, v - j
    a, b = a * a * (3 - 2 * a), b * b * (3 - 2 * b)
    return (grid[j % n][i % n] * (1 - a) + grid[j % n][(i + 1) % n] * a) * (1 - b) + (grid[(j + 1) % n][i % n] * (1 - a) + grid[(j + 1) % n][(i + 1) % n] * a) * b


def normal_map(name, heights, strength):
    data = bytearray(SIZE * SIZE * 4)
    for y in range(SIZE):
        for x in range(SIZE):
            dx = (heights[y * SIZE + (x + 1) % SIZE] - heights[y * SIZE + (x - 1) % SIZE]) * strength
            dy = (heights[((y + 1) % SIZE) * SIZE + x] - heights[((y - 1) % SIZE) * SIZE + x]) * strength
            length = math.sqrt(dx * dx + dy * dy + 1)
            at = (y * SIZE + x) * 4
            data[at:at + 4] = bytes((int(127.5 - 127.5 * dx / length), int(127.5 - 127.5 * dy / length), int(127.5 + 127.5 / length), 255))
    png(name + '_normal', data)


for name in ('asphalt', 'concrete', 'brick', 'grass', 'metal'):
    coarse, medium = noise_grid(8), noise_grid(32)
    pixels = bytearray(SIZE * SIZE * 4)
    heights = []
    brick_colors = [[rng.uniform(-13, 13) for _ in range(8)] for _ in range(16)]
    for y in range(SIZE):
        for x in range(SIZE):
            broad = noise(coarse, x, y) - .5
            grain = rng.uniform(-1, 1)
            fine = noise(medium, x, y) - .5
            height = grain * .025
            if name == 'asphalt':
                c = 60 + broad * 12 + fine * 8 + grain * 7
                color = (c, c * 1.03, c * 1.045)
            elif name == 'concrete':
                c = 151 + broad * 23 + fine * 11 + grain * 8
                seam = min(x % 128, y % 128) < 2
                color = (c * .97, c * .97, c * .94) if not seam else (83, 84, 78)
                height = .15 if not seam else 0
            elif name == 'brick':
                row = y // 32
                u = (x + (32 if row % 2 else 0)) % SIZE
                mortar = y % 32 < 3 or u % 64 < 3
                c = brick_colors[row][u // 64] + broad * 11 + grain * 10
                color = (142 + c, 103 + c * .8, 80 + c * .6) if not mortar else (122 + grain * 7, 119 + grain * 7, 109 + grain * 7)
                height = .25 + fine * .08 if not mortar else 0
            elif name == 'grass':
                c = broad * 34 + fine * 24 + grain * 14
                color = (82 + c, 91 + c, 61 + c * .7)
                height = grain * .07
            else:
                c = 115 + broad * 18 + grain * 4 + 15 * math.cos(x * math.tau * 32 / SIZE)
                color = (c, c * .98, c * .93)
                height = .15 * math.cos(x * math.tau * 32 / SIZE)
            heights.append(height)
            at = (y * SIZE + x) * 4
            pixels[at:at + 4] = bytes([max(0, min(255, int(c))) for c in color] + [255])
    if name == 'asphalt':
        # Sparse repaired cracks, irregularly branched instead of parallel waves.
        for crack in range(3):
            x, y = rng.randrange(SIZE), rng.randrange(SIZE)
            for step in range(rng.randrange(90, 190)):
                x += rng.choice((-1, 0, 1))
                y += 1
                at = ((y % SIZE) * SIZE + x % SIZE)
                pixels[at * 4:at * 4 + 4] = bytes((39, 41, 42, 255))
                heights[at] -= .045
    png(name, pixels)
    normal_map(name, heights, 1.4 if name == 'brick' else .6)

# Branch silhouette with hundreds of overlapping small leaf clusters, alpha tested.
size = 256
pixels = bytearray(size * size * 4)

def ellipse(cx, cy, rx, ry, color):
    for y in range(max(0, int(cy - ry)), min(size, int(cy + ry + 1))):
        for x in range(max(0, int(cx - rx)), min(size, int(cx + rx + 1))):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1:
                at = (y * size + x) * 4
                pixels[at:at + 4] = bytes(color)

for step in range(195):
    ellipse(127 + math.sin(step / 40) * 3, 245 - step, 2.5, 3, (79, 71, 49, 255))
for _ in range(1350):
    angle = rng.random() * math.tau
    radius = math.sqrt(rng.random())
    x = 128 + math.cos(angle) * radius * 111
    y = 111 + math.sin(angle) * radius * 96
    if rng.random() < .1 and radius > .65:
        continue
    c = rng.randrange(-19, 27)
    ellipse(x, y, rng.randrange(2, 6), rng.randrange(2, 5), (76 + c, 91 + c, 49 + c // 2, 255))
png('foliage', pixels, size)
print('Saved 11 original textures to', OUT)
