# Video to canvas: research review

Reviewed October 13, 2026, America/Indiana/Indianapolis.

The research supports a small experiment with automatic scroll reconstruction.
It does not establish product feasibility across general recordings.
The [proposed design](design.md) preserves the spatial storyboard vision and chooses a small first proof.

## Collection

The [Pro conversation](https://chatgpt.com/c/6acedea9-bee8-83ea-a73e-6f127f7a1891) completed after 36 minutes and 30 seconds.
All six requested files were collected: the ZIP, report, recommendations, proof plan, sources, and manifest.
Original bytes remain under [pro-output](pro-output/video-to-canvas-report.md).
The [collection manifest](collection-manifest.json) records names, sizes, hashes, paths, and retrieval time.

The ZIP passed its integrity check.
It contained five flat Markdown/JSON files, with no unsafe paths or symbolic links.
All four substantive files matched the supplied size and SHA-256 manifest.
All five standalone downloads matched their archive copies.
The recommendation array contains exactly nine unique IDs, VC-01 through VC-09.

The browser's download-event wait timed out, but the ZIP had reached the Downloads folder.
Collection used that verified file. No research restart or follow-up was needed.
A duplicate standalone report was byte-identical and was not added twice.

## Recommendation decisions

“Adopt” means include in the proposed design. It does not mean implemented or approved for release.
Each row resolves the corresponding item in the [original recommendation array](pro-output/video-to-canvas-recommendations.json).

| ID | Decision | Reason and destination |
| --- | --- | --- |
| VC-01 | Adopt, with a smaller initial schema | Keep source patches, states, and visits distinct in meaning. Avoid separate record tables until sharing needs them. See design: image meaning. |
| VC-02 | Investigate | Test translation with independent verification. Keep keyframes as the comparison and refusal result. Review pinned scrollsnap reuse before writing substantial code. See proof stages 2–3. |
| VC-03 | Adopt | Explicit offline analysis avoids capture contention and note-edit recomputation. See design: repository fit. |
| VC-04 | Adopt for the proof | The portable HTML viewer already has local media and inline data. Defer native canvas work until value is clear. |
| VC-05 | Adopt representation; defer richer detection | Preserve edits and later visits. Motion grouping and confirmed return detection get separate later checks. See design: experience and later steps. |
| VC-06 | Adopt | Use decoded frame times and source pixels. Treat narration association as temporal. Current clocks and mark images cannot supply exact frame provenance. |
| VC-07 | Adopt bounded images; investigate budgets | Avoid a full-session bitmap. Defer full export integration and fixed cache limits until the short proof wins. |
| VC-08 | Defer instrumentation | First measure video-only limits. Add browser measurements only for a specific failure; retain supplied-video support. |
| VC-09 | Adopt decision gates; reduce fixed test counts | Preserve truth, geometry, user value, and local-cost gates. Use a small directed corpus; the full trial schedule is optional. |

Reject silent merging of changed states, inferred content presented as observed pixels, and text-distorting output warps.
Reject a mandatory DOM replay system, cloud service, or new frontend stack for the first proof.
Keep richer correction tools and durable edit files outside the first slice unless a measured failure requires them.

## Repository checks

The inspected baseline is `016684895df51872aeea1be5e93e28419fd63a7f`.
At integration, tracked application source still matched this baseline.
The research branch contained only the prior handoff commit before artifact collection.

| Claim | Direct check and consequence |
| --- | --- |
| Capture requests 15 fps, width at most 1920, and H.264 at 4 Mbps | Confirmed in [Recorder.start](../../../../Sources/ContextRecorder/Recorder.swift). Requested cadence does not replace actual decoded times. |
| Still exposure can follow mark time | Confirmed in [addMark and addRegionMark](../../../../Sources/ContextRecorder/main.swift). The saved offset precedes region selection and asynchronous capture. |
| Browser event offsets are receipt times | Confirmed in `bridge.onEvent`, [background.js](../../../../extension/background.js), and [page.js](../../../../extension/page.js). Queued delivery and tab identity matter. |
| Scroll geometry is sparse | `snapshot` includes viewport and scroll coordinates on demand. `STREAM` contains no continuous scroll event. |
| Native page data omits viewport geometry | Confirmed in [PageSnapshot](../../../../Sources/ContextRecorder/Library/SessionData.swift). Raw JSON and native projection differ. |
| Transcript rollup contains sentences | Confirmed in [process_session.py](../../../../scripts/process_session.py). Raw transcript token times remain separate. |
| Existing frame extraction lacks recorded actual output time | `extract_frame` saves a JPEG; [Review.saveFrame](../../../../Sources/ContextRecorder/Library/Review.swift) discards the returned actual time. |
| HTML already has an inline data and shared-player path | Confirmed in `write_viewer`, `DATA`, `video`, `renderNow`, and the `seeked` listener. |
| Note edits rerun processing | Confirmed in `Review.reprocess`. Canvas analysis should stay outside that automatic path. |

These findings set requirements for new source mapping.
They do not establish a user-facing failure in the current mark workflow.

## Independent external checks

Checked October 13, 2026. These checks verify published capabilities, not accuracy on Context Recorder videos.

| Primary source | Verified claim and limit |
| --- | --- |
| [OpenCV motion API](https://docs.opencv.org/4.13.0/d7/df3/group__imgproc__motion.html) and [4.14 source](https://raw.githubusercontent.com/opencv/opencv/4.14.0/modules/imgproc/include/opencv2/imgproc.hpp) | Phase correlation estimates translation and returns a response based on the correlation peak. This is not a calibrated correctness probability. |
| [OpenCV headless 4.14.0.94](https://pypi.org/project/opencv-python-headless/4.14.0.94/) | macOS ARM64 and Intel wheels are listed. Downloads are 46.5 MB and 33.1 MB, before NumPy and installation expansion. No local install was tested. |
| [scrollsnap repository](https://github.com/Haruhiyuki/scrollsnap) and [metadata](https://raw.githubusercontent.com/Haruhiyuki/scrollsnap/main/pyproject.toml) | The project describes scroll coordinates and source crop queries. Metadata marks version 0.1.0 as Alpha and points to another source URL. Reuse remains unresolved. |
| [FFmpeg showinfo](https://ffmpeg.org/ffmpeg-filters.html#showinfo) | The filter reports frame number, presentation timestamp, timestamp seconds, and image size. A real extraction still needs mapping checks. |

The [Pro source ledger](pro-output/video-to-canvas-sources.md) contains 27 external sources and their access limits.
Other prior-art summaries remain Pro research evidence; Codex did not independently reproduce their results.
No measured runtime, accuracy, library compatibility, or general lecture support is claimed.

## Validation and limits

| Evidence type | Result |
| --- | --- |
| Pro research | All five priority questions answered; nine recommendations; rejected approaches and unresolved choices explicit. |
| Artifact integrity | Archive, hashes, standalone comparisons, JSON fields, IDs, references, and example mappings checked locally. |
| Local repository | `swift build` passed in 229.47 seconds; processor help passed; document links and whitespace checked. |
| Product tests | Unrun. No media, canvas, browser interaction, export, performance, or usability experiment was executed. |

The build emitted an existing warning in `Recorder.swift:88` about capturing a non-Sendable value.
The first build attempt failed under filesystem restrictions. The approved retry completed.
No application source changed, so the unrelated warning remains outside this research PR.

The proposed data example parses and its translations are consistent.
That check establishes only document consistency.
The detailed memory estimates and thresholds remain assumptions until a proof measures them.

No follow-up was required. The package supplied the contracted evidence and made its limits explicit.
Open product choices remain proposals for review: viewport selection, transcript placement, return layout, and acceptable cost.
