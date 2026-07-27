#!/usr/bin/env python3
"""Write the train/serve parity fixtures (PLAN_V2_RECOGNITION.md R-5).

Generates `test/fixtures/letter_features_v2.json` from `tools/letter_features.py`
— the *training* implementation — so `test/letter_features_test.dart` can assert
the *inference* implementation (`lib/core/normalize.dart` +
`lib/engines/letter_features.dart`) produces the same numbers within 1e-4.

Cases cover the ordinary path plus the branches that are easy to get subtly
wrong on one side only: left-hand mirroring, a degenerate zero-scale hand, a
hand whose wrist->middle-MCP vector is purely vertical (rotation
canonicalization edge case), and real MediaPipe landmarks pulled from the
extracted dataset when it is present.

    python make_fixtures.py [--real-csv data/landmarks/<source>/A.csv]
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np

from letter_features import features_v2, normalize_hand

OUT = Path(__file__).resolve().parent.parent / "test" / "fixtures" / "letter_features_v2.json"


def synthetic_hand(rng: np.random.Generator) -> np.ndarray:
    """A plausible MediaPipe-shaped hand: 21 points in [0,1] image space with a
    small z, laid out so the wrist->middle-MCP scale is non-degenerate."""
    base = rng.uniform(0.25, 0.75, size=(21, 2))
    base[0] = [0.5, 0.8]  # wrist low in frame
    base[9] = [0.5 + rng.uniform(-0.08, 0.08), 0.55]  # middle MCP above it
    z = rng.normal(0, 0.02, size=(21, 1))
    z[0] = 0.0
    return np.hstack([base, z])


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--real-csv", type=Path, default=None,
                    help="Optional CSV of already-normalized 63-vectors to add as feature-only cases")
    args = ap.parse_args()

    rng = np.random.default_rng(20260725)
    cases = []

    for i in range(6):
        pts = synthetic_hand(rng)
        is_left = i % 2 == 1
        norm = normalize_hand(pts, is_left)
        cases.append(
            {
                "name": f"synthetic_{i}_{'left' if is_left else 'right'}",
                "raw": [round(float(v), 9) for v in pts.reshape(-1)],
                "isLeft": is_left,
                "normalized": [round(float(v), 9) for v in norm],
                "features": [round(float(v), 9) for v in features_v2(norm)],
            }
        )

    # Degenerate: every landmark on the wrist -> hand scale falls back to 1.0
    # and both the orientation angle and the palm normal hit their zero guards.
    degenerate = np.zeros((21, 3))
    degenerate[:] = [0.4, 0.4, 0.0]
    norm = normalize_hand(degenerate, False)
    cases.append(
        {
            "name": "degenerate_zero_scale",
            "raw": [round(float(v), 9) for v in degenerate.reshape(-1)],
            "isLeft": False,
            "normalized": [round(float(v), 9) for v in norm],
            "features": [round(float(v), 9) for v in features_v2(norm)],
        }
    )

    # Purely vertical wrist->middle-MCP: rotation canonicalization is the
    # identity here, which is exactly when an off-by-one in the sin/cos pair
    # stays invisible in the other cases.
    vertical = synthetic_hand(rng)
    vertical[0] = [0.5, 0.8, 0.0]
    vertical[9] = [0.5, 0.5, 0.0]
    norm = normalize_hand(vertical, False)
    cases.append(
        {
            "name": "vertical_axis",
            "raw": [round(float(v), 9) for v in vertical.reshape(-1)],
            "isLeft": False,
            "normalized": [round(float(v), 9) for v in norm],
            "features": [round(float(v), 9) for v in features_v2(norm)],
        }
    )

    if args.real_csv and args.real_csv.exists():
        import pandas as pd

        df = pd.read_csv(args.real_csv).head(4)
        cols = [f"lm{i}_{a}" for i in range(21) for a in ("x", "y", "z")]
        for i, row in enumerate(df[cols].to_numpy(dtype=np.float64)):
            cases.append(
                {
                    "name": f"real_{args.real_csv.parent.name}_{args.real_csv.stem}_{i}",
                    "raw": None,  # already normalized; features-only case
                    "isLeft": None,
                    "normalized": [round(float(v), 9) for v in row],
                    "features": [round(float(v), 9) for v in features_v2(row)],
                }
            )

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(
        json.dumps(
            {
                "featureSet": "v2",
                "featureDim": len(cases[0]["features"]),
                "generatedBy": "tools/make_fixtures.py",
                "cases": cases,
            },
            indent=1,
        )
    )
    print(f"Wrote {len(cases)} cases to {OUT}")


if __name__ == "__main__":
    main()
