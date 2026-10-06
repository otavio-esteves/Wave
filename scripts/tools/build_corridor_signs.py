"""Deterministic, original painted signs. Standard library; no runtime font layout.
A small uppercase bitmap alphabet is enough for static signs seen while driving.
PNG is rendered offline, then imported with the same opaque shader as facades.
"""
from pathlib import Path
import random
import struct
import zlib

GLYPHS = {
    'A': ['01110', '10001', '10001', '11111', '10001', '10001', '10001'],
    'C': ['01111', '10000', '10000', '10000', '10000', '10000', '01111'],
    'D': ['11110', '10001', '10001', '10001', '10001', '10001', '11110'],
    'E': ['11111', '10000', '10000', '11110', '10000', '10000', '11111'],
    'F': ['11111', '10000', '10000', '11110', '10000', '10000', '10000'],
    'I': ['11111', '00100', '00100', '00100', '00100', '00100', '11111'],
    'L': ['10000', '10000', '10000', '10000', '10000', '10000', '11111'],
    'M': ['10001', '11011', '10101', '10101', '10001', '10001', '10001'],
    'N': ['10001', '11001', '11001', '10101', '10011', '10011', '10001'],
    'O': ['01110', '10001', '10001', '10001', '10001', '10001', '01110'],
    'R': ['11110', '10001', '10001', '11110', '10100', '10010', '10001'],
    'U': ['10001', '10001', '10001', '10001', '10001', '10001', '01110'],
    'V': ['10001', '10001', '10001', '10001', '10001', '01010', '00100'],
    ' ': ['00000'] * 7,
}
SIGNS = [('OFICINA ALVORADA', (52, 76, 91), (236, 226, 198)),
         ('MERCADO DO VALE', (211, 185, 145), (52, 63, 59)),
         ('RUA DO VALE', (52, 76, 91), (236, 226, 198)),
         ('AVENIDA DO VALE', (52, 76, 91), (236, 226, 198))]


def build() -> bytes:
    size = 512
    tile = size // 2
    pixels = bytearray(size * size * 3)
    rng = random.Random(5547)
    for index, (text, background, foreground) in enumerate(SIGNS):
        ox, oy = index % 2 * tile, index // 2 * tile
        width = len(text) * 6 - 1
        scale_x, scale_y = (3 if index == 2 else 2 if index == 3 else 1), 14
        tx, ty = (tile - width * scale_x) // 2, (tile - 7 * scale_y) // 2
        for y in range(tile):
            for x in range(tile):
                cx, cy = x - tx, y - ty
                ink = False
                if 0 <= cx < width * scale_x and 0 <= cy < 7 * scale_y:
                    character, column = divmod(cx // scale_x, 6)
                    ink = column < 5 and GLYPHS[text[character]][cy // scale_y][column] == '1'
                shade = rng.randrange(-5, 6)
                color = foreground if ink else tuple(max(0, min(255, c + shade)) for c in background)
                if x < 2 or y < 2 or x > tile - 3 or y > tile - 3:
                    color = tuple(int(c * .75) for c in color)
                at = ((oy + y) * size + ox + x) * 3
                pixels[at:at + 3] = bytes(color)
    def chunk(kind, data):
        return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', zlib.crc32(kind + data))
    raw = b''.join(b'\0' + pixels[y * size * 3:(y + 1) * size * 3] for y in range(size))
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!2I5B', size, size, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')


if __name__ == '__main__':
    destination = Path(__file__).resolve().parents[2] / 'assets/textures/corridor/signs.png'
    destination.write_bytes(build())
    print('Painted signs saved:', destination)
