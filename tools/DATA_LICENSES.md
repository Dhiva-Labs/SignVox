# SignVox — training-data licence audit

**Rule being enforced (PLAN_V2_RECOGNITION.md R-3):** every dataset used to
*train* the shipped letter model must carry a licence permitting **commercial
use and redistribution of derived model weights**. Accepted: **CC0, CC BY 4.0,
MIT, Apache-2.0**. Rejected: GPL, non-commercial, no-derivatives, research-only,
competition-use-only, and "© original authors" / unspecified.

This project has been bitten by a licence landmine before (the Piper `lessac`
voice, PLAN.md §2 P4 gotcha), so the audit below records *why* each candidate
was accepted or rejected, not just the licence string.

Two rules beyond the licence string itself, both of which changed decisions here:

- **Share-alike is treated as rejected.** CC BY-SA 4.0 requires adaptations to
  be released under the same terms. Whether trained weights are an "adaptation"
  of a database is legally unsettled; R-3's accept-list does not include it, so
  every CC BY-SA 4.0 candidate below is out. This is a deliberate,
  conservative reading, not an oversight.
- **A permissive licence string on a re-upload does not launder the original.**
  A Kaggle uploader can tick "CC0" on someone else's GPL data. Where a dataset's
  own description admits pooling from unnamed sources, or its layout/filenames
  fingerprint a known restrictively-licensed dataset, it is rejected regardless
  of the stated licence.

Licence strings below were read from Kaggle's own API
(`https://www.kaggle.com/api/v1/datasets/view/<owner>/<slug>`) and HuggingFace's
dataset API on **2026-07-25**, not from the plan's assumptions. Re-verify before
any future retrain — uploaders can change a licence after the fact.

---

## Used for TRAINING

| Source | Licence (verified) | Why it passed | Used for |
|---|---|---|---|
| [`chaitanyakakade77/american-sign-language-dataset`](https://www.kaggle.com/datasets/chaitanyakakade77/american-sign-language-dataset) | **MIT** | Uploader-authored capture set (clean plain-background photos), 26 classes × ~1 000, no re-upload markers. ~100% hand-detection rate. | Train — **26 294 rows** |
| [`dorukdemirci/asl-alphabet-dataset`](https://www.kaggle.com/datasets/dorukdemirci/asl-alphabet-dataset) | **Apache-2.0** | Uploader-authored webcam capture, 24 classes (A–Y, no J/Z) × ~100. Shares a `<LETTER>-samples/` folder convention with `chaitanyakakade77` but the images are demonstrably different (different signer, different room, softer focus — checked by eye and by hash), so it is a genuinely independent second source. | Train — **2 370 rows** |
| [`deeppythonist/american-sign-language-dataset`](https://www.kaggle.com/datasets/deeppythonist/american-sign-language-dataset) | **MIT** | Uploader-authored, 36 classes (a–z + 0–9; digits skipped at extraction), hand-on-black composites. A third signer. Detection rates vary widely by letter (3–99%). | Train — **1 028 rows** |

## Used for EVALUATION ONLY (never trained on)

| Source | Licence (verified) | Why | Used for |
|---|---|---|---|
| [`danrasband/asl-alphabet-test`](https://www.kaggle.com/datasets/danrasband/asl-alphabet-test) | **CC0: Public Domain** | 870 photos shot by the uploader himself as a validation set. Its description references `grassknoted/asl-alphabet` only as the *idea's* origin and for image-size compatibility — the images are his own work, so the CC0 grant is his to give. | **Held-out cross-dataset test set.** Never in any training split. |

## Clean licence, but NOT used (and why)

| Source | Licence | Why not used |
|---|---|---|
| [`borisgraudt/asl-alphabet-hand-landmarks`](https://www.kaggle.com/datasets/borisgraudt/asl-alphabet-hand-landmarks) | CC0 | Licence and provenance are both fine (uploader's own ASL&AI project). Ships raw MediaPipe landmarks but **no handedness label**, which `normalizeHand` needs to mirror left hands into right-hand space. Recoverable by chirality (see `letter_features.chirality`), but the samples are consecutive video frames — 404/class with far fewer distinct poses — so the diversity gain did not justify the extra inference-path assumption. |
| [`sid220/asl-now-fingerspelling`](https://huggingface.co/datasets/sid220/asl-now-fingerspelling) (+ mirror `AxelS27/…`, `thefakeslimshady/…`) | MIT | Same handedness gap; only ~82 samples/letter. Genuinely clean data (DOI 10.57967/hf/1494) — a good candidate if a future retrain adds a validated handedness-recovery step. |
| [`rajchoudharii/american-sign-language-keypoints-dataset`](https://www.kaggle.com/datasets/rajchoudharii/american-sign-language-keypoints-dataset) | MIT | Keypoints are **2D only** (x,y, no z) and pre-normalized with a different scheme. Incompatible with the app's 63-float (x,y,z) feature space. |
| [`bhagyashrizade/american-sign-language`](https://www.kaggle.com/datasets/bhagyashrizade/american-sign-language) | CC0 | Licence and provenance both fine (own webcam capture — filenames are raw unix timestamps). **But the images already have MediaPipe's landmark overlay drawn on them** — red dots, white skeleton, magenta bounding box. Detection rate: 2 / 6 360. |
| [`granthgaurav/asl-mediapipe-converted-dataset`](https://www.kaggle.com/datasets/granthgaurav/asl-mediapipe-converted-dataset) | MIT | Not photographs: green **wireframe renderings** of landmarks on white. Detection rate: 0 / 4 681. |
| [`amitabhabanerjee/training-a-robot-to-understand-sign-language`](https://www.kaggle.com/datasets/amitabhabanerjee/training-a-robot-to-understand-sign-language) | CC0 | Impeccable provenance (uploader's own Anki Vector robot, documented capture script) but the images are 200×200 grayscale extreme close-ups with no wrist or forearm context. Detection rate: 81 / 8 476. |
| [`muhammadkhalid/sign-language-for-alphabets`](https://www.kaggle.com/datasets/muhammadkhalid/sign-language-for-alphabets) | CC0 | 100×100 grayscale thumbnails, poor detection; its `unknown` class is random scenery with no hand in it, so it is useless for the `none` class too. |
| [`madhavanair/american-sign-language-dataset`](https://www.kaggle.com/datasets/madhavanair/american-sign-language-dataset) | CC0 | 140 000 real-hand photos, but the classes are bare numeric folders `0..27` with no published mapping, and the images carry a heavy magenta colour cast (looks like a channel swap). An inferred label mapping risks poisoning entire classes, which is worse than having less data. Not used; revisit only with the mapping validated against a model trained elsewhere. |
| [`computeroid/asl-alphabet-training-set-937-images`](https://www.kaggle.com/datasets/computeroid/asl-alphabet-training-set-937-images) | Apache-2.0 | Classes are bare numeric folders `0..30` with no published label mapping (and the description says it encodes J-start/J-end/Z-start/Z-end), so labels can't be assigned reliably. |
| [`emresulun/sign-language-letter-images`](https://www.kaggle.com/datasets/emresulun/sign-language-letter-images) | CC0 | The uploader states the letters are "not exactly ASL… adapted from ASL". Wrong label semantics. |
| [`ayuraj/asl-dataset`](https://www.kaggle.com/datasets/ayuraj/asl-dataset) | CC0 (claimed) | Filenames (`hand1_0_bot_seg_1_cropped.jpeg`) match the **Massey University Gesture Dataset 2012** naming convention exactly, and the description gives no provenance. Treated as a re-upload of a dataset whose own terms are not CC0. |

## REJECTED

| Source | Stated licence | Reason |
|---|---|---|
| [`lexset/synthetic-asl-alphabet`](https://www.kaggle.com/datasets/lexset/synthetic-asl-alphabet) | **"Data files © Original Authors"** | **PLAN_V2_RECOGNITION.md R1 listed this as "CC BY 4.0" — that is wrong.** Kaggle's API reports no open licence at all; Lexset retains copyright. No grant to redistribute derived weights. Rejected. (This is exactly why R-3 says "verify the licence yourself at download time".) |
| [`grassknoted/asl-alphabet`](https://www.kaggle.com/datasets/grassknoted/asl-alphabet) | GPL-2.0 | Copyleft. Already flagged in the plan. Not used, for training or evaluation. |
| [`debashishsau/aslamerican-sign-language-aplhabet-dataset`](https://www.kaggle.com/datasets/debashishsau/aslamerican-sign-language-aplhabet-dataset) | CC0 (claimed) | Description: *"We would thank every open dataset which helped in pooling a large dataset"* — an admitted pool of unnamed third-party datasets, in the exact 29-class (A–Z + SPACE/DELETE/NOTHING) layout of the GPL-2.0 `grassknoted` set. A downstream CC0 tick cannot re-license upstream GPL images. |
| `avnijaiswal/asl-alphabet-dataset` | CC0 (claimed) | 1.1 GB / 29-class layout — matches `grassknoted`'s fingerprint. Same laundering concern; not downloaded. |
| `buildingabetterworld/asl-hand-landmarks`, `buildingabetterworld/google-asl-hands`, `chichannn/asl-fingerspelling-recognition-tfrecord`, `jobayerhossain/asl-fingerspelling-*`, `sohier/529505295052950` | Apache-2.0 / CC0 (claimed) | All derived from Google's **ASL Fingerspelling / Isolated Sign Language competition** data, which is competition-use-only. R-3 names this class of source explicitly. |
| `ammarsayedtaha/…`, `prathumarikeri/…`, `vignonantoine/mediapipe-processed-asl-dataset`, `siruyyy/asl-hand-landmarks-24-letters-v1-a-y-no-jz`, `iamavinashkr090502/…`, `dwibonbhargabdeka/…`, `muhammadalbrham/…`, `pradeepisawasan/…`, `rabieelkharoua/…`, `ardamavi/sign-language-digits-dataset` | CC BY-SA 4.0 | Share-alike — outside R-3's accept-list (see the note at the top). |
| `kirandevraj/ISL-Fingerspelling`, `achrafothman/aslg_pc12` | CC BY-NC-4.0 | Non-commercial. |
| `Marxulia/asl_sign_languages_alphabets_v0*`, `Katyaaaaae/asl-alphabet`, `Au4Ob10/fingerspelling_imgs`, `nandyc/ASL_Isolated_Swin_dataset`, `SignReader/…` | none stated | No licence = no grant. |

---

## Provenance of the shipped weights

`assets/models/letters_weights.json` (v1.1) is trained **only** on the three
sources in the "Used for TRAINING" table above — `chaitanyakakade77` (MIT),
`dorukdemirci` (Apache-2.0) and `deeppythonist` (MIT), 29 692 landmark rows in
total — plus synthetically-generated `none` transition frames derived from those
same landmarks (`tools/train_letters.py`, `synthesize_none`). No GPL,
non-commercial, research-only or competition data contributed to it, directly or
transitively.

Accuracy is reported against `danrasband` (CC0), held out entirely: it appears in
no training split, and its rows are loaded only through `--eval-dir`.

Reproduce with the exact command in `tools/README.md` § Train. Re-verify every
licence in this file first — uploaders can change a licence after the fact.

`README.md` carries the user-facing short version of this.
