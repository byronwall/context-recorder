# Repository evidence for the research review

Baseline: `6c74158ca96abd36819d2a58f75bacdc44107bb0`.
These are static source observations. No capture, playback, or competitor product test ran for these notes.

## Correction to the submitted brief

The brief repeats the README's statement that input values are excluded. Source inspection does not support that broad claim.

In `extension/page.js`, `describe` selects interactive elements, including input, select, and textarea elements.
Its `text` field uses `target.innerText || target.value || ""` at line 207.
The click handler calls `describe(e.target)` at line 228.
The change handler also calls it at line 235, despite a comment saying values are never recorded.
That handler uses `stream: false`; this does not remove the value from the constructed event.

This establishes a capture path in source. It does not establish which personal values were captured in any real session.
No personal recordings were inspected. No sensitive input was entered to test it.

During reconciliation, reject any unqualified claim that the app excludes all input values.
Check Pro's assessment against this path. Use a bounded follow-up if the error materially affects its recommendations.
Preserve the submitted prompt and packet unchanged as handoff evidence.
Do not fix application code within this research-only scope.

## Other confirmed distinctions

| Capability | Source observation | Limit |
| --- | --- | --- |
| Screen capture | `Recorder.start` selects the main display; `maxWidth = 1920`, `fps = 15`. | A region screenshot is not region video recording. |
| Audio | `Recorder.start` sets `capturesAudio = false`; microphone capture is optional. | Microphone narration does not establish system audio support. |
| Speech | `scripts/process_session.py:transcribe` runs `parakeet-mlx` after capture. | No live dictation into other apps is established. |
| Transcript timing | Raw output has token times; `SessionData.Sentence` carries sentence times. | Seeking does not establish text editing or transcript correction. |
| Review marks | `Library/Review.swift` adds marks, cropped frames, and notes. | Historical review does not reconstruct a new DOM snapshot. |
| Local output | README and export code describe Markdown, media, JSON, HTML, and local Product Grid export. | Local files do not establish complete redaction or effortless sharing. |
| Spatial canvas | `docs/research/video-to-canvas/design.md` labels the feature proposed. | No product proof or implementation is established. |
| Existing checks | `scripts/check-transcript.py` and `scripts/ui-test/` exist at baseline. | Their existence does not mean they ran for this research. |

## Checks completed during preparation

- Verified baseline source bytes for all 47 baseline files in the packet.
- Verified UTF-8 decoding and packet hashes in `source-manifest.json`.
- Scanned the packet for private-key and common token patterns; no match found.
- Ran `python3 scripts/process_session.py --help`; passed.
- Ran `git diff --check`; passed before the checkpoint.
- Inspected capture, review, transcript, browser-context, and export source paths.

The packet scan is a bounded content check, not proof that arbitrary source text can never contain secrets.
The packet excludes user recordings, generated session data, binary assets, dependencies, and build output.
Swift compilation and native UI tests were not repeated for this document-only checkpoint.
