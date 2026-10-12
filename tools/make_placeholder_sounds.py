"""Fabrique les sons provisoires du jeu (fichiers WAV), par calcul.

Ce ne sont pas des sons définitifs : ils servent à « sentir » les coups en
attendant de vrais enregistrements (kora, djembé, voix...). Pour remplacer un
son, il suffit de déposer un fichier du même nom dans assets/audio/sfx/.

Utilisation (depuis le dossier du projet) :
    python tools/make_placeholder_sounds.py
"""

import wave
from pathlib import Path

import numpy as np

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio" / "sfx"
rng = np.random.default_rng(7)


def time(seconds: float) -> np.ndarray:
    return np.arange(int(RATE * seconds)) / RATE


def decay(t: np.ndarray, speed: float) -> np.ndarray:
    return np.exp(-t * speed)


def noise(t: np.ndarray, smooth: int = 1) -> np.ndarray:
    """Bruit blanc ; smooth > 1 l'adoucit (sons plus sourds)."""
    raw = rng.uniform(-1, 1, len(t))
    if smooth > 1:
        raw = np.convolve(raw, np.ones(smooth) / smooth, mode="same") * np.sqrt(smooth)
    return raw


def sweep(t: np.ndarray, start: float, end: float) -> np.ndarray:
    """Son dont la hauteur glisse de start à end (en hertz)."""
    frequency = np.linspace(start, end, len(t))
    return np.sin(2 * np.pi * np.cumsum(frequency) / RATE)


def save(name: str, signal: np.ndarray, volume: float = 0.8) -> None:
    signal = signal / max(1e-6, np.abs(signal).max()) * volume
    fade = min(len(signal), int(RATE * 0.005))
    signal[-fade:] *= np.linspace(1, 0, fade)
    data = (signal * 32767).astype("<i2")
    with wave.open(str(OUT / f"{name}.wav"), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(data.tobytes())
    print(f"  {name}.wav ({len(signal) / RATE:.2f} s)")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    t = time(0.12)
    save("hit_light", noise(t, 3) * decay(t, 40) + 0.8 * np.sin(2 * np.pi * 140 * t) * decay(t, 30), 0.7)
    t = time(0.28)
    save("hit_heavy", noise(t, 6) * decay(t, 18) + 1.2 * sweep(t, 110, 45) * decay(t, 12), 0.9)
    t = time(0.1)
    save("block", (np.sin(2 * np.pi * 1800 * t) + 0.6 * np.sin(2 * np.pi * 2650 * t)) * decay(t, 60)
         + 0.3 * noise(t) * decay(t, 90), 0.5)
    t = time(0.45)
    save("parry", (np.sin(2 * np.pi * 1320 * t) + 0.5 * np.sin(2 * np.pi * 1980 * t)
                   + 0.25 * np.sin(2 * np.pi * 2640 * t)) * decay(t, 8), 0.6)
    t = time(0.16)
    envelope = np.sin(np.pi * t / t[-1])
    save("whoosh", noise(t, 12) * envelope, 0.35)
    t = time(0.4)
    save("special", sweep(t, 260, 880) * (0.6 + 0.4 * np.sin(2 * np.pi * 18 * t)) * decay(t, 4), 0.55)
    t = time(1.0)
    save("ultimate", (sweep(t, 70, 150) + 0.4 * sweep(t, 420, 900) * np.sin(np.pi * t)) * decay(t, 2.5), 0.85)
    t = time(0.9)
    save("ko", 1.4 * sweep(t, 90, 35) * decay(t, 4) + noise(t, 10) * decay(t, 6), 0.95)
    t = time(0.28)
    save("dodge", sweep(t, 1400, 280) * decay(t, 9), 0.4)
    t = time(0.35)
    chime = np.where(t < 0.12, np.sin(2 * np.pi * 660 * t), np.sin(2 * np.pi * 990 * t))
    save("assist", chime * decay(t, 7), 0.5)
    t = time(1.4)
    gong = sum(a * np.sin(2 * np.pi * f * t) for f, a in [(196, 1), (293, 0.5), (412, 0.35), (587, 0.2)])
    save("gong", gong * decay(t, 2.2) * (1 - np.exp(-t * 200)), 0.7)
    t = time(0.05)
    save("ui_click", np.sin(2 * np.pi * 1000 * t) * decay(t, 70), 0.4)
    print(f"-> sons dans {OUT}")


if __name__ == "__main__":
    main()
