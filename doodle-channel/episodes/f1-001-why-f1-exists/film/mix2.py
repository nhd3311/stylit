"""Score, foley and voice → out/mix.wav (48 kHz stereo). Reads timeline2.json and events.json (v2: one voice take per paragraph).

Original score, synthesised here (no samples): electric piano, plucked bass, brushed kit.
The mood follows the story, set per scene in MOOD.
"""
import json, os, sys
from pathlib import Path
import numpy as np, soundfile as sf, soxr

HERE = Path(__file__).resolve().parent
sys.path.insert(0, os.path.join(os.environ.get('LIB', str(Path.home() / 'lemo-opuscar')), 'core', 'audio'))
import sfx  # noqa: E402
from sfx import SR, t_, env_exp, bp, lp, hp, noise, norm, compress, limit, add  # noqa: E402

T = json.loads((HERE / 'timeline2.json').read_text())
EV = json.loads((HERE / 'events.json').read_text())['ev']
DUR = T['dur']
N = int(DUR * SR) + SR
music, fx, voice = np.zeros((N, 2)), np.zeros((N, 2)), np.zeros((N, 2))

# ---------------- voice ----------------
for x in T['paras']:
    w, sr = sf.read(HERE / 'voice2' / f"{x['id']}.wav", dtype='float32')
    if w.ndim > 1: w = w.mean(1)
    add(voice, soxr.resample(compress(w, thr=.2, ratio=3), sr, SR), x['t0'], 1.0, 0)   # sfx.compress at 24 kHz is fine for speech

# ---------------- score ----------------
BPM = 100; BEAT = 60 / BPM; BAR = 4 * BEAT
def mood_of(i):
    p = i.split('_')[0]
    if i == 'TITLE' or i in ('P13_1', 'P16_1', 'P16_2', 'P16_3'): return 'triumph'
    if p in ('P06', 'P08', 'P12') or i == 'P07_3': return 'tense'
    if p == 'P07' or i in ('P13_2', 'P13_3'): return 'dark'
    if p == 'P17' or i == 'P16_4': return 'warm'
    return 'light'
SCENES = [(x['s0'], x['s1'], x['id']) for x in T['shots']]
def mood_at(t):
    for a, b, i in SCENES:
        if a <= t < b: return mood_of(i)
    return 'warm'

def hz(m): return 440 * 2 ** ((m - 69) / 12)
# chord progressions (root MIDI note, chord intervals) per mood
PROG = {
    'light':   [(60, (0, 4, 7, 11)), (57, (0, 3, 7, 10)), (53, (0, 4, 7, 11)), (55, (0, 4, 7, 10))],   # Cmaj7 Am7 Fmaj7 G7
    'tense':   [(57, (0, 3, 7)), (53, (0, 4, 7)), (50, (0, 3, 7)), (52, (0, 4, 7))],                 # Am F Dm E
    'dark':    [(57, (0, 3, 7)), (57, (0, 3, 7)), (53, (0, 4, 7)), (52, (0, 4, 7))],
    'triumph': [(62, (0, 4, 7)), (57, (0, 4, 7)), (59, (0, 3, 7)), (55, (0, 4, 7))],                 # D A Bm G
    'warm':    [(53, (0, 4, 7, 11)), (60, (0, 4, 7)), (50, (0, 3, 7, 10)), (58, (0, 4, 7))],         # Fmaj7 C Dm7 Bb
}

def epiano(f, d, v=1.0):
    tt = t_(d); e = np.exp(-tt / .35)
    x = np.sin(2 * np.pi * f * tt + 1.1 * e * np.sin(2 * np.pi * f * tt)) * np.exp(-tt / 1.4)
    x += .25 * np.sin(2 * np.pi * 2 * f * tt) * np.exp(-tt / .4)
    x *= np.minimum(1, tt / .004) * np.minimum(1, (d - tt) / .05)
    return x * v
def bass(f, d, v=1.0):
    tt = t_(d); x = np.sin(2 * np.pi * f * tt) + .35 * np.sin(4 * np.pi * f * tt) + .15 * np.sin(6 * np.pi * f * tt)
    return x * np.exp(-tt / .5) * np.minimum(1, tt / .005) * np.minimum(1, (d - tt) / .04) * v
def pad(f, d, v=1.0):
    tt = t_(d); x = sum(np.sin(2 * np.pi * f * k * tt + k) / k for k in (1, 2, 3))
    return lp(x, 1200) * np.minimum(1, tt / .8) * np.minimum(1, (d - tt) / .8) * v
def hat(v=1.0): d = .06; return hp(noise(d), 7000) * env_exp(d, .012) * v
def brush(v=1.0): d = .18; return bp(noise(d), 1500, 6000) * env_exp(d, .05) * v
def kick(v=1.0): return sfx.thump(v, 58)

r = np.random.default_rng(3)
bar_t = 0.0
while bar_t < DUR - 2:
    m = mood_at(bar_t + .01); bi = int(bar_t / BAR) % 4
    root, iv = PROG[m][bi]
    if m == 'dark':
        for k in iv: add(music, pad(hz(root + k - 12), BAR + .6, .10), bar_t, 1, (k - 4) / 12)
        add(music, bass(hz(root - 24), BAR, .25), bar_t, 1, 0)
    else:
        loud = {'light': .8, 'tense': .85, 'triumph': 1.0, 'warm': .75}[m]
        # comping: chord on 1 and the "and" of 2, a little humanised
        for beat in (0, 1.5, 3) if m != 'tense' else (0, 2):
            for j, k in enumerate(iv):
                add(music, epiano(hz(root + k), BEAT * 1.4, .11 * loud), bar_t + beat * BEAT + j * .008 + r.normal(0, .004), 1, (j - 1.5) * .25)
        # melody fragment on light/triumph/warm: pentatonic over the chord
        if m in ('light', 'triumph', 'warm') and bi in (0, 2):
            pent = [0, 2, 4, 7, 9]
            for s in range(4):
                n = root + 12 + pent[int(r.integers(0, 5))]
                add(music, epiano(hz(n), BEAT * .9, .07 * loud), bar_t + (s + .5) * BEAT, 1, .3)
        # bass: root–fifth walk
        for b, off in enumerate((0, 7, 12, 7) if m != 'tense' else (0, 0, 0, 0)):
            add(music, bass(hz(root - 24 + off), BEAT * .9, .32 * loud), bar_t + b * BEAT, 1, 0)
        # brushed kit
        for b in range(4):
            if b in (0, 2): add(music, kick(.32 * loud), bar_t + b * BEAT, 1, 0)
            if b in (1, 3): add(music, brush(.22 * loud), bar_t + b * BEAT, 1, .1)
            for h in (0, .5): add(music, hat(.08 * loud), bar_t + (b + h) * BEAT + r.normal(0, .003), 1, -.25)
    bar_t += BAR

# fade in/out
fade = np.ones(N); fi, fo = int(1.5 * SR), int(3.5 * SR); fade[:fi] = np.linspace(0, 1, fi); end = int((DUR - .3) * SR)
fade[end - fo:end] *= np.linspace(1, 0, fo); fade[end:] = 0
music *= fade[:, None]

# ducking: music −8 dB under the voice, smooth
env = np.abs(voice).mean(1); win = int(.25 * SR)
env = np.convolve(env, np.ones(win) / win, 'same'); env = np.clip(env / (env.max() * .15 + 1e-9), 0, 1)
music *= (1 - .6 * env)[:, None]

# ---------------- foley from the page events ----------------
def crowd(d=2.2, v=1.0):
    tt = t_(d); x = bp(noise(d), 300, 2500) * np.sin(np.pi * np.minimum(1, tt / d)) ** .6
    return x * v
def chug(d=3.0, v=1.0):
    out = np.zeros(int(d * SR))
    for i in range(int(d / .18)): x = sfx.thump(.6, 95); s = int(i * .18 * SR); out[s:s + len(x)] += x[:len(out) - s]
    return out * v
def stamp_fx():
    x = sfx.thump(.9, 80).copy(); c = sfx.clack(.8, .6); x[:len(c)] += c; return x
FX = {
    'cut': lambda: sfx.whoosh(.3, .18), 'stamp': lambda: stamp_fx(),
    'tick': lambda: sfx.ding(.35), 'ding': lambda: sfx.ding(.45), 'title': lambda: sfx.thump(.9, 60),
    'engine': lambda: sfx.roar(2.0, .35), 'pass': lambda: sfx.whoosh(.7, .5), 'cheer': lambda: crowd(2.4, .22),
    'chug': lambda: chug(3.0, .25), 'paper': lambda: sfx.whoosh(.25, .25), 'draw': lambda: sfx.whoosh(.5, .12),
    'low': lambda: sfx.rumble(2.0, .3), 'glint': lambda: sfx.ding(.3), 'doors': lambda: sfx.creak(.5),
    'type': lambda: sfx.click(.7, .25), 'press': lambda: chug(2.5, .2), 'click': lambda: sfx.click(1.0, .5), 'thump': lambda: sfx.thump(.6, 70), 'night': lambda: np.zeros(10),
}
for e in EV:
    f = FX.get(e['type'])
    if f: add(fx, f(), e['t'], 1.0, 0)

# ---------------- balance & master ----------------
def rms(x): return float(np.sqrt(np.mean(x[np.abs(x).max(1) > 1e-4] ** 2))) if np.any(x) else 1e-9
v_rms, m_rms = rms(voice), rms(music)
music *= (v_rms / m_rms) * 10 ** (-12 / 20)          # music ≈ 12 dB under the voice before ducking
fx *= (v_rms / max(rms(fx), 1e-9)) * 10 ** (-14 / 20)
mix = voice + music + fx
mix = mix / max(1e-9, np.abs(mix).max()) * .9
mix = np.stack([limit(mix[:, 0], .95), limit(mix[:, 1], .95)], 1)
(HERE / 'out').mkdir(exist_ok=True)
sf.write(HERE / 'out' / 'mix2.wav', mix[:int(DUR * SR)].astype(np.float32), SR)
print(f"mix.wav {DUR:.1f}s  voice rms {20*np.log10(v_rms):.1f} dBFS (pre-master)")
