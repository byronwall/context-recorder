# Video to canvas: proposed proof

Status: unrun. This is the next-work plan, not completed product validation.

The [design](design.md) proposes automatic scroll reconstruction with links to the original video.
The smallest useful proof contains a tall page, one changed state, and one refused join.
Use ordinary video and a change-selected storyboard as comparisons.

## 1. Establish the source mapping

Use a disposable copy of a selected local session.
Record its video hash, dimensions, frame times, time base, and media-time origin.
Keep decoded frame identity separate from the requested sampling interval.
Check the translation direction, crop bounds, and inverse mapping with known points.

Check irregular frame gaps, the first frame, and the last frame.
A canvas click must display the frame that supplied that patch.
Setting a player's requested time alone does not prove that the correct frame appeared.

FFmpeg's `showinfo` exposes frame numbers, presentation times, and dimensions.
Validate the extraction mapping against the actual media before using it as evidence. [FFmpeg documentation](https://ffmpeg.org/ffmpeg-filters.html#showinfo).

Stop if source mapping is unresolved. Do not evaluate stitching with an unreliable time or coordinate reference.

## 2. Prove the distinctive geometry

Record 60–90 seconds of one product page at a fixed viewport size and zoom.
Scroll across three viewport heights, edit a visible value, then jump past an unobserved gap.
One initial viewport selection is allowed. Manual frame offsets are not allowed in automatic scoring.

Build only the proposed pipeline needed for this sequence.
Retain the frame times and source rectangles for each output patch.
The result must include:

- A readable surface at least two viewport heights tall.
- A separate changed state, with no invented content in unseen areas.
- A timed card for the unsupported jump.
- A source-frame action for every visible patch.
- A sentence rail connected to the recording time.

Keep an independent record of visible landmarks and old/new values.
Use recorded pixels as ground truth. Offscreen DOM content does not count as observed content.
Save a few failure crops and raw counts. Do not build a benchmark service.

## 3. Check likely failures

Use short directed clips. Several cases can share a clip if their ground truth remains clear.
Freeze thresholds before checking held-out examples.

| Case | Required result |
| --- | --- |
| Clean scrolling and reversal | Preserve page geometry and later traversal times. |
| Fixed header, sticky row, tooltip, cursor | Avoid repeated headers and false motion estimates; keep temporal evidence reachable. |
| Nested pane, window movement, resize, zoom | Refuse unsupported whole-view joins. |
| Small edit, inserted text, lazy load, recycled list rows | Preserve changed content or show a clear unstitched interval. |
| Fast jump, repeated text, blank content | Refuse an ambiguous or unsupported displacement. |
| Similar pages and repeated visits | Keep separate visits; test confirmed identity only when that feature exists. |
| Animation and brief edits | Preserve named changes visible for at least 500 ms; report shorter events separately. |
| Slides and code | Keep slide states; join only supported stable code scrolling. |

The [full Pro proof plan](pro-output/video-to-canvas-proof-plan.md) supplies detailed corpus and metric definitions.
Use it as a reference. Its eight-clip and 21-trial counts are not fixed requirements for this personal proof.

After the clean case passes, test at least two distinct narrated product recordings before claiming primary-case support.
Lecture support needs a separate supplied lecture sample.
Do not count omitted return detection as a perfect return detector.
Report attempted joins, accepted joins, refusals, and their reasons.

## 4. Compare practical value

Test the same tasks in ordinary video, a useful change-selected storyboard, and the canvas.
Use comparable content and rotate the order to reduce learning effects.
Include finding content, comparing an edit, locating the relevant narration, and returning to its source moment.
Count initial crop selection and manual correction time.

After basic navigation works, add one bounded larger-than-frame capture.
Verify its output against the contributor frames and source map.
Report capture success separately when a comparison view cannot produce the same result.

Begin with a few matched tasks.
Expand the comparison only if the result is unclear.
Keep Byron's direct assessment alongside accuracy, time, and failure counts.
A small personal comparison cannot establish a general user-study result.

## 5. Decide whether to continue

The numerical values below are proposed starting gates. They are not measured results.
Adjust product budgets explicitly before evaluation; do not change them afterward to hide a failure.

| Gate | Proposed acceptance | Failure decision |
| --- | --- | --- |
| Source truth | No harmful accepted join or lost required change in the scored set. Every patch maps to a real frame and crop. | Block the affected stitched mode. Keep timed cards. |
| Geometry | Source-pixel error p95 at most 2 pixels and maximum at most 4. At least 90% of eligible clean-scroll content appears legibly. | Diagnose one cause, then narrow or stop if clean scrolling still fails. |
| User value | No task-accuracy loss, useful long capture, and a clear time benefit over the stronger comparison. A 20% median gain is a provisional target. | Prefer the simpler storyboard when spatial geometry does not earn its cost. |
| Local cost | Analysis completes within recording duration. Proposed worker budget: 512 MiB; viewer increase: 256 MiB. Ordinary review remains usable. | Fix one measured bottleneck or reduce scope. |

Check source seeking within one actual neighboring frame interval.
Inspect labels and code for cut, doubled, or blurred glyphs introduced by reconstruction.
Count meaningful changes lasting at least 500 ms; a general link to the whole video does not count as preservation.
Zero errors in a small test set is an acceptance result, not a guarantee about future recordings.

Try one focused method revision after diagnosing a failure.
Keep broader changes as a new decision rather than expanding the proof without a limit.

## 6. Measure longer sessions after the short proof wins

Use 10-minute and 60-minute workloads with distinct content.
Measure worker and child-process memory, viewer memory, processing time, output size, and refusal count.
Repeated identical clips can test some limits but do not establish real-session accuracy.

Use bounded patches or tiles and explicit eviction.
The Pro report's tile and image budgets are estimates to test, not defaults already selected.
No claim about actual throughput or compression follows from those estimates.

Edit a note and reprocess the disposable session.
Confirm that this does not rerun video reconstruction.
Check missing or invalid canvas data, changed source video, and interrupted output generation.
Keep canonical input hashes unchanged except for an intentional note edit in the disposable copy.

## 7. Keep implementation boundaries clear

The proposed first surface is [viewer.html](../../../scripts/viewer.html), with its existing player and inline session data.
The proposed analyzer and canvas files do not exist yet.
Dependency setup and source reuse need separate local validation during implementation.

Only the following existing checks ran during this research workflow:

- `swift build`: passed in 229.47 seconds after access to compiler caches was allowed.
- `python3 scripts/process_session.py --help`: passed.
- Research document, JSON, source-hash, and archive checks: recorded in the [review](research-review.md).

No recording was decoded or reconstructed. No canvas interaction, export, accuracy, performance, or usability test ran.
The next implementation request must start with this evidence gap intact.
