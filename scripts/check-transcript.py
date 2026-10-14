#!/usr/bin/env python3
"""Check exact sentence starts, including a sentence shorter than 0.2 seconds."""
import json
import subprocess
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="cr-transcript-") as folder:
    sentences = [
        {"start": 1, "end": 1.05, "text": "Short"},
        {"start": 1.1, "end": 2, "text": "Next"},
        {"start": 4, "end": 5, "text": "After gap"},
    ]
    Path(folder, "session.json").write_text(json.dumps({"transcript": sentences}))
    subprocess.run(["swift", "run", "ContextRecorder", "--library", folder, "--check-transcript"], cwd=root, check=True)
