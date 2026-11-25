"""Generate the ten Infinite Tower biome ambient music loops.

Every track is synthesised from scratch (no samples), so the music is original and the
script is the source of truth. Output is deterministic: the same seed gives the same file.

Each loop is seamless. All rendering is circular: every oscillator runs a whole number of
cycles over the loop, noise is shaped in the frequency domain, and every note, echo and
reverb tail that runs past the end wraps back onto the start.

Usage (needs numpy):
    python tools/generate_biome_ambience.py                 # all ten biomes
    python tools/generate_biome_ambience.py --only 4 9      # just Frozen and Astral
    python tools/generate_biome_ambience.py --out some/dir --seconds 64

Writes 44.1 kHz 16-bit stereo WAVs named biome01_verdant.wav ... biome10_abyssal.wav into
assets/music/biomes/ (gitignored). Upload them as Audio assets and put the IDs in
SoundCatalog (Biome1_Verdant ... Biome10_Abyssal).
"""

from __future__ import annotations

import argparse
import os
import wave

import numpy as np

SR = 44100


# ----------------------------------------------------------------------------- helpers

def midi(n: float) -> float:
    return 440.0 * 2.0 ** ((n - 69) / 12.0)


class Track:
    """A circular stereo buffer of `seconds` length."""

    def __init__(self, seconds: float, seed: int):
        self.L = seconds
        self.N = int(round(seconds * SR))
        self.t = np.arange(self.N) / SR
        self.buf = np.zeros((2, self.N))
        self.rng = np.random.default_rng(seed)

    # Frequencies snapped to whole cycles over the loop so sustained tones never click.
    def q(self, f: float) -> float:
        return max(1.0, round(f * self.L)) / self.L

    def lfo(self, cycles: int, phase: float = 0.0, lo: float = 0.0, hi: float = 1.0) -> np.ndarray:
        s = 0.5 - 0.5 * np.cos(2 * np.pi * cycles * self.t / self.L + phase)
        return lo + (hi - lo) * s

    def add(self, sig: np.ndarray, pan: float = 0.0, gain: float = 1.0) -> None:
        """Add a mono (N,) or stereo (2, N) full-length signal."""
        if sig.ndim == 1:
            l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
            self.buf[0] += sig * l * gain * 1.414
            self.buf[1] += sig * r * gain * 1.414
        else:
            self.buf += sig * gain

    def place(self, ev: np.ndarray, start_s: float, pan: float = 0.0, gain: float = 1.0) -> None:
        """Add a short mono event at `start_s`, wrapping past the loop end."""
        i0 = int(start_s * SR) % self.N
        idx = (i0 + np.arange(len(ev))) % self.N
        l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        np.add.at(self.buf[0], idx, ev * l * gain * 1.414)
        np.add.at(self.buf[1], idx, ev * r * gain * 1.414)

    # ---- spectral tools (circular by nature)
    def shape(self, sig: np.ndarray, curve) -> np.ndarray:
        spec = np.fft.rfft(sig)
        f = np.fft.rfftfreq(len(sig), 1 / SR)
        return np.fft.irfft(spec * curve(f), n=len(sig))

    def noise(self, curve, seed_off: int = 0) -> np.ndarray:
        w = self.rng.standard_normal(self.N)
        out = self.shape(w, curve)
        return out / (np.sqrt(np.mean(out ** 2)) + 1e-12)

    def reverb(self, seconds: float, mix: float, damp_hz: float = 6000.0, predelay: float = 0.02) -> None:
        n = int(seconds * SR)
        out = np.zeros_like(self.buf)
        for ch in range(2):
            ir = self.rng.standard_normal(n) * np.exp(-6.9 * np.arange(n) / n)
            ir = np.concatenate([np.zeros(int(predelay * SR)), ir])
            ir = np.pad(ir, (0, self.N - len(ir))) if len(ir) < self.N else ir[: self.N]
            irf = np.fft.rfft(ir)
            f = np.fft.rfftfreq(self.N, 1 / SR)
            irf *= 1 / (1 + (f / damp_hz) ** 2)
            wet = np.fft.irfft(np.fft.rfft(self.buf[ch]) * irf, n=self.N)
            wet /= np.sqrt(np.mean(wet ** 2)) + 1e-12
            dry_rms = np.sqrt(np.mean(self.buf[ch] ** 2)) + 1e-12
            out[ch] = self.buf[ch] * (1 - mix) + wet * dry_rms * mix
        self.buf = out

    def finish(self, rms_db: float = -19.0) -> np.ndarray:
        x = self.buf - self.buf.mean(axis=1, keepdims=True)
        # gentle low cut under 30 Hz, circularly
        for ch in range(2):
            x[ch] = self.shape(x[ch], lambda f: 1 / np.sqrt(1 + (30 / np.maximum(f, 1e-3)) ** 4))
        rms = np.sqrt(np.mean(x ** 2)) + 1e-12
        x *= 10 ** (rms_db / 20) / rms
        x = np.tanh(x * 1.2) / np.tanh(1.2)  # soft ceiling
        peak = np.max(np.abs(x))
        if peak > 0.97:
            x *= 0.97 / peak
        return x


# ----------------------------------------------------------------------------- instruments

def env_ad(n: int, attack: float, decay: float) -> np.ndarray:
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-t / decay)


def pad(tr: Track, notes, amp=0.2, harmonics=6, rolloff=1.4, detune=0.0025, swell=(1, 0.0), pan_spread=0.5,
        bright_lfo: int = 0) -> None:
    """Sustained chord of detuned additive voices. `swell` = (cycles, phase) of the amplitude breath."""
    cyc, ph = swell
    amp_env = tr.lfo(cyc, ph, 0.35, 1.0) if cyc else 1.0
    for i, n in enumerate(notes):
        f0 = midi(n)
        pan = (i / max(1, len(notes) - 1) * 2 - 1) * pan_spread if len(notes) > 1 else 0
        for d in (-detune, detune):
            sig = np.zeros(tr.N)
            for k in range(1, harmonics + 1):
                f = tr.q(f0 * k * (1 + d))
                if f > 9000:
                    break
                ka = 1 / k ** rolloff
                if bright_lfo and k > 1:
                    ka = ka * tr.lfo(bright_lfo, k * 0.7, 0.3, 1.0)
                sig += ka * np.sin(2 * np.pi * f * tr.t + tr.rng.uniform(0, 6.28))
            tr.add(sig * amp_env, pan=pan + d * 60, gain=amp / len(notes))


def drone(tr: Track, note: float, amp=0.3, harmonics=4, beat_cycles=3) -> None:
    f = tr.q(midi(note))
    f2 = tr.q(midi(note) * 1.003)
    s = np.zeros(tr.N)
    for k in range(1, harmonics + 1):
        s += (np.sin(2 * np.pi * tr.q(f * k) * tr.t) + np.sin(2 * np.pi * tr.q(f2 * k) * tr.t)) / k ** 1.6
    tr.add(s * tr.lfo(beat_cycles, 0, 0.6, 1.0), gain=amp)


def pluck(freq: float, dur: float = 2.5, bright: float = 0.996, rng=None) -> np.ndarray:
    """Karplus-Strong plucked string."""
    n = int(dur * SR)
    p = max(2, int(SR / freq))
    rng = rng or np.random.default_rng(0)
    buf = rng.uniform(-1, 1, p)
    out = np.zeros(n)
    for i in range(0, n, p):
        seg = buf.copy()
        out[i:i + p] = seg[: max(0, min(p, n - i))]
        buf = bright * 0.5 * (buf + np.roll(buf, 1))
    return out * env_ad(n, 0.002, dur / 2.5)


def bell(freq: float, dur: float = 4.0, ratios=(1, 2.76, 5.4, 8.93), decay=1.5) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = np.zeros(n)
    for j, r in enumerate(ratios):
        s += np.sin(2 * np.pi * freq * r * t) * np.exp(-t * (1 + j * 1.2) / decay) / (1 + j)
    return s * np.clip(t / 0.003, 0, 1)


def soft_tone(freq: float, dur: float = 3.0, attack: float = 0.4, decay: float = 1.2, harm=3) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = sum(np.sin(2 * np.pi * freq * k * t) / k ** 2 for k in range(1, harm + 1))
    e = np.clip(t / attack, 0, 1) * np.exp(-np.maximum(t - attack, 0) / decay)
    return s * e


def fm_glass(freq: float, dur: float = 5.0, index: float = 2.0, ratio: float = 3.5) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    idx = index * np.exp(-t / 0.6)
    s = np.sin(2 * np.pi * freq * t + idx * np.sin(2 * np.pi * freq * ratio * t))
    return s * np.clip(t / 0.004, 0, 1) * np.exp(-t / (dur / 3.5))


def drum(freq: float = 55, dur: float = 1.6, rng=None) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    fsweep = freq * (1 + 1.5 * np.exp(-t / 0.03))
    body = np.sin(2 * np.pi * np.cumsum(fsweep) / SR) * np.exp(-t / 0.35)
    rng = rng or np.random.default_rng(1)
    skin = rng.standard_normal(n) * np.exp(-t / 0.02) * 0.3
    return body + skin


def thunder(rng, dur: float = 7.0) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    w = rng.standard_normal(n)
    spec = np.fft.rfft(w)
    f = np.fft.rfftfreq(n, 1 / SR)
    spec *= 1 / (1 + (f / 180) ** 2)
    rum = np.fft.irfft(spec, n=n)
    rum /= np.max(np.abs(rum)) + 1e-12
    env = np.clip(t / 0.25, 0, 1) * np.exp(-t / 2.2)
    # rolling bursts
    for _ in range(4):
        c = rng.uniform(0.3, 3.5)
        env += 0.5 * np.exp(-((t - c) / 0.35) ** 2)
    return rum * env


def metal_clang(freq: float, dur: float = 3.5) -> np.ndarray:
    return bell(freq, dur, ratios=(1, 1.47, 2.09, 2.56, 3.39, 4.08), decay=0.9)


def bubble(rng) -> np.ndarray:
    dur = rng.uniform(0.04, 0.12)
    n = int(dur * SR)
    t = np.arange(n) / SR
    f0 = rng.uniform(500, 1400)
    f = f0 * (1 + 2.5 * t / dur)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / (dur / 3)) * np.clip(t / 0.002, 0, 1)


def drip(rng, f0=None) -> np.ndarray:
    dur = 0.25
    n = int(dur * SR)
    t = np.arange(n) / SR
    f0 = f0 or rng.uniform(900, 2200)
    f = f0 * (1 + 0.8 * np.exp(-t / 0.01))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.05)


def glide(f_from: float, f_to: float, dur: float, vib=0.0) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = t / dur
    f = f_from * (f_to / f_from) ** (0.5 - 0.5 * np.cos(np.pi * x))
    f = f * (1 + vib * np.sin(2 * np.pi * 5 * t))
    env = np.sin(np.pi * x) ** 2
    ph = 2 * np.pi * np.cumsum(f) / SR
    return (np.sin(ph) + 0.25 * np.sin(2 * ph)) * env


def chirp(rng) -> np.ndarray:
    """Small synthetic bird call."""
    out = []
    base = rng.uniform(2800, 4200)
    for _ in range(rng.integers(2, 5)):
        dur = rng.uniform(0.05, 0.1)
        n = int(dur * SR)
        t = np.arange(n) / SR
        f = base * (1 + rng.uniform(-0.25, 0.3) * t / dur)
        out.append(np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / dur) ** 2)
        out.append(np.zeros(int(rng.uniform(0.03, 0.08) * SR)))
    return np.concatenate(out)


def formant_curve(vowel: str):
    table = {"ah": [(730, 90), (1090, 110), (2440, 160)], "oo": [(300, 60), (870, 90), (2240, 140)],
             "eh": [(530, 80), (1840, 120), (2480, 160)]}
    fs = table[vowel]

    def c(f):
        g = np.zeros_like(f)
        for i, (fc, bw) in enumerate(fs):
            g += np.exp(-0.5 * ((f - fc) / bw) ** 2) / (1 + i)
        return g + 0.02
    return c


def choir(tr: Track, notes, vowel="ah", amp=0.25, pan_spread=0.6) -> None:
    for i, n in enumerate(notes):
        f0 = midi(n)
        for v in range(3):
            d = (v - 1) * 0.004
            f = tr.q(f0 * (1 + d))
            ph = 2 * np.pi * f * tr.t
            saw = np.zeros(tr.N)
            for k in range(1, 30):
                if f * k > 6000:
                    break
                saw += np.sin(k * ph + v) / k
            sig = tr.shape(saw, formant_curve(vowel))
            sig /= np.sqrt(np.mean(sig ** 2)) + 1e-12
            pan = ((i / max(1, len(notes) - 1)) * 2 - 1) * pan_spread + (v - 1) * 0.2
            tr.add(sig * tr.lfo(1 + v, v + i, 0.5, 1.0), pan=float(np.clip(pan, -1, 1)), gain=amp / len(notes) / 3)


def lowpass(f, fc, order=2):
    return 1 / np.sqrt(1 + (f / fc) ** (2 * order))


def bandpass(f, lo, hi):
    return lowpass(f, hi, 2) / np.sqrt(1 + (lo / np.maximum(f, 1e-3)) ** 4)


def scatter(tr: Track, count: int, make, gain_range=(0.1, 0.2), pan_range=(-0.8, 0.8), grid: float | None = None):
    for i in range(count):
        if grid:
            start = (i * grid + tr.rng.uniform(-0.05, 0.05)) % tr.L
        else:
            start = tr.rng.uniform(0, tr.L)
        tr.place(make(i), start, pan=tr.rng.uniform(*pan_range), gain=tr.rng.uniform(*gain_range))


# ----------------------------------------------------------------------------- biomes

def verdant(tr: Track):
    """Verdant Ruins: warm, green, hopeful morning among mossy ruins. D major pentatonic."""
    pad(tr, [50, 57, 62, 66, 69], amp=0.5, harmonics=5, rolloff=1.8, swell=(4, 0.0), bright_lfo=2)
    pad(tr, [38], amp=0.25, harmonics=3, rolloff=2)
    scale = [62, 64, 66, 69, 71, 74, 76, 78, 81]
    # slow harp phrases
    t = 0.0
    while t < tr.L - 1:
        for k in range(tr.rng.integers(3, 6)):
            n = scale[tr.rng.integers(0, len(scale))]
            tr.place(pluck(midi(n), 3.0, 0.997, tr.rng), t + k * 0.38, pan=tr.rng.uniform(-0.5, 0.5),
                     gain=0.09)
        t += tr.rng.uniform(4.5, 7.5)
    scatter(tr, 14, lambda i: chirp(tr.rng), gain_range=(0.015, 0.04), pan_range=(-1, 1))
    tr.add(tr.noise(lambda f: bandpass(f, 300, 2500)) * tr.lfo(3, 1, 0.2, 1), gain=0.025)
    tr.reverb(3.5, 0.35, 7000)


def fungal(tr: Track):
    """Fungal Hollow: bioluminescent caverns, dripping, curious and a little eerie. E dorian."""
    pad(tr, [40, 52, 59, 62, 66], amp=0.45, harmonics=7, rolloff=1.3, detune=0.006, swell=(3, 1.0), bright_lfo=5)
    scale = [64, 66, 67, 69, 71, 73, 74, 76, 78, 83]
    # glowing marimba-ish blips with dotted echoes
    for i in range(int(tr.L / 1.6)):
        if tr.rng.random() < 0.45:
            n = scale[tr.rng.integers(0, len(scale))]
            ev = soft_tone(midi(n), 1.4, 0.005, 0.25, harm=2)
            s = i * 1.6
            p = tr.rng.uniform(-0.6, 0.6)
            for e in range(4):
                tr.place(ev, s + e * 0.6, pan=p * (-1) ** e, gain=0.08 * 0.5 ** e)
    scatter(tr, 40, lambda i: drip(tr.rng), gain_range=(0.03, 0.08), pan_range=(-1, 1))
    tr.add(tr.noise(lambda f: bandpass(f, 60, 200)), gain=0.04)
    tr.reverb(5.0, 0.5, 5000, 0.05)


def ashen(tr: Track):
    """Ashen Dunes: dry wind over buried ruins, sparse and haunting. D phrygian dominant."""
    drone(tr, 38, amp=0.16, harmonics=6, beat_cycles=2)
    drone(tr, 45, amp=0.07, harmonics=4, beat_cycles=3)
    scale = [62, 63, 66, 67, 69, 70, 72, 74, 75]
    t = 1.0
    while t < tr.L - 2:
        phrase = tr.rng.integers(2, 6)
        idx = tr.rng.integers(2, len(scale) - 2)
        for k in range(phrase):
            idx = int(np.clip(idx + tr.rng.integers(-2, 3), 0, len(scale) - 1))
            tr.place(pluck(midi(scale[idx]), 2.0, 0.993, tr.rng), t, pan=tr.rng.uniform(-0.3, 0.3), gain=0.22)
            t += tr.rng.choice([0.25, 0.5, 0.75])
        t += tr.rng.uniform(4, 8)
    # gusting sand wind
    w = tr.noise(lambda f: bandpass(f, 250, 3500))
    tr.add(np.stack([w * tr.lfo(3, 0, 0.1, 1), np.roll(w, 7000) * tr.lfo(3, 2, 0.1, 1)]), gain=0.09)
    tr.reverb(2.5, 0.3, 4500)


def frozen(tr: Track):
    """Frozen Citadel: still, cold and crystalline. F# minor with glass bells."""
    pad(tr, [54, 61, 66, 69, 73, 78], amp=0.4, harmonics=3, rolloff=2.2, detune=0.0015, swell=(2, 0.5),
        pan_spread=0.8)
    scale = [78, 80, 81, 85, 88, 90, 93, 97]
    for i in range(int(tr.L / 2.0)):
        if tr.rng.random() < 0.55:
            n = scale[tr.rng.integers(0, len(scale))]
            tr.place(fm_glass(midi(n), 5.0, 1.6, 3.5), i * 2.0 + tr.rng.uniform(0, 0.4),
                     pan=tr.rng.uniform(-0.9, 0.9), gain=0.06)
    w = tr.noise(lambda f: bandpass(f, 1200, 7000))
    tr.add(np.stack([w * tr.lfo(2, 0, 0.05, 1), np.roll(w, 13000) * tr.lfo(2, 2.5, 0.05, 1)]), gain=0.045)
    tr.reverb(6.0, 0.55, 9000, 0.04)


def infernal(tr: Track):
    """Infernal Foundry: heat, molten iron and distant hammers. C minor with a flat second."""
    drone(tr, 24, amp=0.28, harmonics=8, beat_cycles=4)
    pad(tr, [36, 43, 48, 49], amp=0.25, harmonics=8, rolloff=1.1, detune=0.004, swell=(2, 0.0), bright_lfo=3)
    # forge rhythm: two anvils in a slow, uneven call-and-response
    beat = 60 / 52
    for i in range(int(tr.L / beat)):
        if i % 4 in (0, 3) or tr.rng.random() < 0.12:
            tr.place(metal_clang(tr.rng.choice([220.0, 233.0, 262.0]), 2.5), i * beat, pan=-0.5, gain=0.15)
        if i % 8 == 6:
            tr.place(metal_clang(175.0, 3.0), i * beat, pan=0.6, gain=0.13)
        if i % 4 == 0:
            tr.place(drum(42, 1.4, tr.rng), i * beat, gain=0.25)
    # bubbling lava rumble
    tr.add(tr.noise(lambda f: lowpass(f, 120, 2)) * tr.lfo(8, 0, 0.4, 1), gain=0.12)
    tr.add(tr.noise(lambda f: bandpass(f, 2000, 6000)) * tr.lfo(5, 1, 0, 1) ** 3, gain=0.015)
    tr.reverb(3.0, 0.4, 3500)


def thunder_hl(tr: Track):
    """Thunder Highlands: open, wind-swept peaks under a storm. A aeolian, open fifths, war drums."""
    pad(tr, [33, 40, 45, 52, 57, 64], amp=0.45, harmonics=6, rolloff=1.5, swell=(2, 1.2), pan_spread=0.9)
    # distant war drums
    beat = 60 / 70
    pattern = [1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 1]
    bars = int(tr.L / (beat * 4))
    for b in range(bars):
        if b % 4 == 3:
            continue
        for s, hit in enumerate(pattern):
            if hit:
                tr.place(drum(60 if s % 4 else 48, 1.5, tr.rng), (b * 16 + s) * beat / 4, pan=-0.2, gain=0.16)
    # horn-like call
    for t0 in (6.0, 38.0):
        for k, n in enumerate([57, 64, 62, 57]):
            tr.place(soft_tone(midi(n), 3.5, 0.5, 1.4, harm=5), t0 + k * 2.2, pan=0.3, gain=0.05)
    tr.add(tr.noise(lambda f: bandpass(f, 800, 9000)), gain=0.05)  # rain
    for t0 in tr.rng.uniform(0, tr.L, 4):
        tr.place(thunder(tr.rng, 7.0), t0, pan=tr.rng.uniform(-0.7, 0.7), gain=0.35)
    tr.reverb(4.0, 0.4, 6000)


def corrupted(tr: Track):
    """Corrupted Grove: a sick, breathing forest. Detuned tritones and bending tones."""
    pad(tr, [41, 47, 53, 56], amp=0.4, harmonics=6, rolloff=1.3, detune=0.012, swell=(3, 0.0), bright_lfo=4)
    choir(tr, [65, 71], vowel="oo", amp=0.25)
    # creaking, bending tones
    for _ in range(8):
        f = midi(tr.rng.choice([65, 66, 71, 72]))
        tr.place(glide(f, f * tr.rng.choice([0.94, 1.06, 0.89]), tr.rng.uniform(3, 6), vib=0.004),
                 tr.rng.uniform(0, tr.L), pan=tr.rng.uniform(-0.8, 0.8), gain=0.05)
    # heartbeat-like pulse of the Mother Graft
    for i in range(int(tr.L / 1.6)):
        tr.place(drum(40, 0.8, tr.rng), i * 1.6, gain=0.08)
        tr.place(drum(38, 0.8, tr.rng), i * 1.6 + 0.28, gain=0.05)
    tr.add(tr.noise(lambda f: bandpass(f, 3000, 8000)) * tr.lfo(7, 0, 0, 1) ** 4, gain=0.02)  # whispers
    tr.reverb(4.5, 0.5, 4000, 0.03)


def sunken(tr: Track):
    """Sunken Sanctuary: a drowned temple. Muffled sacred choir, whale song, bubbles. Bb lydian."""
    choir(tr, [46, 53, 58, 62, 64], vowel="oo", amp=0.4)
    pad(tr, [34, 41], amp=0.25, harmonics=3, rolloff=2)
    for _ in range(4):
        f = midi(tr.rng.choice([58, 62, 65]))
        tr.place(glide(f, f * tr.rng.choice([1.5, 0.75, 1.33]), tr.rng.uniform(4, 7), vib=0.006),
                 tr.rng.uniform(0, tr.L), pan=tr.rng.uniform(-0.6, 0.6), gain=0.05)
    scatter(tr, 60, lambda i: bubble(tr.rng), gain_range=(0.02, 0.06), pan_range=(-1, 1))
    # temple bell far away
    for t0 in (3.0, 35.0):
        tr.place(bell(midi(58), 8.0, decay=3.0), t0, gain=0.08)
    # everything under water: muffle the whole mix
    for ch in range(2):
        tr.buf[ch] = tr.shape(tr.buf[ch], lambda f: lowpass(f, 1600, 2))
    tr.add(tr.noise(lambda f: lowpass(f, 250, 2)) * tr.lfo(4, 0, 0.5, 1), gain=0.05)
    tr.reverb(6.5, 0.55, 2500, 0.06)


def astral(tr: Track):
    """Astral Archives: starlight and floating libraries, wonder. C lydian celesta arpeggios."""
    pad(tr, [48, 55, 62, 66, 71, 76], amp=0.4, harmonics=4, rolloff=1.8, swell=(2, 0.0), pan_spread=0.9,
        bright_lfo=2)
    arp = [72, 76, 79, 83, 86, 90, 88, 83]
    step = 0.25
    for i in range(int(tr.L / step)):
        if (i // 32) % 2 == 1 and tr.rng.random() < 0.6:
            continue
        n = arp[i % len(arp)] + (12 if (i // 64) % 2 else 0)
        tr.place(bell(midi(n), 2.5, ratios=(1, 4.0, 10.0), decay=0.6), i * step,
                 pan=np.sin(i * 0.4) * 0.8, gain=0.035)
    scatter(tr, 50, lambda i: fm_glass(tr.rng.uniform(3000, 6000), 1.2, 0.5, 1.41), gain_range=(0.005, 0.015),
            pan_range=(-1, 1))
    tr.reverb(6.0, 0.55, 10000, 0.05)


def abyssal(tr: Track):
    """Abyssal Throne: the final dread. Sub drones, a dark choir cluster and a slow doom pulse."""
    drone(tr, 21, amp=0.55, harmonics=8, beat_cycles=2)
    drone(tr, 27, amp=0.2, harmonics=6, beat_cycles=3)  # tritone over A
    choir(tr, [45, 48, 51, 52], vowel="ah", amp=0.3)
    pad(tr, [69, 70], amp=0.08, harmonics=2, rolloff=2, detune=0.003, swell=(1, 0.0))  # thin minor-second whine
    for i in range(int(tr.L / 4.0)):
        tr.place(drum(36, 3.0, tr.rng), i * 4.0, gain=0.3)
        if i % 4 == 2:
            tr.place(metal_clang(110.0, 5.0), i * 4.0 + 2.0, pan=tr.rng.uniform(-0.5, 0.5), gain=0.05)
    tr.add(tr.noise(lambda f: lowpass(f, 90, 2)) * tr.lfo(4, 0.5, 0.3, 1), gain=0.12)
    tr.reverb(7.0, 0.5, 3000, 0.05)


BIOMES = [
    (1, "verdant", verdant),
    (2, "fungal", fungal),
    (3, "ashen", ashen),
    (4, "frozen", frozen),
    (5, "infernal", infernal),
    (6, "thunder", thunder_hl),
    (7, "corrupted", corrupted),
    (8, "sunken", sunken),
    (9, "astral", astral),
    (10, "abyssal", abyssal),
]


def write_wav(path: str, x: np.ndarray) -> None:
    pcm = (np.clip(x.T, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def main() -> None:
    here = os.path.dirname(os.path.abspath(__file__))
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(here, "..", "assets", "music", "biomes"))
    ap.add_argument("--seconds", type=float, default=64.0)
    ap.add_argument("--only", type=int, nargs="*")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    for idx, name, fn in BIOMES:
        if a.only and idx not in a.only:
            continue
        tr = Track(a.seconds, seed=1000 + idx)
        fn(tr)
        x = tr.finish()
        path = os.path.join(a.out, f"biome{idx:02d}_{name}.wav")
        write_wav(path, x)
        print(f"{path}  peak={np.max(np.abs(x)):.2f}  seam={np.max(np.abs(x[:, 0] - x[:, -1])):.3f}")


if __name__ == "__main__":
    main()
