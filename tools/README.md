# SignVox training tools

Dev-machine only — nothing here ships in the app or touches a network at
runtime. Trains the Spell-mode letter MLP from Data Lab recordings.

## Setup

```bash
cd tools
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
```

(If your system is missing the `venv`/`pip` modules — e.g. a minimal
Debian/Ubuntu install without `python3-venv` — and you have
[`uv`](https://github.com/astral-sh/uv) available instead:
`uv venv .venv && uv pip install --python .venv/bin/python -r requirements.txt`.)

## Extract landmarks from an image dataset (v1.1)

`extract_landmarks.py` turns a folder of labelled hand *images* into the same
per-letter CSVs the Data Lab produces, so public data and user recordings share
one code path. Read `DATA_LICENSES.md` before adding a source — the licence gate
is a hard requirement, not a formality.

```bash
python extract_landmarks.py --source <name> --input <dir> \
    --layout dir|prefix [--strip-suffix=-samples] \
    [--label-map "background=none,del=SKIP"] [--skip-dirs <names>] \
    --max-per-class 1500 --workers 10 [--resume]
```

- `--layout dir` reads the label from the parent folder; `--layout prefix` from
  the filename up to the first `_`.
- Note the `=` in `--strip-suffix=-samples`: a bare `-samples` looks like a flag
  to argparse.
- Output: `data/landmarks/<source>/<LABEL>.csv` plus `_stats.json` with
  per-class detection rates.

**Look at the images first.** Four permissively-licensed "ASL alphabet" datasets
turned out to be landmark overlays, wireframe renders, or extreme close-ups and
produced ~0% detection. A quick montage of 4 images per source costs 30 seconds
and saves an extraction run.

## Train

1. Record the alphabet via the app's Data Lab screen (exports land in
   `Documents/SignVox/datalab/` on the device — `adb pull
   /sdcard/Documents/SignVox/datalab ./data`), and/or extract public-dataset
   landmarks as above.
2. Run:
   ```bash
   python train_letters.py \
       --data-dir data/landmarks/chaitanyakakade77 \
       --data-dir data/landmarks/dorukdemirci \
       --data-dir data/landmarks/deeppythonist \
       --eval-dir data/landmarks/danrasband_eval \
       --ablation --none-multiplier 1.0 --none-oversample 1 \
       --out ../assets/models/letters_weights.json --report-dir reports/final
   ```
3. Read the printed classification report / confusion matrix (also written to
   `--report-dir`). Letters that confuse easily (M/N/S/T/E — the fist family;
   U/V/R) may need another recording round. Target ≥95% held-out accuracy per
   PLAN.md §13 — but treat the **cross-dataset** number from `--eval-dir` as the
   real one; in-dataset accuracy mostly measures how well the model memorised
   the dominant source's signer.
4. Re-run the app — `LetterEngine` loads the JSON directly, no rebuild step
   needed beyond a hot restart (Flutter picks up changed assets on restart).

### Flags worth knowing

| Flag | What it does |
|---|---|
| `--data-dir` (repeatable) | Pool several sources into one training set |
| `--eval-dir` | A source held out entirely, used only for the cross-dataset metric |
| `--feature-set raw63\|v2` | v1 raw landmarks vs the v1.1 135-dim feature vector (default `v2`) |
| `--ablation` | Train both on identical splits and ship whichever wins on cross-dataset |
| `--none-multiplier` | Synthetic `none` rows as a multiple of the median letter class |
| `--none-t-min/--none-t-max` | Interpolation range for those synthetic transition poses |
| `--roll-deg`, `--yaw-deg`, `--pitch-deg`, `--noise` | Augmentation strength; **yaw was the single biggest cross-dataset win**; pitch (v1.2) is available but did not beat the shipped config on the current held-out source — see reports/sweep_* |
| `--cap-per-source-class` | Cap rows per (source, label) — measured as a net *loss* here, kept for future imbalanced pools |
| `--no-calibrate` | Skip temperature scaling (it is baked into the exported output layer) |

## Train/serve parity — do not skip this

`tools/letter_features.py` and `lib/engines/letter_features.dart` must compute
identical features. After changing either, regenerate the fixtures and run the
Dart test:

```bash
python make_fixtures.py            # writes ../test/fixtures/letter_features_v2.json
cd .. && flutter test test/letter_features_test.dart
```

Skew here does not throw, does not fail training, and does not show up in any
offline metric — it just makes the app quietly wrong on device.

## Re-evaluate without retraining

After recording more samples for a specific weak letter:

```bash
python eval_letters.py --weights ../assets/models/letters_weights.json --data-dir ./data/retake
```

## Why scikit-learn, not TensorFlow/Keras

`LetterEngine` runs a pure-Dart forward pass on-device (see
`lib/engines/mlp_dart.dart` and PLAN.md's P3 gotchas) rather than
`tflite_flutter` — P1 already spent real time on native-dependency friction
(ABI gaps, R8 breakage) that a network this size (63→128→64→27) doesn't need
to risk again. That means there's no `.tflite` export step, and no need for
TensorFlow's much heavier install just to train a small MLP —
`sklearn.neural_network.MLPClassifier` is enough, and `train_letters.py`
exports its weights directly to the JSON format `mlp_dart.dart` expects.
