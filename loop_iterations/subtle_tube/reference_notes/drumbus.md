# reference_notes — drumbus / mixbus (subtle_tube)

Material used: `Drum_Test.wav`, `Epic_Drum_Test.wav`, `EDM_Test.wav`, `Disco_Test.wav`
(plus steady-tone probes `100hz_test.wav`, `Middle_C_Test.wav`).
`listening_blinded: false` (single-listener project, R-ListeningProtocol allows this
with the flag recorded).

---

## voice_stage `saturn_like`, iter 00 — first listening pass

**Loudness-matched**: yes (candidate matched to each dry file's integrated
loudness; +2.6…+6.4 dB compensation, monitoring only, not written to parameters).

**Human feedback (2026-08-11)**
> "Tube 跟 Saturation 目前聽感大致還行，但有共同的問題：數位感 / 高頻粗糙，
> 高頻聽起來有點麻麻的。降低麻麻的感覺讓它通透一點。"

Summary: overall direction accepted; **shared defect in both tracks** — digital
character / harsh, "fizzy" (麻麻) highs. Wants the fizz reduced while keeping the
top end open and transparent (通透), i.e. *not* by dulling the highs.

**TRANSLATE — what was ruled out first (§3.6 caveat: the table is heuristic)**

1. *Aliasing (H1)* — the table's first suggestion for "digital / harsh highs".
   **Ruled out by measurement** (`tools/diagnoseAliasing`): alias energy is
   −130 dB for 2–8 kHz tones and −70 dB at 11 kHz; processing at OS=4 differs
   from an OS=32 gold reference by only −74.8 dB on real EDM material. Raising
   oversampling would change nothing audible.
2. *A defect in our model vs Saturn* — **ruled out**: on pink noise the model
   matches the Saturn reference to within **0.02–0.04 dB in every octave band**,
   and 8 kHz harmonic generation matches within 0.22 dB. The fizz is Saturn's own
   character (inherent to a full-bandwidth digital waveshaper), faithfully
   reproduced — not a modelling error.

**Conclusion**: this is exactly the Phase B situation R-ReferenceFreeze describes.
Saturn is no longer the target; the user wants *better than Saturn* here.

**First hypothesis (pre/post-emphasis pair) — TESTED AND REJECTED.** A high shelf
of −g dB before the waveshaper with the exact complementary +g dB shelf after it
keeps the linear response perfectly flat, but measured on real material it made
the fizz slightly *worse* (nonlinear HF residual −23.4 → −22.8 dB at −5 dB,
−22.4 dB at −8 dB). Reason: the post-shelf re-amplifies the HF intermodulation
products generated from mid-band content, cancelling the benefit of driving the
highs less. It only improved an artificial both-tones-in-the-highs IMD number.

**Measurement note.** Two metrics had to be fixed before any of this could be
trusted: (i) "HF harmonic energy of a tone" is meaningless here — at 48 kHz an
8 kHz tone through an odd-only curve makes no in-band harmonics at all; (ii)
"loudness-match then subtract" charges a candidate for changing tonal balance
rather than for adding junk. Replaced by a **per-bin complex projection**:
H(k)=<Y,X>/<X,X> absorbs every linear difference exactly, so the residual
R = Y − H·X is purely nonlinear. Reported per band as nlHF (8–20 kHz, the fizz)
and nlMID (200–2000 Hz, the wanted warmth).

**Hypothesis adopted (voice iter 01): HF-clean split.** Split the input with the
already-validated LR4 complementary crossover; only the low band enters the
nonlinearity, the high band passes through clean and is scaled by the chain's
small-signal gain so the linear response stays flat. Measured on EDM material:

| variant | nlHF (fizz) | nlMID (warmth) | multitone IMD |
|---|---|---|---|
| A saturn_like | −23.4 | −27.8 | −24.5 |
| B split 8 kHz | −29.4 | −27.4 | −28.0 |
| C split 6 kHz | −33.6 | −27.2 | −29.5 |
| D split 4 kHz | −41.7 | −27.0 | −31.8 |

The fizz drops by 6–18 dB while the mid-band warmth is untouched, and the
straddling tone pair (3 kHz + 3.5 kHz) also improves (−20.2 → −31.8 dB), so the
gain is not an artefact of the test tones sitting above the crossover. Linear
response ripple 0.02 dB (transparent). Reducing drive instead was rejected: it
cuts the fizz only 5.6 dB and costs 5.7 dB of the wanted mid character.

**Status: pending_review** — A/B/C/D rendered for both tracks on EDM / Epic_Drum /
Disco, loudness-matched. improved/regressed to be decided by the listener.

---

## voice_stage `enhanced`, iter 02 — thickness recovery

**Human feedback (2026-08-11)**
> "乾淨程度 B 版就可以，但 B/C/D 雖然變通透了，Tube 的暖度變少了、Saturation 變薄了，
> 共通點是厚度變薄了，希望是介在 A_saturn_like 跟 B_hf8k 之間的聽感。"

Cleanliness target settled at **B (8 kHz)**. Defect: all split variants lost body.

**Measured cause — it is crest factor, not tone.** Loudness-matched crest (dB):

| material | dry | A baseline | B hf8k |
|---|---|---|---|
| EDM | 8.11 | **7.46** | **11.10** |
| Epic_Drum | 14.04 | **10.49** | **13.03** |
| Disco | 9.97 | **8.70** | **12.07** |

A pushes crest *below* dry — that peak compression is what "thick" means here.
B pushes it *above* dry, because HF transients now bypass the curve entirely;
after loudness matching the programme is ~3.6 dB less dense. Mid-band RMS barely
moves (−0.05 dB), so this is density, not tonal balance. The listener's "thinner"
is exactly this number.

**Two levers added, both aimed at density rather than tone**
- `beta` — fraction of the HF band still driven into the nonlinearity
  (0 = fully clean, 1 = the unsplit baseline).
- `follow` — modulates the *clean* HF band by the gain reduction the curve is
  applying to the low band (1 ms attack / 30 ms release, envelope rate so it adds
  no sidebands). Restores the peak compression without generating HF harmonics.

| variant | EDM | Epic | Disco | nlHF |
|---|---|---|---|---|
| A baseline | 7.46 | 10.49 | 8.70 | −20.6 |
| B hf8k | 11.10 | 13.03 | 12.07 | −26.6 |
| follow 1.0 alone | 10.37 | 11.44 | 10.55 | −24.5 |
| beta .35 alone | 9.98 | 11.95 | 11.69 | −28.9 |
| **beta .35 + follow 1.0** | **9.62** | **11.00** | **10.29** | **−25.7** |

The two levers are complementary: together they recover most of the density gap
while giving up only 0.9 dB of the cleanliness B bought.

**Rendered ladder for the listener** (all at fc = 8 kHz, follow = 1.0):
E1 `beta 0.25` (closest to B) / E2 `beta 0.50` / E3 `beta 0.75` (closest to A).
Peaks fall monotonically E1 → E3, confirming the ladder sits between A and B.

**Status: pending_review.**
