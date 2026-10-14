# Engine bake-off (M2)

Run on 2026-10-14. Each engine estimated the scroll between consecutive frames of the synthetic fixture clips, using pairs where the true shift is known, nonzero, under 60% of the view, and on the same page state: 295 pairs. The repeated-rows and blank clips were scored separately for ambiguity.

| Engine | Exact (≤ 1 px) | Worst miss | Time per pair | Ambiguity signal | Dependency |
| --- | --- | --- | --- | --- | --- |
| Row profile (Swift, `RowProfileEstimator`) | 100% | 0 px | 3.9 ms | Runner-up cost: wrong estimates had a runner-up within 0.05 of the best; correct ones had a margin of 0.29 or more | None |
| Apple Vision (`VNTranslationalImageRegistrationRequest`) | 99.7% | 416 px | 6.0 ms | None | System framework |
| OpenCV phase correlation (`cv2.phaseCorrelate`, 4.12) | 100% | 0 px | 25 ms | Peak response fell to 0.13–0.35 on ambiguous pairs; not calibrated | About 50 MB Python wheel plus NumPy |

**Decision:** keep the row-profile estimator. It matches OpenCV's accuracy, runs about 6× faster, gives a usable ambiguity signal, and adds no dependency. Vision and OpenCV are dropped. Every estimate, whichever engine produced it, still has to pass an independent pixel check (`Joiner`).

Reproduce:

```bash
swift run -c release canvas-tool bakeoff
uv run docs/intent/video-to-canvas/spikes/opencv_bakeoff.py tmp/canvas-fixtures
```

## Real footage

Real recordings needed three changes the fixtures didn't show:

- **Sub-pixel scrolling.** Recordings are scaled down from Retina, so a scroll can land between rows. A pixel now matches when it lies between its two neighboring source rows.
- **Sticky sidebars inside the content box.** Strips at the left or right edge that stay in place (allowing a table of contents to highlight the current section) are left out of matching, and the column is cropped to the part that scrolls.
- **Residual limit.** Raised from 0.4% to 0.8% for pointer and hover effects.

On the 97 s docs walkthrough, this produced 20 columns (the tallest is 8,867 px) and 17 cards, in 4.7 s. A 224 s session took 5.1 s.
