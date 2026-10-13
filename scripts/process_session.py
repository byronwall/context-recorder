#!/usr/bin/env python3
"""Turn a raw Context Recorder session folder into markdown.

Input (written by the app):
  recording.mp4      screen + mic
  marks.jsonl        one JSON object per mark
  screenshots/*.png  full-res stills for "screenshot" marks

Output:
  audio.wav, transcript.json      (parakeet-mlx)
  frames/NNN.jpg                  video frame for every mark
  marks/NNN.md                    one file per mark: image, narration window, context
  session.md                      all marks + full timestamped transcript
  session.json                    everything above, machine-readable
  viewer.html                     "control center" UI (open directly in a browser)

Recordings without a microphone track (silent mode) skip transcription.

Re-runnable: `python3 scripts/process_session.py <session-folder> [--before 20] [--after 10]`
Stdlib only.
"""
import argparse
import json
import os
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
    if not has_audio(folder / "recording.mp4"):
        print("no audio track (silent recording); skipping transcript")
        return None
    wav = folder / "audio.wav"
    out = folder / "transcript.json"
    if out.exists():
        return json.loads(out.read_text())
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


def extract_frame(folder, mark):
    frames = folder / "frames"
    frames.mkdir(exist_ok=True)
    dest = frames / f"{mark['index']:03d}.jpg"
    if not dest.exists():
        # Nudge slightly forward so we don't land before the first decodable frame.
        ts = max(0.0, mark["offsetSeconds"])
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


def mark_markdown(mark, image, narration, rel_prefix=""):
    title = narration_title(narration) or (mark["context"].get("browserTitle") or mark["context"].get("windowTitle") or "Mark")
    lines = [
        f"## {mark['index']:03d} · {fmt_ts(mark['offsetSeconds'])} · {title}",
        "",
        f"![mark {mark['index']}]({rel_prefix}{image})",
        "",
    ]
    if narration:
        lines += ["> " + narration, ""]
    lines += context_lines(mark["context"])
    lines += [f"- **Video:** `recording.mp4` @ {mark['offsetSeconds']:.1f}s", f"- **Kind:** {mark['kind']}", ""]
    return "\n".join(lines)


def narration_title(narration, limit=70):
    """Short heading from the words spoken just before the mark."""
    if not narration:
        return ""
    before = narration.split("⚑")[0].strip() or narration.replace("⚑", "").strip()
    # Last sentence before the mark tends to be the "this is broken because…" line.
    parts = [p.strip() for p in before.replace("?", ".").replace("!", ".").split(".") if p.strip()]
    text = parts[-1] if parts else before
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
    tokens = tokens_of(transcript)

    (folder / "marks").mkdir(exist_ok=True)
    sections = []
    for mark in marks:
        image = mark.get("screenshot")
        if not image or not (folder / image).exists():
            image = extract_frame(folder, mark)
        narration = narration_window(tokens, mark["offsetSeconds"], args.before, args.after) if tokens else ""
        mark["image"] = image
        mark["narration"] = narration
        (folder / "marks" / f"{mark['index']:03d}.md").write_text(mark_markdown(mark, image, narration, "../"))
        sections.append(mark_markdown(mark, image, narration))

    # Machine-readable rollup for the viewer and later exporters (pgm, etc.).
    data = {
        "name": folder.name,
        "folder": str(folder),
        "duration": duration_of(folder / "recording.mp4"),
        "marks": marks,
        "activity": load_jsonl(folder / "activity.jsonl"),
        "transcript": [{"start": s_["start"], "end": s_["end"], "text": s_["text"].strip()}
                       for s_ in (transcript or {}).get("sentences", [])],
    }
    (folder / "session.json").write_text(json.dumps(data, indent=2))
    write_viewer(folder, data)

    out = [f"# Session {folder.name}", "", f"{len(marks)} marks · video: `recording.mp4`", ""]
    out += sections
    if transcript:
        out += ["---", "", "## Full transcript", ""]
        for s in transcript.get("sentences", []):
            out.append(f"- `{fmt_ts(s['start'])}` {s['text'].strip()}")
    (folder / "session.md").write_text("\n".join(out) + "\n")
    print(f"wrote {folder / 'session.md'}")


if __name__ == "__main__":
    main()
