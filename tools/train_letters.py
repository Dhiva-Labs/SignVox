#!/usr/bin/env python3
"""Train the Spell-mode letter MLP from Data Lab recordings and/or extracted
public-dataset landmarks.

Input: one or more directories of per-letter CSVs (the PLAN.md §9 Data Lab
export format), each row = 63 floats (21 normalized landmarks x,y,z) + a label
column. Files are typically named "<LABEL>.csv" (A.csv, none.csv) but the label
column is what's actually used — filenames don't matter. `--data-dir` may be
repeated to pool several sources.

Output: a single JSON file (default: letters_weights.json) holding the trained
network's weights in the exact shape lib/engines/mlp_dart.dart expects:
{"labels": [...], "layers": [{"weights": [[out][in]], "biases": [...],
"activation": "relu"|"softmax"}, ...], "featureSet": "raw63"|"v2"}.

Usage:
    # v1-compatible: raw 63 inputs, one source
    python train_letters.py --data-dir ./data --feature-set raw63 --out w.json

    # v1.1: pooled sources, v2 features, held-out cross-dataset eval
    python train_letters.py \
        --data-dir data/landmarks/chaitanyakakade77 \
        --data-dir data/landmarks/dorukdemirci \
        --data-dir data/landmarks/deeppythonist \
        --eval-dir data/landmarks/danrasband_eval \
        --out ../assets/models/letters_weights.json

    # both feature sets on identical splits (PLAN_V2_RECOGNITION.md R2 ablation)
    python train_letters.py ... --ablation

Trains an MLPClassifier (scikit-learn) rather than TensorFlow/Keras — the app's
LetterEngine runs a pure-Dart forward pass (see PLAN.md's P3 gotchas for why:
avoiding another native/tflite dependency after how much native-lib friction P1
already hit), so there's no TFLite export step and no need for TensorFlow's much
heavier install just to train an MLP this size.

Three things this does that the v1.0 version didn't, all from
PLAN_V2_RECOGNITION.md R2:

- **Feature v2** (`tools/letter_features.py`), computed *after* augmentation so
  augments propagate through the features correctly rather than being applied to
  an already-derived vector.
- **A synthetic `none` class** built by interpolating between two different
  letters' landmark vectors at t in [0.3, 0.7]. Those are exactly the
  mid-transition poses that used to be classified as confident garbage letters
  in the middle of a word; teaching the model to call them `none` kills the
  phantom-letter problem at its source. `none` is also oversampled, because a
  missed letter is retryable but a phantom letter corrupts the word.
- **Temperature calibration**, fitted on a held-out val split and then *baked
  into the output layer* (W/T, b/T). softmax(z/T) == softmax((W/T)x + b/T), so
  `mlp_dart.dart` needs no change and the 0.8 commit gate in the decoder finally
  means something.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.neural_network import MLPClassifier
from sklearn.metrics import classification_report, confusion_matrix

sys.path.insert(0, str(Path(__file__).resolve().parent))
from letter_features import features_v2_batch  # noqa: E402

LANDMARK_COLS = [f"lm{i}_{axis}" for i in range(21) for axis in ("x", "y", "z")]
LABEL_COL = "label"
NONE_LABEL = "none"


# --------------------------------------------------------------------------
# data
# --------------------------------------------------------------------------
def load_dataset(data_dirs: list[Path]) -> pd.DataFrame:
    frames = []
    for data_dir in data_dirs:
        csv_files = sorted(data_dir.glob("*.csv"))
        if not csv_files:
            sys.exit(f"No CSV files found in {data_dir}")
        for f in csv_files:
            df = pd.read_csv(f)
            missing = set(LANDMARK_COLS + [LABEL_COL]) - set(df.columns)
            if missing:
                sys.exit(f"{f} is missing columns: {sorted(missing)}")
            df["source"] = data_dir.name
            frames.append(df)
    return pd.concat(frames, ignore_index=True)


def synthesize_none(X: np.ndarray, y: np.ndarray, count: int, rng: np.random.Generator,
                    t_min: float = 0.3, t_max: float = 0.7) -> np.ndarray:
    """Mid-transition poses: linear blends of two *different* letters' landmark
    vectors at t in [0.3, 0.7].

    This is the single cheapest fix for phantom letters. Moving from one
    handshape to the next sweeps the hand through poses that look, to a model
    that has only ever seen clean letters, like a confident third letter — and
    the old decoder happily committed it. Labelling that whole region `none`
    means the decoder simply never sees a candidate there.
    """
    letters = np.unique(y[y != NONE_LABEL])
    by_label = {lab: X[y == lab] for lab in letters}
    out = np.empty((count, X.shape[1]), dtype=np.float32)
    for i in range(count):
        a_lab, b_lab = rng.choice(letters, size=2, replace=False)
        a = by_label[a_lab][rng.integers(len(by_label[a_lab]))]
        b = by_label[b_lab][rng.integers(len(by_label[b_lab]))]
        t = rng.uniform(t_min, t_max)
        out[i] = a * (1.0 - t) + b * t
    return out


def augment(X: np.ndarray, y: np.ndarray, factor: int, rng: np.random.Generator,
            roll_deg: float = 20.0, yaw_deg: float = 20.0, pitch_deg: float = 0.0,
            noise: float = 0.012) -> tuple[np.ndarray, np.ndarray]:
    """Per PLAN.md §6.1: rotation, scale jitter, Gaussian noise, and random
    landmark dropout — cheap invariances real recordings won't fully cover on
    their own (e.g. only a few wrist-rotation angles per session).

    Applied to the *raw 63* so that when v2 features are computed afterwards,
    every derived feature (orientation, canonical shape, distances, curls) sees
    a genuinely rotated/scaled/noised hand rather than a perturbed summary.

    v1.1 adds a **yaw** term (rotation about the vertical axis, mixing x and z)
    on top of the original in-plane roll. Cross-dataset evaluation showed the
    single biggest generalization gap is camera *viewpoint*: the training
    sources are all shot square-on, the held-out source is shot from below and
    off to the side. Yaw is the cheapest stand-in for that, and it is exactly
    the variation a phone held at chest height produces in real use.
    """
    if factor <= 1:
        return X, y

    landmarks = X.reshape(-1, 21, 3)
    out_X, out_y = [landmarks.copy()], [y.copy()]

    for _ in range(factor - 1):
        batch = landmarks.copy()

        # in-plane roll (x,y)
        angles = rng.uniform(-np.radians(roll_deg), np.radians(roll_deg), size=len(batch))
        cos, sin = np.cos(angles), np.sin(angles)
        rot = np.stack([np.stack([cos, -sin], axis=-1), np.stack([sin, cos], axis=-1)], axis=-2)
        batch[:, :, :2] = np.einsum("nij,nkj->nki", rot, batch[:, :, :2])

        # out-of-plane yaw (x,z)
        if yaw_deg > 0:
            yaw = rng.uniform(-np.radians(yaw_deg), np.radians(yaw_deg), size=len(batch))
            cy, sy = np.cos(yaw), np.sin(yaw)
            xz = batch[:, :, [0, 2]]
            rot_y = np.stack([np.stack([cy, -sy], axis=-1), np.stack([sy, cy], axis=-1)], axis=-2)
            batch[:, :, [0, 2]] = np.einsum("nij,nkj->nki", rot_y, xz)

        # out-of-plane pitch (y,z) — v1.2: the held-out source's viewpoint gap is
        # a camera looking *up from below* (phone at chest height, hand above),
        # which yaw cannot express: that tilt mixes y and z, not x and z.
        if pitch_deg > 0:
            pitch = rng.uniform(-np.radians(pitch_deg), np.radians(pitch_deg), size=len(batch))
            cp, sp = np.cos(pitch), np.sin(pitch)
            yz = batch[:, :, [1, 2]]
            rot_x = np.stack([np.stack([cp, -sp], axis=-1), np.stack([sp, cp], axis=-1)], axis=-2)
            batch[:, :, [1, 2]] = np.einsum("nij,nkj->nki", rot_x, yz)

        scale = rng.uniform(0.85, 1.15, size=(len(batch), 1, 1))
        batch *= scale

        batch += rng.normal(0, noise, size=batch.shape)

        dropout_mask = rng.random(size=(len(batch), 21)) < 0.05
        batch[dropout_mask] = 0.0

        out_X.append(batch)
        out_y.append(y.copy())

    return np.concatenate(out_X).reshape(-1, 63).astype(np.float32), np.concatenate(out_y)


def cap_per_source_class(df: pd.DataFrame, cap: int, rng: np.random.Generator) -> pd.DataFrame:
    """Keep at most [cap] rows per (source, label).

    Without this the biggest source drowns out the others — 1 010 rows/letter
    from one signer against ~100 and ~40 from the other two — and the model
    learns that one hand rather than the letter. Balancing costs in-dataset
    accuracy (which was measuring the dominant signer anyway) and buys
    cross-dataset accuracy, which is the metric that predicts real use.
    """
    if cap <= 0:
        return df
    parts = []
    for _, group in df.groupby(["source", LABEL_COL], sort=False):
        if len(group) > cap:
            group = group.iloc[rng.permutation(len(group))[:cap]]
        parts.append(group)
    return pd.concat(parts, ignore_index=True)


def to_features(X63: np.ndarray, feature_set: str) -> np.ndarray:
    if feature_set == "raw63":
        return X63.astype(np.float32)
    if feature_set == "v2":
        return features_v2_batch(X63)
    raise ValueError(feature_set)


# --------------------------------------------------------------------------
# calibration
# --------------------------------------------------------------------------
def logits(model: MLPClassifier, X: np.ndarray) -> np.ndarray:
    """Pre-softmax outputs, recomputed in numpy — sklearn only exposes
    probabilities, and temperature scaling needs the logits."""
    a = X
    n = len(model.coefs_)
    for i, (w, b) in enumerate(zip(model.coefs_, model.intercepts_)):
        a = a @ w + b
        if i < n - 1:
            a = np.maximum(a, 0)  # relu
    return a


def fit_temperature(z: np.ndarray, y_idx: np.ndarray) -> float:
    """Scalar T minimising NLL of softmax(z/T). Grid + local refine — no scipy
    dependency needed for a smooth 1-D problem this small."""

    def nll(t: float) -> float:
        s = z / t
        s = s - s.max(axis=1, keepdims=True)
        log_norm = np.log(np.exp(s).sum(axis=1))
        return float(np.mean(log_norm - s[np.arange(len(y_idx)), y_idx]))

    grid = np.geomspace(0.25, 8.0, 60)
    best = min(grid, key=nll)
    lo, hi = best / 1.3, best * 1.3
    for _ in range(40):  # golden-section
        m1 = lo + 0.382 * (hi - lo)
        m2 = lo + 0.618 * (hi - lo)
        if nll(m1) < nll(m2):
            hi = m2
        else:
            lo = m1
    return float((lo + hi) / 2)


def export_weights_json(model: MLPClassifier, labels: list[str], out_path: Path,
                        feature_set: str, temperature: float, meta: dict) -> None:
    layers = []
    n_layers = len(model.coefs_)
    for i, (coef, intercept) in enumerate(zip(model.coefs_, model.intercepts_)):
        is_output = i == n_layers - 1
        activation = model.out_activation_ if is_output else model.activation
        w, b = coef.T, intercept
        if is_output and temperature and temperature > 0:
            # Bake calibration into the last layer: softmax(z/T) is identical to
            # softmax((W/T)x + b/T), so the Dart forward pass needs no changes.
            w, b = w / temperature, b / temperature
        layers.append(
            {
                # sklearn stores weights as [in, out]; our Dart forward pass
                # wants [out][in] (one row per output neuron) — transpose.
                "weights": [[round(float(v), 6) for v in row] for row in w],
                "biases": [round(float(v), 6) for v in b],
                "activation": activation,
            }
        )
    payload = {
        "labels": labels,
        "layers": layers,
        # Absent == v1/raw-63, so old weight files keep loading unchanged.
        "featureSet": feature_set,
        "temperature": round(float(temperature), 6),
    }
    payload.update(meta)
    out_path.write_text(json.dumps(payload))


# --------------------------------------------------------------------------
# train / evaluate one configuration
# --------------------------------------------------------------------------
def run(feature_set: str, splits: dict, args, rng: np.random.Generator, report_dir: Path):
    X_tr63, y_tr = splits["train"]
    X_va63, y_va = splits["val"]
    X_te63, y_te = splits["test"]

    X_tr63, y_tr = augment(X_tr63, y_tr, args.augment_factor, rng,
                           roll_deg=args.roll_deg, yaw_deg=args.yaw_deg,
                           pitch_deg=args.pitch_deg, noise=args.noise)

    # Oversample `none` after augmentation: a missed letter is retryable, a
    # phantom letter corrupts the word, so recall on `none` is worth more than
    # a little precision elsewhere.
    if args.none_oversample > 1:
        mask = y_tr == NONE_LABEL
        if mask.any():
            reps = args.none_oversample - 1
            X_tr63 = np.concatenate([X_tr63] + [X_tr63[mask]] * reps)
            y_tr = np.concatenate([y_tr] + [y_tr[mask]] * reps)

    X_tr = to_features(X_tr63, feature_set)
    X_va = to_features(X_va63, feature_set)
    X_te = to_features(X_te63, feature_set)

    print(f"\n=== {feature_set}: train {X_tr.shape}, val {X_va.shape}, test {X_te.shape} ===")
    model = MLPClassifier(
        hidden_layer_sizes=tuple(args.hidden),
        activation="relu",
        solver="adam",
        max_iter=args.max_iter,
        early_stopping=True,
        n_iter_no_change=12,
        random_state=args.seed,
    )
    model.fit(X_tr, y_tr)
    labels = list(model.classes_)
    idx_of = {lab: i for i, lab in enumerate(labels)}

    temperature = 1.0
    if args.calibrate:
        z_va = logits(model, X_va)
        temperature = fit_temperature(z_va, np.array([idx_of[v] for v in y_va]))
        print(f"calibration temperature T = {temperature:.4f}")

    results = {"feature_set": feature_set, "temperature": temperature, "labels": labels}

    def evaluate(name: str, X, y_true):
        if X is None or len(X) == 0:
            return None
        y_pred = model.predict(X)
        rep = classification_report(y_true, y_pred, zero_division=0, output_dict=True)
        letters_only = [k for k in rep if len(k) == 1 and k.isalpha()]
        no_jz = [k for k in letters_only if k not in ("J", "Z")]
        acc = float(rep["accuracy"])
        acc_no_jz = float(np.mean([rep[k]["recall"] for k in no_jz])) if no_jz else 0.0
        none_recall = float(rep[NONE_LABEL]["recall"]) if NONE_LABEL in rep else None
        print(f"\n--- {feature_set} / {name} ---")
        print(classification_report(y_true, y_pred, zero_division=0))
        cm_labels = sorted(set(y_true) | set(y_pred))
        cm = confusion_matrix(y_true, y_pred, labels=cm_labels)
        (report_dir / f"confusion_{feature_set}_{name}.txt").write_text(
            "labels: " + ", ".join(cm_labels) + "\n" + str(cm) + "\n\n"
            + classification_report(y_true, y_pred, zero_division=0)
        )
        results[name] = {
            "accuracy": acc,
            "macro_recall_letters_no_jz": acc_no_jz,
            "none_recall": none_recall,
            "n": int(len(y_true)),
        }
        return results[name]

    evaluate("in_dataset_test", X_te, y_te)
    if splits.get("cross") is not None:
        X_cr63, y_cr = splits["cross"]
        evaluate("cross_dataset", to_features(X_cr63, feature_set), y_cr)

    return model, labels, temperature, results


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--data-dir", type=Path, action="append", required=True,
                        help="Directory of per-letter CSVs; repeat to pool sources")
    parser.add_argument("--eval-dir", type=Path, default=None,
                        help="A fully held-out source used only for the cross-dataset metric")
    parser.add_argument("--out", type=Path, default=Path("letters_weights.json"))
    parser.add_argument("--report-dir", type=Path, default=Path("reports"))
    parser.add_argument("--feature-set", choices=("raw63", "v2"), default="v2")
    parser.add_argument("--ablation", action="store_true",
                        help="Train raw63 and v2 on identical splits and ship the winner")
    parser.add_argument("--augment-factor", type=int, default=8, help="1 = no augmentation")
    parser.add_argument("--roll-deg", type=float, default=20.0, help="in-plane rotation jitter")
    parser.add_argument("--yaw-deg", type=float, default=20.0, help="out-of-plane viewpoint jitter")
    parser.add_argument("--pitch-deg", type=float, default=0.0,
                        help="out-of-plane tilt jitter (camera-below viewpoints)")
    parser.add_argument("--noise", type=float, default=0.012, help="per-landmark gaussian sigma")
    parser.add_argument("--cap-per-source-class", type=int, default=0,
                        help="Max rows kept per (source, label) — balances an over-represented source")
    parser.add_argument("--none-multiplier", type=float, default=2.5,
                        help="Synthetic none rows as a multiple of the median letter class size")
    parser.add_argument("--none-t-min", type=float, default=0.3)
    parser.add_argument("--none-t-max", type=float, default=0.7)
    parser.add_argument("--none-oversample", type=int, default=2,
                        help="Extra copies of none rows in the training split")
    parser.add_argument("--hidden", type=int, nargs="+", default=[256, 128])
    parser.add_argument("--max-iter", type=int, default=400)
    parser.add_argument("--no-calibrate", dest="calibrate", action="store_false")
    parser.add_argument("--test-size", type=float, default=0.15)
    parser.add_argument("--val-size", type=float, default=0.15)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    args.report_dir.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(args.seed)

    df = load_dataset(args.data_dir)
    print(f"Loaded {len(df)} rows from {len(args.data_dir)} source(s)")
    df = cap_per_source_class(df, args.cap_per_source_class, rng)
    if args.cap_per_source_class:
        print(f"After per-(source,label) cap of {args.cap_per_source_class}: {len(df)} rows")
    print(df.groupby(["source", LABEL_COL]).size().unstack(fill_value=0).to_string())

    X = df[LANDMARK_COLS].to_numpy(dtype=np.float32)
    y = df[LABEL_COL].to_numpy().astype(str)

    # Synthetic `none` (R1 step 3) — built from the pooled real letters, then
    # split alongside them so val/test contain none rows too.
    if NONE_LABEL not in set(y):
        counts = pd.Series(y).value_counts()
        n_none = int(args.none_multiplier * counts.median())
        print(f"\nSynthesizing {n_none} `none` rows from letter-to-letter transitions")
        X = np.concatenate([X, synthesize_none(X, y, n_none, rng, args.none_t_min, args.none_t_max)])
        y = np.concatenate([y, np.array([NONE_LABEL] * n_none)])

    X_rest, X_te, y_rest, y_te = train_test_split(
        X, y, test_size=args.test_size, random_state=args.seed, stratify=y)
    val_frac = args.val_size / (1.0 - args.test_size)
    X_tr, X_va, y_tr, y_va = train_test_split(
        X_rest, y_rest, test_size=val_frac, random_state=args.seed, stratify=y_rest)

    splits = {"train": (X_tr, y_tr), "val": (X_va, y_va), "test": (X_te, y_te), "cross": None}

    if args.eval_dir:
        cross = load_dataset([args.eval_dir])
        # The held-out source has no `none` of its own; synthesize it there too so
        # none-recall is measured on genuinely unseen transitions.
        Xc = cross[LANDMARK_COLS].to_numpy(dtype=np.float32)
        yc = cross[LABEL_COL].to_numpy().astype(str)
        n_none_c = max(30, int(0.5 * pd.Series(yc).value_counts().median()) * 4)
        Xc = np.concatenate([Xc, synthesize_none(Xc, yc, n_none_c, rng, args.none_t_min, args.none_t_max)])
        yc = np.concatenate([yc, np.array([NONE_LABEL] * n_none_c)])
        splits["cross"] = (Xc, yc)
        print(f"Cross-dataset eval source: {args.eval_dir.name}, {len(yc)} rows "
              f"({n_none_c} synthetic none)")

    configs = ["raw63", "v2"] if args.ablation else [args.feature_set]
    all_results = {}
    trained = {}
    for fs in configs:
        model, labels, temperature, results = run(fs, splits, args, np.random.default_rng(args.seed), args.report_dir)
        trained[fs] = (model, labels, temperature)
        all_results[fs] = results

    def score(fs: str) -> float:
        r = all_results[fs]
        cross = r.get("cross_dataset")
        return cross["accuracy"] if cross else r["in_dataset_test"]["accuracy"]

    winner = max(configs, key=score)
    model, labels, temperature = trained[winner]
    print(f"\n>>> shipping feature set: {winner}")

    export_weights_json(
        model, labels, args.out, winner, temperature if args.calibrate else 0.0,
        meta={
            "trainedOn": [d.name for d in args.data_dir],
            "crossDatasetEval": args.eval_dir.name if args.eval_dir else None,
        },
    )
    (args.report_dir / "metrics.json").write_text(json.dumps(all_results, indent=2))
    print(f"Wrote {args.out} ({args.out.stat().st_size / 1e6:.2f} MB)")
    print(f"Reports in {args.report_dir}")


if __name__ == "__main__":
    main()
