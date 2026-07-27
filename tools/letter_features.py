#!/usr/bin/env python3
"""Feature extraction for the Spell-mode letter model — the Python half of a
train/serve pair (PLAN_V2_RECOGNITION.md R-5).

Every function here has a byte-for-byte counterpart in Dart:

    normalize_hand()  <->  lib/core/normalize.dart      normalizeHand()
    features_v2()     <->  lib/engines/letter_features.dart  featuresV2()

`tools/make_fixtures.py` writes `test/fixtures/letter_features_v2.json` from
this module and `test/letter_features_test.dart` asserts the Dart side matches
within 1e-4. If you change the maths here, regenerate the fixtures and let the
Dart test tell you whether the two halves still agree — silent train/serve skew
is the classic way a landmark model looks great offline and fails on device.

Feature layout (v2), 135 dims total, in this exact order:

      0.. 62  normalized 63 (wrist-relative, scale-normalized, handedness-
              canonicalized) with **z damped x0.5** — MediaPipe's z is noisy,
              and every later block is computed from this damped copy so the
              whole vector has one consistent representation.
     63.. 64  sin, cos of the in-plane angle of wrist->middle-MCP
     65.. 67  palm-normal unit vector, (indexMCP-wrist) x (pinkyMCP-wrist)
     68..109  rotation-canonicalized xy of all 21 points (wrist->middle-MCP
              rotated onto +y) — pure shape, orientation removed
    110..119  10 pairwise fingertip distances (tips 4,8,12,16,20)
    120..124  5 fingertip->wrist distances
    125..134  cos of the flexion angle at each finger's PIP and DIP joints

Orientation is deliberately kept as *explicit separate features* (63..67)
alongside the rotation-canonicalized shape (68..109) rather than being thrown
away: ASL distinguishes G/Q, K/P and H/U by global hand orientation, so a
fully rotation-invariant representation would make those pairs unlearnable.
"""
from __future__ import annotations

import math

import numpy as np

FEATURE_DIM_V2 = 135
RAW_DIM = 63

# Landmark indices (MediaPipe hand topology).
WRIST = 0
INDEX_MCP = 5
MIDDLE_MCP = 9
PINKY_MCP = 17
FINGERTIPS = (4, 8, 12, 16, 20)

# (previous, joint, next) triples for the two flexion angles per finger.
CURL_JOINTS = (
    (1, 2, 3), (2, 3, 4),        # thumb MCP, IP
    (5, 6, 7), (6, 7, 8),        # index PIP, DIP
    (9, 10, 11), (10, 11, 12),   # middle PIP, DIP
    (13, 14, 15), (14, 15, 16),  # ring PIP, DIP
    (17, 18, 19), (18, 19, 20),  # pinky PIP, DIP
)

Z_DAMPING = 0.5
_EPS = 1e-6


def hand_scale(points: np.ndarray) -> float:
    """Wrist -> middle-MCP distance, the scale normalizer (Dart: _handScale)."""
    d = points[MIDDLE_MCP] - points[WRIST]
    scale = float(math.sqrt(float(d[0]) * float(d[0]) + float(d[1]) * float(d[1]) + float(d[2]) * float(d[2])))
    return scale if scale > _EPS else 1.0


def normalize_hand(landmarks, is_left: bool) -> np.ndarray:
    """Port of Dart `normalizeHand` (lib/core/normalize.dart).

    [landmarks] is 21x3 (or a flat 63) of raw MediaPipe image-space landmarks.
    Returns 63 float32: wrist-translated, divided by the wrist->middle-MCP
    distance, with a left hand's x mirrored into right-hand space.
    """
    pts = np.asarray(landmarks, dtype=np.float64).reshape(21, 3)
    wrist = pts[WRIST]
    scale = hand_scale(pts)
    mirror = -1.0 if is_left else 1.0

    out = (pts - wrist) / scale
    out[:, 0] *= mirror
    return out.reshape(63).astype(np.float32)


def _unit(v: np.ndarray) -> np.ndarray:
    n = float(np.linalg.norm(v))
    return v / n if n > _EPS else np.zeros(3)


def features_v2(normalized63) -> np.ndarray:
    """Port of Dart `featuresV2`. Input: the normalized 63. Output: 135 floats."""
    p = np.asarray(normalized63, dtype=np.float64).reshape(21, 3).copy()
    p[:, 2] *= Z_DAMPING

    out = np.zeros(FEATURE_DIM_V2, dtype=np.float64)
    out[0:63] = p.reshape(63)

    # --- orientation, explicit ------------------------------------------
    v = p[MIDDLE_MCP] - p[WRIST]
    vlen = float(math.sqrt(float(v[0]) * float(v[0]) + float(v[1]) * float(v[1])))
    if vlen > _EPS:
        cos_t, sin_t = float(v[0]) / vlen, float(v[1]) / vlen
    else:
        cos_t, sin_t = 1.0, 0.0
    out[63] = sin_t
    out[64] = cos_t

    normal = _unit(np.cross(p[INDEX_MCP] - p[WRIST], p[PINKY_MCP] - p[WRIST]))
    out[65:68] = normal

    # --- rotation-canonicalized shape (wrist->middle-MCP onto +y) --------
    # Rotating by -phi where cos(phi)=vy/|v|, sin(phi)=vx/|v| maps v to (0,|v|).
    if vlen > _EPS:
        c, s = float(v[1]) / vlen, float(v[0]) / vlen
    else:
        c, s = 1.0, 0.0
    xs = p[:, 0] - p[WRIST, 0]
    ys = p[:, 1] - p[WRIST, 1]
    out[68:110:2] = xs * c - ys * s
    out[69:110:2] = xs * s + ys * c

    # --- distances -------------------------------------------------------
    idx = 110
    for i in range(len(FINGERTIPS)):
        for j in range(i + 1, len(FINGERTIPS)):
            out[idx] = float(np.linalg.norm(p[FINGERTIPS[i]] - p[FINGERTIPS[j]]))
            idx += 1
    for tip in FINGERTIPS:
        out[idx] = float(np.linalg.norm(p[tip] - p[WRIST]))
        idx += 1

    # --- curl angles -----------------------------------------------------
    for (a, b, cj) in CURL_JOINTS:
        u = p[a] - p[b]
        w = p[cj] - p[b]
        nu, nw = float(np.linalg.norm(u)), float(np.linalg.norm(w))
        out[idx] = float(np.dot(u, w)) / (nu * nw) if nu > _EPS and nw > _EPS else 0.0
        idx += 1

    assert idx == FEATURE_DIM_V2, idx
    return out.astype(np.float32)


def features_v2_batch(normalized: np.ndarray) -> np.ndarray:
    """Vectorized-enough wrapper: (n, 63) -> (n, 135)."""
    normalized = np.asarray(normalized, dtype=np.float64)
    out = np.empty((len(normalized), FEATURE_DIM_V2), dtype=np.float32)
    for i in range(len(normalized)):
        out[i] = features_v2(normalized[i])
    return out


def chirality(normalized63) -> float:
    """Signed in-plane palm area of a *normalized* hand.

    After `normalize_hand`, every hand lives in right-hand space, so this sign
    is near-constant across a correctly-labelled dataset. It is what lets
    landmark-only datasets that ship no handedness label be checked (and, if
    they disagree, mirrored) instead of silently poisoning the training set.
    """
    p = np.asarray(normalized63, dtype=np.float64).reshape(21, 3)
    a = p[INDEX_MCP] - p[WRIST]
    b = p[PINKY_MCP] - p[WRIST]
    return float(a[0] * b[1] - a[1] * b[0])
