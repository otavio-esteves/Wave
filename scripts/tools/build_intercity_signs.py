"""Original static wayfinding, using Wave's offline bitmap alphabet."""
import hashlib
import json
from pathlib import Path
from build_corridor_signs import build

SIGNS = [
    ('VILA DA SERRA', (48, 79, 65), (236, 226, 198)),
    ('PARADA DA SERRA', (52, 76, 91), (236, 226, 198)),
    ('BAIRRO DO SOL', (48, 79, 65), (236, 226, 198)),
    ('PRACA DA VILA', (52, 76, 91), (236, 226, 198)),
]

if __name__ == '__main__':
    destination = Path(__file__).resolve().parents[2] / 'assets/textures/intercity'
    destination.mkdir(parents=True, exist_ok=True)
    image = build(SIGNS, fit_text=True)
    (destination / 'wayfinding.png').write_bytes(image)
    (destination / 'provenance.json').write_text(json.dumps({
        'asset': 'wayfinding.png', 'author': 'Wave project', 'license': 'MIT (project)',
        'source': 'original project bitmap alphabet; deterministic standard-library PNG generation',
        'generator': 'scripts/tools/build_intercity_signs.py',
        'labels': [sign[0] for sign in SIGNS], 'sha256': hashlib.sha256(image).hexdigest(),
    }, indent=2) + '\n')
    print('Intercity signs saved:', destination)
