# Canvas review package

> The original ZIP, `manifest.json`, `results/`, and `experiments/` are not kept in this repository. A copy is in the main checkout’s ignored `tmp/pro-follow-up-2026-10-14/`, and the original commit `4cb1dea` on `codex/video-canvas-plan` still contains them. References to `results/` below point to that copy.

A source-grounded review of `byronwall/context-recorder` at `76afc4faa24887408c275360132f0dd03384c94b`, prepared October 14, 2026 (America/Indiana/Indianapolis).

## Start here

- `canvas-review.md`: diagnosis, ten ranked changes, evidence, and canvas interaction proposals.
- `canvas-improvements.json`: exactly ten structured recommendations, VCI-01–VCI-10.
- `codex-next-steps.md`: file-level scope, proposed gates, and macOS command run sheet.
- `canvas-concepts.html`: self-contained light-mode interaction concept using synthetic source images. No server or network needed. This is not the native app.
- `sources.md`: primary sources, reading inventory, exact baseline, and evidence limits.
- `results/`: machine-readable measurements, source verification, assertions, and logs.
- `experiments/`: source-verified upstream excerpts, platform stubs, probes, and the exact synthetic inputs. `run.sh` reproduces the diagnostics using installed tools; it does not install dependencies.
- `manifest.json`: sizes and SHA-256 values for packaged files (excluding itself).

The ZIP excludes compiled build products and Python caches. No fonts, installed dependencies, personal videos, credentials, or repository working tree are included. The four verbatim upstream source files are identified in `results/source-verification.json`; they are source evidence, not authored fixes.

## What was executed

Actual Swift row matching, join verification, change gating, run patch planning, and segmentation ran with Linux raw-array/image-metadata stubs. The four algorithm source copies passed Git blob verification. Thirty-four synthetic pairs, ten sequences totaling 380 frames, and one 20-frame anchor ablation were evaluated. Two sequences passed through FFmpeg H.264 encoding/decoding. Independent OpenCV probes generated local phase-correlation and sparse-flow candidates. All 23 reproduction assertions passed, including assertions that reproduce failures.

## What that does not establish

No real user recording was supplied or fetched. No full macOS app, Apple decoder, Vision estimator, Core Graphics compositor, AVPlayer seek, or SwiftUI interaction was executed. Known-region crops and a known-transient skip are oracle tests, not automatic fixes. Motion candidates are not accepted truthful stitches. Synthetic pass/fail numbers do not estimate field accuracy.

The HTML demonstration has syntax/data checks, not a completed browser or usability test. Its atlas is a Python rendering of the clean Swift patch plan; its viewport positions come from synthetic fixture ground truth. The diagnosis and implementation proposals do not depend on that demonstration being adopted.

## Reproducibility

Exact environment versions and the input corpus are included. Synthetic regeneration uses a local DejaVu Sans font when present and otherwise Pillow's default; different fonts/tool versions can change the stress tests. Do not compare a regenerated corpus to these numbers without recording the environment. To inspect the exact executed inputs, use the included `.gray` arrays (8-bit row-major, dimensions in input JSON), PNG pair previews, and H.264 MP4 controls.

No repository files were edited and no PR was created. All implementation changes remain proposals for Codex review.
