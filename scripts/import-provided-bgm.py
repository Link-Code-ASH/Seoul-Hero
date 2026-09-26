"""Copy the six user-provided MP3s without altering or re-encoding them."""
from pathlib import Path
import hashlib
import json
import shutil

root = Path(__file__).resolve().parents[1]
target = root / 'assets/audio/bgm/provided'
target.mkdir(parents=True, exist_ok=True)
music = {
    'BGM 1.mp3': 'menu_01.mp3', 'BGM 2.mp3': 'menu_02.mp3',
    'BGM 3.mp3': 'menu_03.mp3', 'Guild 1.mp3': 'guild_01.mp3',
    'Ingame 1.mp3': 'combat_01.mp3', 'Ingame 2.mp3': 'combat_02.mp3',
}

def sha256(path: Path) -> str:
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

records = []
for original, deployed in music.items():
    source = Path.home() / 'Desktop' / original
    if not source.is_file():
        raise FileNotFoundError(source)
    output = target / deployed
    shutil.copy2(source, output)
    checksum = sha256(source)
    if checksum != sha256(output):
        raise ValueError(f'Copy differs from source: {original}')
    records.append({'original': original, 'deployed': deployed, 'bytes': output.stat().st_size, 'sha256': checksum})

(target / 'SOURCES.json').write_text(json.dumps(records, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(f'Copied {len(records)} MP3s, {sum(item["bytes"] for item in records)} bytes; SHA-256 matches.')
