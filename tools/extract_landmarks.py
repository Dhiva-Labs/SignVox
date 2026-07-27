#!/usr/bin/env python3
"""Turn a folder of labelled hand images into Data Lab-format landmark CSVs.

Dev-machine only. Nothing here ships in the app.

Why this exists (PLAN_V2_RECOGNITION.md R1): the v1.0 letter model was trained
on placeholder data recorded off an emulator webcam and had never seen a real
signing hand. This script feeds real, permissively-licensed public-dataset
images through **the repo's own `hand_landmarker.task`** and the exact same
normalization the app applies at runtime, so public data and user-recorded Data
Lab data land in one identical CSV format (`lm0_x..lm20_z,label`) forever.

Two parity details that matter more than they look (get either wrong and the
model trains on a different distribution than it sees on device):

1. **Every input image is mirrored horizontally before detection.** The app
   feeds MediaPipe a selfie-mirrored bitmap (CameraEngine) and takes MediaPipe's
   raw handedness label as the user's true hand. Public datasets are ordinary
   non-mirrored photos, where MediaPipe's handedness means the opposite. Flipping
   the image reproduces the app's bitmap exactly, so both the coordinates and the
   handedness label carry the same meaning as at runtime.
2. **`score` is the handedness category score**, which is what `MainActivity`
   puts in the `score` field the Dart side gates on — so filtering here on the
   same number filters the same way the app does.

Usage:
    python extract_landmarks.py --source chaitanyakakade77 \
        --input data/raw/<dir> --layout dir --strip-suffix -samples \
        --out data/landmarks --max-per-class 1500

Output: data/landmarks/<source>/<LABEL>.csv plus <source>/_stats.json with
per-class detection-success rates (10-30% loss on some classes is normal —
cropped/blurred images simply have no detectable hand).
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from collections import defaultdict
from multiprocessing import Pool
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from letter_features import normalize_hand  # noqa: E402

MODEL_PATH = Path(__file__).resolve().parent.parent / "assets" / "models" / "hand_landmarker.task"
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
COLUMNS = [f"lm{i}_{a}" for i in range(21) for a in ("x", "y", "z")] + ["label"]
MIN_SCORE = 0.6

_landmarker = None


def _get_landmarker():
    """One HandLandmarker per worker process (they are not fork-safe)."""
    global _landmarker
    if _landmarker is None:
        from mediapipe.tasks import python as mp_python
        from mediapipe.tasks.python import vision

        base = mp_python.BaseOptions(model_asset_path=str(MODEL_PATH))
        opts = vision.HandLandmarkerOptions(
            base_options=base,
            running_mode=vision.RunningMode.IMAGE,
            num_hands=2,
            # Same thresholds as LandmarkerEngine.kt.
            min_hand_detection_confidence=0.5,
            min_hand_presence_confidence=0.5,
            min_tracking_confidence=0.5,
        )
        _landmarker = vision.HandLandmarker.create_from_options(opts)
    return _landmarker


def detect_one(path_and_label):
    """Returns (label, normalized63 or None, score). Runs in a worker process."""
    path, label = path_and_label
    try:
        import mediapipe as mp
        from PIL import Image

        with Image.open(path) as im:
            im = im.convert("RGB").transpose(Image.FLIP_LEFT_RIGHT)  # parity detail 1
            arr = np.asarray(im, dtype=np.uint8)

        result = _get_landmarker().detect(mp.Image(image_format=mp.ImageFormat.SRGB, data=arr))
        if not result.hand_landmarks:
            return label, None, 0.0

        best_i, best_score = 0, -1.0
        for i, cats in enumerate(result.handedness):
            s = cats[0].score if cats else 0.0
            if s > best_score:
                best_i, best_score = i, s
        if best_score < MIN_SCORE:
            return label, None, float(best_score)

        lms = result.hand_landmarks[best_i]
        pts = np.array([[lm.x, lm.y, lm.z] for lm in lms], dtype=np.float64)
        is_left = result.handedness[best_i][0].category_name == "Left"
        return label, normalize_hand(pts, is_left), float(best_score)
    except Exception as exc:  # noqa: BLE001 — one bad image must not kill the run
        print(f"  ! {path}: {exc}", file=sys.stderr)
        return label, None, 0.0


def collect_files(root: Path, layout: str, strip_suffix: str, label_map: dict, skip_dirs: set) -> dict:
    """-> {LABEL: [paths]}"""
    by_label = defaultdict(list)
    for path in sorted(root.rglob("*")):
        if path.suffix.lower() not in IMAGE_EXTS or not path.is_file():
            continue
        if path.name.startswith("._"):  # macOS AppleDouble junk
            continue
        if any(part in skip_dirs for part in path.parts):
            continue
        if layout == "dir":
            raw = path.parent.name
        elif layout == "prefix":
            raw = path.stem.split("_")[0]
        else:
            raise ValueError(f"unknown layout {layout}")
        if strip_suffix and raw.endswith(strip_suffix):
            raw = raw[: -len(strip_suffix)]
        label = label_map.get(raw.lower(), raw.upper())
        if label == "SKIP":
            continue
        by_label[label].append(path)
    return by_label


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--source", required=True, help="Short name; becomes the output subfolder")
    ap.add_argument("--input", type=Path, required=True)
    ap.add_argument("--out", type=Path, default=Path("data/landmarks"))
    ap.add_argument("--layout", choices=("dir", "prefix"), default="dir")
    ap.add_argument("--strip-suffix", default="")
    ap.add_argument("--label-map", default="", help='e.g. "background=none,nothing=none,del=SKIP"')
    ap.add_argument("--skip-dirs", default="", help="comma-separated directory names to ignore")
    ap.add_argument("--max-per-class", type=int, default=1500)
    ap.add_argument("--workers", type=int, default=max(1, (os.cpu_count() or 4) - 1))
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--resume", action="store_true", help="Skip labels whose CSV already exists")
    args = ap.parse_args()

    label_map = {}
    for pair in filter(None, args.label_map.split(",")):
        k, v = pair.split("=", 1)
        label_map[k.strip().lower()] = v.strip()
    skip_dirs = {d.strip() for d in args.skip_dirs.split(",") if d.strip()}

    out_dir = args.out / args.source
    out_dir.mkdir(parents=True, exist_ok=True)

    by_label = collect_files(args.input, args.layout, args.strip_suffix, label_map, skip_dirs)
    if not by_label:
        sys.exit(f"No images found under {args.input}")

    rng = np.random.default_rng(args.seed)
    jobs = []
    for label, paths in sorted(by_label.items()):
        if args.resume and (out_dir / f"{label}.csv").exists():
            print(f"{label}: already extracted, skipping")
            continue
        if len(paths) > args.max_per_class:
            idx = rng.choice(len(paths), size=args.max_per_class, replace=False)
            paths = [paths[i] for i in sorted(idx)]
        jobs.extend((p, label) for p in paths)

    if not jobs:
        print("Nothing to do (all labels already extracted).")
        return

    print(f"{args.source}: {len(jobs)} images across {len(by_label)} labels, {args.workers} workers")

    rows = defaultdict(list)
    attempted = defaultdict(int)
    with Pool(args.workers) as pool:
        for n, (label, vec, _score) in enumerate(pool.imap_unordered(detect_one, jobs, chunksize=16), 1):
            attempted[label] += 1
            if vec is not None:
                rows[label].append(vec)
            if n % 500 == 0:
                print(f"  {n}/{len(jobs)} processed", flush=True)

    stats = {}
    for label in sorted(attempted):
        got, tried = len(rows[label]), attempted[label]
        stats[label] = {"attempted": tried, "detected": got, "rate": round(got / tried, 3) if tried else 0.0}
        print(f"  {label:8s} {got:5d}/{tried:5d}  ({stats[label]['rate']:.0%})")
        if got:
            arr = np.asarray(rows[label], dtype=np.float32)
            with (out_dir / f"{label}.csv").open("w") as f:
                f.write(",".join(COLUMNS) + "\n")
                for r in arr:
                    f.write(",".join(f"{v:.6g}" for v in r) + f",{label}\n")

    stats_path = out_dir / "_stats.json"
    existing = json.loads(stats_path.read_text()) if stats_path.exists() else {}
    existing.update(stats)
    stats_path.write_text(json.dumps(existing, indent=2))
    total = sum(len(v) for v in rows.values())
    print(f"\nWrote {total} rows to {out_dir}")


if __name__ == "__main__":
    main()
