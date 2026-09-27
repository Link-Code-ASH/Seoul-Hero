"""Cut one quiet clock transient from the user's Sonniss antique-clock source."""

from pathlib import Path
import sys
import wave

import numpy as np


def pcm24_mono(path: Path) -> tuple[np.ndarray, int]:
    with wave.open(str(path), 'rb') as source:
        rate, channels, width = source.getframerate(), source.getnchannels(), source.getsampwidth()
        if width != 3:
            raise ValueError('Expected 24-bit PCM source')
        raw = np.frombuffer(source.readframes(min(source.getnframes(), rate * 12)), np.uint8)
    samples = raw.reshape(-1, channels, 3).astype(np.int32)
    values = samples[:, :, 0] | (samples[:, :, 1] << 8) | (samples[:, :, 2] << 16)
    values = np.where(values >= 0x800000, values - 0x1000000, values)
    return values.mean(axis=1).astype(np.float64) / 8388608, rate


def main() -> None:
    source = Path(sys.argv[1])
    target = Path(sys.argv[2])
    signal, rate = pcm24_mono(source)
    window = rate // 200
    energy = np.sqrt(np.mean(signal[:len(signal) // window * window].reshape(-1, window) ** 2, axis=1))
    candidates = np.argsort(energy)[::-1]
    onset = next(index * window for index in candidates if 0.5 * rate < index * window < 10 * rate)
    start = max(0, onset - int(0.018 * rate))
    clip = signal[start:start + int(0.19 * rate)]
    # Gentle low-pass keeps the antique mechanical click from piercing the mix.
    clip = np.convolve(clip, np.ones(5) / 5, mode='same')[::2]
    fade = min(len(clip) // 3, 600)
    clip[-fade:] *= np.linspace(1, 0, fade)
    clip[:80] *= np.linspace(0, 1, 80)
    clip *= 0.55 / max(0.01, np.max(np.abs(clip)))
    target.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(target), 'wb') as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(rate // 2)
        out.writeframes((np.clip(clip, -1, 1) * 32767).astype('<i2').tobytes())
    print(f'{source.name}: {start / rate:.3f}s - {(start + int(0.19 * rate)) / rate:.3f}s -> {target}')


if __name__ == '__main__':
    main()
