#!/usr/bin/env python3
"""Turn a raw Context Recorder session folder into markdown.

Input (written by the app):
  recording.mp4      screen + mic
  marks.jsonl        one JSON object per mark
  screenshots/*.png  region stills for "screenshot" marks
  activity.jsonl     front app / window / Chrome tab changes
  browser.jsonl      page events streamed by the Chrome extension (optional)

Output:
  audio.wav, transcript.json      (parakeet-mlx)
  frames/NNN.jpg                  video frame for every mark
  marks/NNN.md                    one file per mark: image, narration window, context, page snapshot
  session.md                      all marks + full timestamped transcript
  session.json                    everything above, machine-readable
  viewer.html                     "control center" UI (open directly in a browser)

Edits (optional, written by the Sessions window):
  edits.json   {"segments": [{"source": ".", "start": s, "end": s}, ...]}
               The kept ranges of the recording, in play order. Everything above is then written in
               edited time: marks, activity, page events and the transcript move with the video, and
               anything inside a removed range drops out (marks go to "hiddenMarks"). Raw files are
               never changed, so deleting edits.json restores the session.

Recordings without a microphone track (silent mode) skip transcription.

Re-runnable: `python3 scripts/process_session.py <session-folder> [--before 20] [--after 10]`
Stdlib only.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


# The app launches us from a GUI context where PATH may be minimal; make Homebrew / uv tools findable.
os.environ["PATH"] = os.pathsep.join(
    [str(Path.home() / ".local/bin"), "/opt/homebrew/bin", "/usr/local/bin", os.environ.get("PATH", "")])


def run(cmd):
    print("$", " ".join(str(c) for c in cmd), flush=True)
    subprocess.run(cmd, check=True)


def fmt_ts(seconds):
    seconds = max(0, int(seconds))
    return f"{seconds // 60}:{seconds % 60:02d}"


def load_marks(folder):
    path = folder / "marks.jsonl"
    if not path.exists():
        return []
    return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]


def has_audio(video):
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a", "-show_entries", "stream=index",
                          "-of", "csv=p=0", video], capture_output=True, text=True)
    return bool(out.stdout.strip())


def duration_of(video):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", video],
                         capture_output=True, text=True)
    try:
        return float(out.stdout.strip())
    except ValueError:
        return None


def load_jsonl(path):
    if not path.exists():
        return []
    return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]


def transcribe(folder):
    out = folder / "transcript.json"
    if out.exists():  # re-processing (e.g. after adding marks while reviewing) keeps the transcript
        return json.loads(out.read_text())
    if not has_audio(folder / "recording.mp4"):
        print("no audio track (silent recording); skipping transcript")
        return None
    wav = folder / "audio.wav"
    if not wav.exists():
        run(["ffmpeg", "-loglevel", "error", "-y", "-i", folder / "recording.mp4", "-vn", "-ac", "1", "-ar", "16000", wav])
    exe = shutil.which("parakeet-mlx")
    if not exe:
        print("parakeet-mlx not found on PATH; skipping transcript", file=sys.stderr)
        return None
    run([exe, wav, "--output-format", "json", "--output-dir", folder])
    produced = folder / "audio.json"
    if produced.exists():
        produced.rename(out)
    return json.loads(out.read_text()) if out.exists() else None


def tokens_of(transcript):
    if not transcript:
        return []
    return [t for s in transcript.get("sentences", []) for t in s.get("tokens", [])]


def narration_window(tokens, offset, before, after):
    """Text spoken in [offset-before, offset+after], with a ⚑ where the mark landed."""
    lo, hi = offset - before, offset + after
    out, placed = [], False
    for t in tokens:
        if t["end"] < lo or t["start"] > hi:
            continue
        if not placed and t["start"] >= offset:
            out.append(" ⚑")
            placed = True
        out.append(t["text"])
    if not placed:
        out.append(" ⚑")
    return "".join(out).strip()


# ---------------------------------------------------------------------------------------------------
# Edits: a session is an ordered list of segments, each a [start, end) range of a source recording.
# Raw data stays in source time; these functions map it into edited (play) time.


def load_edits(folder):
    """The segment list from edits.json, or None when the session is unedited."""
    path = folder / "edits.json"
    if not path.exists():
        return None
    data = json.loads(path.read_text())
    segments = [{"source": s.get("source", "."), "start": float(s["start"]), "end": float(s["end"])}
                for s in data.get("segments", [])]
    for s in segments:
        if s["end"] <= s["start"]:
            raise ValueError(f"edits.json: segment ends before it starts: {s}")
    return segments


def resolve(segments):
    """Segments with editedStart filled in; play order is list order."""
    out, at = [], 0.0
    for s in segments:
        out.append({**s, "editedStart": round(at, 6)})
        at += s["end"] - s["start"]
    return out


def edited_duration(segments):
    return sum(s["end"] - s["start"] for s in segments)


def to_edited(segments, source, t):
    """Edited time for source time `t`, or None when `t` was cut. Segments must be resolved."""
    for s in segments:
        if s["source"] == source and s["start"] <= t <= s["end"]:
            return round(s["editedStart"] + t - s["start"], 6)
    return None


def to_source(segments, edited):
    """(source, time) for an edited time; clamps to the ends."""
    if not segments:
        return (".", edited)
    for s in segments:
        if edited < s["editedStart"] + (s["end"] - s["start"]):
            return (s["source"], round(s["start"] + max(0.0, edited - s["editedStart"]), 6))
    last = segments[-1]
    return (last["source"], last["end"])


def kept_pieces(segments, source, a, b):
    """The parts of source range [a, b] that survive, as edited (start, end) pairs."""
    out = []
    for s in segments:
        if s["source"] != source:
            continue
        lo, hi = max(a, s["start"]), min(b, s["end"])
        if hi > lo or (hi == lo and a == b and s["start"] <= a <= s["end"]):
            out.append((s["editedStart"] + lo - s["start"], s["editedStart"] + hi - s["start"]))
    return out


def map_points(items, segments, source, key="offsetSeconds"):
    """Point events (page events): converted, or dropped when cut."""
    out = []
    for item in items:
        t = to_edited(segments, source, item[key])
        if t is not None:
            out.append({**item, key: t})
    return out


def map_states(items, segments, source, key="offsetSeconds"):
    """State changes (activity): each kept range starts with the state that was active at its start,
    so the Apps lane stays continuous across a cut."""
    out = []
    for s in segments:
        if s["source"] != source:
            continue
        active = None
        for item in items:
            if item[key] <= s["start"]:
                active = item
        if active is not None:
            out.append({**active, key: s["editedStart"]})
        for item in items:
            if s["start"] < item[key] < s["end"]:
                out.append({**item, key: round(s["editedStart"] + item[key] - s["start"], 6)})
    return out


def map_sentences(sentences, segments, source):
    """Sentences survive when more than half of them is kept; times are clamped to what is kept and
    tokens inside cuts are dropped."""
    out = []
    for sentence in sentences:
        pieces = kept_pieces(segments, source, sentence["start"], sentence["end"])
        length = max(1e-6, sentence["end"] - sentence["start"])
        if not pieces or sum(b - a for a, b in pieces) <= length / 2:
            continue
        tokens = []
        for tok in sentence.get("tokens", []):
            mid = to_edited(segments, source, (tok["start"] + tok["end"]) / 2)
            if mid is None:
                continue
            half = (tok["end"] - tok["start"]) / 2
            tokens.append({**tok, "start": round(mid - half, 6), "end": round(mid + half, 6)})
        out.append({**sentence, "start": round(pieces[0][0], 6), "end": round(pieces[-1][1], 6), "tokens": tokens})
    return out


def map_marks(marks, segments, source):
    """(visible, hidden): visible marks get edited offsetSeconds and keep sourceOffsetSeconds."""
    visible, hidden = [], []
    for mark in marks:
        original = mark["offsetSeconds"]
        t = to_edited(segments, source, original)
        mapped = {**mark, "sourceOffsetSeconds": original, "sourceSession": source}
        if t is None:
            hidden.append(mapped)
        else:
            mapped["offsetSeconds"] = t
            visible.append(mapped)
    return visible, hidden


def check_page_file(folder, mark):
    """Drop pageFile if the MHTML never arrived, recording why when the extension reported an error."""
    browser = mark.get("browser") or {}
    page = browser.get("pageFile")
    if not page or (folder / page).exists():
        return
    err = (folder / page).with_suffix(".error.txt")
    browser["pageError"] = err.read_text().strip() if err.exists() else "page capture never arrived"
    del browser["pageFile"]


def extract_frame(folder, mark):
    frames = folder / "frames"
    frames.mkdir(exist_ok=True)
    dest = frames / f"{mark['index']:03d}.jpg"
    if not dest.exists():
        # Nudge slightly forward so we don't land before the first decodable frame.
        ts = max(0.0, mark.get("sourceOffsetSeconds", mark["offsetSeconds"]))
        run(["ffmpeg", "-loglevel", "error", "-y", "-ss", f"{ts:.3f}", "-i", folder / "recording.mp4",
             "-frames:v", "1", "-q:v", "3", dest])
    return dest.relative_to(folder).as_posix()


def context_lines(ctx):
    rows = [
        ("App", ctx.get("appName") and f"{ctx.get('appName')} (`{ctx.get('bundleID')}`)"),
        ("Window", ctx.get("windowTitle")),
        ("URL", ctx.get("browserURL")),
        ("Page title", ctx.get("browserTitle")),
    ]
    return [f"- **{k}:** {v}" for k, v in rows if v]


def element_line(label, el):
    if not el:
        return []
    bits = [f"`{el.get('selector')}`"]
    if el.get("text"):
        bits.append(f"“{el['text']}”")
    if el.get("components"):
        bits.append("in " + " › ".join(reversed(el["components"][:5])))
    lines = [f"- **{label}:** " + " · ".join(bits)]
    src = source_text(el.get("source"))
    if src:
        lines.append(f"  - source: `{src}`")
    if el.get("props"):
        props = ", ".join(f"{k}={json.dumps(v)}" for k, v in el["props"].get("props", {}).items())
        lines.append(f"  - `<{el['props'].get('component')}>` props: {props or '(none)'}")
    return lines


def source_text(src):
    if not src or not src.get("file"):
        return ""
    loc = src["file"] + (f":{src['line']}" if src.get("line") else "") + (f":{src['column']}" if src.get("column") else "")
    note = " (line is post-transform)" if src.get("via") == "react-debugStack" else ""
    return loc + note


def problem_text(e):
    if e.get("kind") == "request":
        tail = f" {e.get('error') or ''}{(' — ' + e['body']) if e.get('body') else ''}"
        return f"{e.get('method')} {e.get('requestUrl')} → {e.get('status')} ({e.get('ms')} ms){tail}"
    if e.get("kind") == "console":
        return f"console.{e.get('level')}: {e.get('message')}"
    if e.get("kind") == "error":
        return f"{e.get('type')}: {e.get('message') or e.get('source')}"
    return json.dumps(e)


def is_problem(e):
    k = e.get("kind")
    return (k in ("console", "error")) or (k == "request" and (e.get("error") or (e.get("status") or 0) >= 400
                                                                or e.get("status") == 0 or e.get("slow")))


def browser_lines(browser):
    if not browser:
        return []
    if browser.get("error"):
        return ["", f"_Browser snapshot unavailable: {browser['error']}_"]
    lines = ["", "**Page**", ""]
    lines += element_line("Under mouse", browser.get("hovered"))
    lines += element_line("Focused", browser.get("focused"))
    region = browser.get("region") or {}
    if region.get("elements"):
        lines += ["", f"**Inside the screenshot region** _(mapped via {region.get('method')})_", ""]
        for el in region["elements"][:15]:
            src = source_text(el.get("source"))
            comps = " › ".join(reversed((el.get("components") or [])[:3]))
            lines.append(f"- `{el.get('selector')}`" + (f" “{el['text'][:80]}”" if el.get("text") else "")
                         + (f" · {comps}" if comps else "") + (f" · `{src}`" if src else ""))
        lines.append("")
    elif region.get("note"):
        lines.append(f"- _Region: {region['note']}_")
    if browser.get("pageError"):
        lines.append(f"- **Saved page:** _missing ({browser['pageError']})_")
    if browser.get("pageFile"):
        lines.append(f"- **Saved page:** [{browser['pageFile']}](PAGE_PREFIX{browser['pageFile']}) — open in Chrome to inspect the DOM as it was")
    if browser.get("selection"):
        lines.append(f"- **Selected text:** {browser['selection']}")
    recent = browser.get("recent") or []
    clicks = [e for e in recent if e.get("kind") == "click"][-3:]
    for c in clicks:
        el = c.get("element") or {}
        lines.append(f"- **Recent click:** `{el.get('selector')}`" + (f" “{el['text']}”" if el.get("text") else ""))
    problems = [e for e in recent if is_problem(e)][-8:]
    if problems:
        lines += ["", "**Recent errors / failed requests**", ""]
        lines += [f"- {trunc_line(problem_text(e))}" for e in problems]
    return lines


def trunc_line(s, n=400):
    s = " ".join(str(s).split())
    return s if len(s) <= n else s[: n - 1] + "…"


def note_title(note, limit=70):
    """First line of a typed note, for headings."""
    text = " ".join((note or "").strip().splitlines()[:1]).strip() if note else ""
    return text if len(text) <= limit else text[: limit - 1].rstrip() + "…"


def mark_markdown(mark, image, narration, rel_prefix=""):
    title = (note_title(mark.get("note")) or narration_title(narration)
             or mark["context"].get("browserTitle") or mark["context"].get("windowTitle") or "Mark")
    lines = [
        f"## {mark['index']:03d} · {fmt_ts(mark['offsetSeconds'])} · {title}",
        "",
        f"![mark {mark['index']}]({rel_prefix}{image})",
        "",
    ]
    if mark.get("note"):
        lines += ["**Note:** " + " ".join(mark["note"].split()), ""]
    if narration:
        lines += ["> " + narration, ""]
    lines += context_lines(mark["context"])
    original = mark.get("sourceOffsetSeconds", mark["offsetSeconds"])
    video = "recording.mp4" if mark.get("sourceSession", ".") == "." else f"{mark['sourceSession']}/recording.mp4"
    lines += [f"- **Video:** `{video}` @ {original:.1f}s", f"- **Kind:** {mark['kind']}"]
    if mark.get("source") == "review":
        lines.append("- **Added:** while reviewing the recording (no live page snapshot)")
    lines += [l.replace("PAGE_PREFIX", rel_prefix) for l in browser_lines(mark.get("browser"))]
    lines.append("")
    return "\n".join(lines)


def session_title(folder):
    """The name given with Rename in the Sessions window (session-info.json), if any."""
    try:
        return (json.loads((folder / "session-info.json").read_text()).get("title") or "").strip() or None
    except (OSError, ValueError):
        return None


def narration_title(narration, limit=70):
    """Short heading: the sentence being spoken when the mark was made (the one containing ⚑)."""
    if not narration:
        return ""
    sentences = [s for s in re.split(r"(?<=[.!?])\s+", narration.strip()) if s.strip()]
    clean = lambda s: " ".join(s.replace("⚑", " ").split()).replace(" ,", ",").replace(" .", ".")
    i = next((n for n, s in enumerate(sentences) if "⚑" in s), None)
    if i is None:
        text = clean(sentences[-1]) if sentences else ""
    else:
        text = clean(sentences[i])
        if not text and i > 0:  # "…broken. ⚑" - the mark landed right after a sentence ended
            text = clean(sentences[i - 1])
    return text if len(text) <= limit else text[: limit - 1].rstrip() + "…"


def write_viewer(folder, data):
    template = Path(__file__).with_name("viewer.html").read_text()
    payload = json.dumps(data).replace("</", "<\\/")
    (folder / "viewer.html").write_text(template.replace("/*__SESSION_DATA__*/null", payload))
    print(f"wrote {folder / 'viewer.html'}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("folder", type=Path)
    ap.add_argument("--before", type=float, default=20.0, help="seconds of narration before each mark")
    ap.add_argument("--after", type=float, default=10.0, help="seconds of narration after each mark")
    args = ap.parse_args()
    folder = args.folder.expanduser().resolve()

    marks = load_marks(folder)
    transcript = transcribe(folder)
    sentences = (transcript or {}).get("sentences", [])
    activity = load_jsonl(folder / "activity.jsonl")
    browser = load_jsonl(folder / "browser.jsonl")

    edits = load_edits(folder)
    hidden = []
    if edits is None:
        # Unedited: everything stays exactly as recorded; one segment covers the whole video.
        duration = duration_of(folder / "recording.mp4")
        segments = resolve([{"source": ".", "start": 0.0, "end": duration or 0.0}])
    else:
        segments = resolve(edits)
        duration = round(edited_duration(segments), 6)
        marks, hidden = map_marks(marks, segments, ".")
        sentences = map_sentences(sentences, segments, ".")
        activity = map_states(activity, segments, ".")
        browser = map_points(browser, segments, ".")
    tokens = [t for s_ in sentences for t in s_.get("tokens", [])]

    (folder / "marks").mkdir(exist_ok=True)
    # Marks can be deleted while reviewing, or cut: drop their old Markdown.
    keep = {f"{m['index']:03d}.md" for m in marks}
    for old in (folder / "marks").glob("*.md"):
        if old.name not in keep:
            old.unlink()
    sections = []
    for mark in marks:
        check_page_file(folder, mark)
        frame = extract_frame(folder, mark)
        image = mark.get("screenshot")
        if not image or not (folder / image).exists():
            image = frame
        mark["frame"] = frame
        narration = narration_window(tokens, mark["offsetSeconds"], args.before, args.after) if tokens else ""
        mark["image"] = image
        mark["narration"] = narration
        (folder / "marks" / f"{mark['index']:03d}.md").write_text(mark_markdown(mark, image, narration, "../"))
        sections.append(mark_markdown(mark, image, narration))
    for mark in hidden:
        check_page_file(folder, mark)
        mark["frame"] = extract_frame(folder, mark)
        shot = mark.get("screenshot")
        mark["image"] = shot if shot and (folder / shot).exists() else mark["frame"]

    # Machine-readable rollup for the viewer and later exporters (pgm, etc.).
    data = {
        "name": folder.name,
        "folder": str(folder),
        "duration": duration,
        "segments": segments,
        # Full length of each source recording, so the window can offer to restore a cut at either end.
        "sourceDurations": {".": duration_of(folder / "recording.mp4")},
        "marks": marks,
        "hiddenMarks": hidden,
        "activity": activity,
        "browser": browser,
        "transcript": [{"start": s_["start"], "end": s_["end"], "text": s_["text"].strip()} for s_ in sentences],
    }
    (folder / "session.json").write_text(json.dumps(data, indent=2))
    write_viewer(folder, data)

    title = session_title(folder)
    video = "video: `recording.mp4`"
    if edits is not None:
        cut = (duration_of(folder / "recording.mp4") or duration) - duration
        video += f", edited to {fmt_ts(duration)} ({fmt_ts(cut)} cut; times below are edited times)"
    out = [f"# {title} ({folder.name})" if title else f"# Session {folder.name}", "", f"{len(marks)} marks · {video}", ""]
    out += sections
    if sentences:
        out += ["---", "", "## Full transcript", ""]
        for s in sentences:
            out.append(f"- `{fmt_ts(s['start'])}` {s['text'].strip()}")
    (folder / "session.md").write_text("\n".join(out) + "\n")
    print(f"wrote {folder / 'session.md'}")


if __name__ == "__main__":
    main()
