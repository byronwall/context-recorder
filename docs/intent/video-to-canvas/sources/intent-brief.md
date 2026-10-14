# Video to canvas

Status: proposed. Research has not yet established feasibility.

## Desired outcome

Turn a narrated recording into a canvas that people can explore in space.
Show the content across time, with links back to the original video.
Make product walkthroughs easier to inspect, discuss, and capture.

The central idea is to convert time into space, then use interaction to recover time.
The canvas should feel useful and fun. It should reveal what a normal video player hides.

## Experiences to preserve

1. Scroll a web page. Align overlapping frames into a tall view of the content that appeared.
2. Change the page. Place the changed state to the right, while retaining its relation to the previous state.
3. Show frequent changes. Use overlapping cards or another compact sequence that preserves meaningful moments.
4. Encounter motion. Let a person inspect or play the animation from its place on the canvas.
5. Return to earlier content. Show a return arrow and jump, while preserving the new visit in the sequence.
6. Speak while navigating. Associate transcript chunks with the visual content and times they describe.
7. Review a lecture. Gather slides, code, and narration into a spatial storyboard.
8. Capture a region. Export a composite larger than any single video frame, with its source times available.

The primary case is a narrated product walkthrough with scrolling static content.
A lecture video with slides is a second case.
General video is a research question, not a promised capability.

## Choices for research

- Which content can be joined without creating a misleading image?
- When should the system extend an image, create a state, show motion, or link a return?
- Can video alone support a useful first version?
- How much would optional browser events, DOM data, or scroll measurements improve it?
- Which interactions make the canvas readable without losing the video sequence?
- What should happen when alignment or content identity is uncertain?
- What is the smallest proof that tests the distinctive idea?

The suggested one, five, and ten second frame intervals are examples, not requirements.
Research should compare fixed sampling with change-based selection.
The rightward flow, card stacks, and return arrows express intent. Their exact layout remains open.

## Repository baseline

Source: `016684895df51872aeea1be5e93e28419fd63a7f` from `origin/main`.

The app uses Swift and SwiftUI on macOS 26.
It records the main display at up to 1920 pixels wide and 15 frames per second.
It saves marks, context changes, browser events, and page snapshots.
Python post-processing creates frames, transcript data, Markdown, and a portable HTML viewer.
The native Sessions window supports video review, marks, region shots, and Product Grid export.

The raw transcript includes token times. The session rollup keeps sentence times.
Browser snapshots include viewport scroll coordinates at marks.
The current source does not provide continuous scroll capture or a canvas reconstruction pipeline.
No tracked test suite or sample recording was found in this baseline.

## Scope of this run

Produce research, a proposed design, and a proof plan in a review PR.
Keep application implementation for a later decision.
Do not add services, replace the app stack, or change recordings during this run.

The research must preserve the full vision even if the first proof covers only scrolling content.
It must distinguish observed pixels from inferred layout and from unobserved content.
It must distinguish proposals from measured product behavior.
