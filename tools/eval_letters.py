#!/usr/bin/env python3
"""Evaluate an already-trained letters_weights.json against a directory of
CSVs, without retraining. Useful after recording more samples for a
specific letter that underperformed (PLAN.md §9 point 4) — check whether
it's improved before deciding to retrain the whole model.

Usage:
    python eval_letters.py --weights ../assets/models/letters_weights.json --data-dir /path/to/csvs
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.metrics import classification_report, confusion_matrix

LANDMARK_COLS = [f"lm{i}_{axis}" for i in range(21) for axis in ("x", "y", "z")]
LABEL_COL = "label"


def forward(x: np.ndarray, layers: list[dict]) -> np.ndarray:
    """Mirrors lib/engines/mlp_dart.dart's forward pass exactly, so a
    passing eval here means the same math the app runs."""
    for layer in layers:
        weights = np.array(layer["weights"])  # [out, in]
        biases = np.array(layer["biases"])
        x = x @ weights.T + biases
        if layer["activation"] == "relu":
            x = np.maximum(x, 0)
        elif layer["activation"] == "softmax":
            x = x - x.max(axis=1, keepdims=True)
            e = np.exp(x)
            x = e / e.sum(axis=1, keepdims=True)
        elif layer["activation"] != "none":
            raise ValueError(f"Unknown activation: {layer['activation']}")
    return x


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--weights", type=Path, required=True)
    parser.add_argument("--data-dir", type=Path, required=True)
    args = parser.parse_args()

    model = json.loads(args.weights.read_text())
    labels = model["labels"]

    csv_files = sorted(args.data_dir.glob("*.csv"))
    df = pd.concat([pd.read_csv(f) for f in csv_files], ignore_index=True)
    X = df[LANDMARK_COLS].to_numpy(dtype=np.float32)
    y_true = df[LABEL_COL].to_numpy()

    probs = forward(X, model["layers"])
    y_pred = [labels[i] for i in probs.argmax(axis=1)]

    print(f"Evaluated {len(df)} rows from {args.data_dir}\n")
    print(classification_report(y_true, y_pred, zero_division=0))
    cm_labels = sorted(set(y_true) | set(y_pred))
    print("labels:", cm_labels)
    print(confusion_matrix(y_true, y_pred, labels=cm_labels))


if __name__ == "__main__":
    main()
