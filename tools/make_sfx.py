"""임시 효과음 생성: python tools/make_sfx.py  ->  assets/audio/sfx/*.wav
진짜 효과음 파일을 구하면 같은 이름으로 덮어쓰면 된다."""
import math
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio" / "sfx"


def tone(freq: float, start: float, length: float, vol: float, total: int) -> list[float]:
    out = [0.0] * total
    for i in range(int(length * RATE)):
        k = int(start * RATE) + i
        if k >= total:
            break
        t = i / RATE
        env = math.exp(-5.0 * t / length) * min(1.0, t * 200.0)  # 짧은 어택, 지수 감쇠
        out[k] += vol * env * (math.sin(2 * math.pi * freq * t) + 0.35 * math.sin(2 * math.pi * freq * 2 * t))
    return out


def save(name: str, notes: list[tuple[float, float, float, float]], seconds: float) -> None:
    total = int(seconds * RATE)
    mix = [0.0] * total
    for freq, start, length, vol in notes:
        for k, v in enumerate(tone(freq, start, length, vol, total)):
            mix[k] += v
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32000)) for v in mix))


# 교역 NPC 방문: 맑은 두 음 종소리
save("npc_visit", [(880.0, 0.0, 0.5, 0.35), (1320.0, 0.16, 0.7, 0.3)], 0.95)
print("ok")
