#!/usr/bin/env python3
"""Procedurally synthesize the game's sound effects as 16-bit mono WAVs.
No external assets — run this to (re)generate everything in ../audio/.
"""
import wave, struct, math, os
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")
os.makedirs(OUT, exist_ok=True)

def _t(dur):
    return np.linspace(0, dur, int(SR * dur), endpoint=False)

def env_exp(n, k=5.0):
    x = np.linspace(0, 1, n)
    return np.exp(-k * x)

def env_ad(n, attack=0.01, dur=None):
    # short linear attack, exponential decay
    a = max(1, int(SR * attack))
    e = np.ones(n)
    e[:a] = np.linspace(0, 1, a)
    e[a:] *= np.exp(-5.0 * np.linspace(0, 1, n - a))
    return e

def sine(f, t):
    return np.sin(2 * math.pi * f * t)

def save(name, data, gain=0.9):
    data = np.asarray(data, dtype=np.float64)
    peak = np.max(np.abs(data)) or 1.0
    data = data / peak * gain
    # gentle soft-clip
    data = np.tanh(data * 1.2)
    pcm = np.int16(np.clip(data, -1, 1) * 32767)
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("wrote", os.path.relpath(path))

# --- shoot: quick downward laser chirp -------------------------------------
def shoot():
    d = 0.09
    t = _t(d)
    f = np.linspace(720, 330, t.size)
    phase = 2 * math.pi * np.cumsum(f) / SR
    wave_ = 0.7 * np.sin(phase) + 0.3 * np.sign(np.sin(phase))  # sine + a little square bite
    save("shoot.wav", wave_ * env_exp(t.size, 6.0), gain=0.55)

# --- enemy_hit: tiny bright tick -------------------------------------------
def enemy_hit():
    d = 0.05
    t = _t(d)
    tone = np.sin(2 * math.pi * 900 * t)
    noise = np.random.uniform(-1, 1, t.size) * 0.5
    save("enemy_hit.wav", (tone + noise) * env_exp(t.size, 14.0), gain=0.45)

# --- enemy_death: noisy little explosion -----------------------------------
def enemy_death():
    d = 0.28
    t = _t(d)
    noise = np.random.uniform(-1, 1, t.size)
    # low body sweep
    f = np.linspace(220, 60, t.size)
    body = np.sin(2 * math.pi * np.cumsum(f) / SR)
    mix = 0.6 * noise + 0.6 * body
    save("enemy_death.wav", mix * env_exp(t.size, 5.0), gain=0.7)

# --- ally_collect: pleasant rising two-note chime --------------------------
def ally_collect():
    notes = [523.25, 783.99, 1046.5]  # C5, G5, C6
    seg = 0.075
    out = []
    for i, fq in enumerate(notes):
        t = _t(seg)
        s = np.sin(2 * math.pi * fq * t) + 0.4 * np.sin(2 * math.pi * fq * 2 * t)
        out.append(s * env_ad(t.size, attack=0.005))
    save("ally_collect.wav", np.concatenate(out), gain=0.6)

# --- player_hurt: low thud -------------------------------------------------
def player_hurt():
    d = 0.18
    t = _t(d)
    f = np.linspace(180, 90, t.size)
    body = np.sin(2 * math.pi * np.cumsum(f) / SR)
    noise = np.random.uniform(-1, 1, t.size) * 0.35
    save("player_hurt.wav", (body + noise) * env_exp(t.size, 7.0), gain=0.7)

# --- wave: two rising notes (progress cue) ---------------------------------
def wave_cue():
    notes = [440.0, 660.0]
    seg = 0.12
    out = []
    for fq in notes:
        t = _t(seg)
        s = np.sin(2 * math.pi * fq * t) + 0.3 * np.sin(2 * math.pi * fq * 3 * t)
        out.append(s * env_ad(t.size, attack=0.01))
    save("wave.wav", np.concatenate(out), gain=0.5)

# --- game_over: descending tone --------------------------------------------
def game_over():
    d = 0.7
    t = _t(d)
    f = np.linspace(420, 110, t.size)
    s = np.sin(2 * math.pi * np.cumsum(f) / SR) + 0.3 * np.sin(2 * math.pi * np.cumsum(f) / SR * 2)
    save("game_over.wav", s * env_exp(t.size, 3.0), gain=0.6)

if __name__ == "__main__":
    np.random.seed(7)  # deterministic output
    shoot(); enemy_hit(); enemy_death(); ally_collect()
    player_hurt(); wave_cue(); game_over()
    print("done")
