# /// script
# requires-python = ">=3.11"
# dependencies = ["opencv-python-headless==4.12.0.88", "numpy"]
# ///
"""M2 engine bake-off, OpenCV side: phase correlation on the same fixture frame pairs as
`canvas-tool bakeoff` (consecutive frames, same page state, true shift in range).

    uv run docs/intent/video-to-canvas/spikes/opencv_bakeoff.py tmp/canvas-fixtures
"""
import json
import sys
import time
from pathlib import Path

import cv2
import numpy as np

root = Path(sys.argv[1] if len(sys.argv) > 1 else "tmp/canvas-fixtures")
errors, seconds, amb = [], 0.0, []
for clip in sorted(p for p in root.iterdir() if (p / "truth.json").exists()):
    truth = json.loads((clip / "truth.json").read_text())
    b = truth["box"]
    rows = (truth["header"], b["height"])
    cap = cv2.VideoCapture(str(clip / "recording.mp4"))
    prev, i = None, -1
    while True:
        ok, frame = cap.read()
        if not ok:
            break
        i += 1
        gray = cv2.cvtColor(frame[b["y"]:b["y"] + b["height"], b["x"]:b["x"] + b["width"]], cv2.COLOR_BGR2GRAY)
        cur = gray[rows[0]:rows[1]].astype(np.float32)
        if prev is not None:
            d = truth["scrollY"][i] - truth["scrollY"][i - 1]
            if d != 0 and abs(d) < (rows[1] - rows[0]) * 6 // 10 and truth["pages"][i] == truth["pages"][i - 1]:
                win = cv2.createHanningWindow(cur.shape[::-1], cv2.CV_32F)
                t0 = time.perf_counter()
                (dx, dy), response = cv2.phaseCorrelate(prev, cur, win)
                seconds += time.perf_counter() - t0
                # phaseCorrelate reports how far cur moved relative to prev; content moving up is negative.
                err = abs(round(-dy) - d)
                if clip.name in ("repeated", "blank"):
                    amb.append(f"{clip.name} f{i} true {d} est {round(-dy)} err {err} response {response:.2f}")
                else:
                    errors.append(err)
        prev = cur
errors.sort()
n = len(errors)
print(f"opencv-phase  pairs {n}  exact<=1px {100 * sum(e <= 1 for e in errors) / n:.1f}%  "
      f"p95 {errors[min(n - 1, int(n * 0.95))]}  max {errors[-1]}  ms/pair {seconds * 1000 / n:.2f}")
print("ambiguous clips:")
for line in amb:
    print("  " + line)
