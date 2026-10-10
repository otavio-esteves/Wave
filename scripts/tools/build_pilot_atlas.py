"""Original address digits, rasterized offline without font dependencies."""
import hashlib
import json
import struct
import zlib
from pathlib import Path

DIGITS = [
    ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
    ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
    ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
    ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    ["11111", "10000", "10000", "11110", "00001", "00001", "11110"],
    ["01110", "10000", "10000", "11110", "10001", "10001", "01110"],
    ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
    ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
    ["01110", "10001", "10001", "01111", "00001", "00001", "01110"],
]


def build() -> bytes:
    width, height = 320, 48
    pixels = bytearray(width * height * 3)
    for y in range(height):
        for x in range(width):
            digit, local_x = divmod(x, 32)
            gx, gy = (local_x - 6) // 4, (y - 10) // 4
            ink = 0 <= gx < 5 and 0 <= gy < 7 and DIGITS[digit][gy][gx] == "1"
            color = (235, 227, 204) if ink else (40, 51, 55)
            at = (y * width + x) * 3
            pixels[at:at + 3] = bytes(color)

    def chunk(kind, data):
        return struct.pack("!I", len(data)) + kind + data + struct.pack("!I", zlib.crc32(kind + data))

    raw = b"".join(b"\0" + pixels[y * width * 3:(y + 1) * width * 3] for y in range(height))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack("!2I5B", width, height, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


if __name__ == "__main__":
    output = Path(__file__).resolve().parents[2] / "assets/textures/pilot"
    output.mkdir(parents=True, exist_ok=True)
    atlas = build()
    (output / "address-atlas.png").write_bytes(atlas)
    (output / "provenance.json").write_text(json.dumps({
        "author": "Wave project", "license": "MIT (project)",
        "source": "Original 5 by 7 bitmap digits; deterministic standard-library PNG",
        "generator": "scripts/tools/build_pilot_atlas.py", "sha256": hashlib.sha256(atlas).hexdigest(),
    }, indent=2) + "\n")
    print(f"Address atlas: {len(atlas)} bytes")
