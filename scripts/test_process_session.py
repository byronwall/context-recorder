"""Unit tests for the edit (segment) mapping in process_session.py.

    python3 -m unittest scripts/test_process_session.py

No ffmpeg or session folder needed. The time-mapping cases are shared with the app's
`--self-test edits` check, so Python and Swift agree on what a cut means.
"""
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import process_session as ps  # noqa: E402

CASES = json.loads((Path(__file__).parent / "fixtures" / "edit-cases.json").read_text())["cases"]


def segs(*ranges, source="."):
    return ps.resolve([{"source": source, "start": a, "end": b} for a, b in ranges])


class SharedCases(unittest.TestCase):
    def test_cases(self):
        for case in CASES:
            segments = ps.resolve(case["segments"])
            with self.subTest(case["name"]):
                self.assertAlmostEqual(ps.edited_duration(segments), case["duration"])
                for source, t, expected in case["toEdited"]:
                    got = ps.to_edited(segments, source, t)
                    if expected is None:
                        self.assertIsNone(got, f"{source}@{t}")
                    else:
                        self.assertAlmostEqual(got, expected, msg=f"{source}@{t}")
                for edited, source, t in case["toSource"]:
                    got = ps.to_source(segments, edited)
                    self.assertEqual(got[0], source, f"edited {edited}")
                    self.assertAlmostEqual(got[1], t, msg=f"edited {edited}")


class Marks(unittest.TestCase):
    def test_marks_shift_or_hide(self):
        marks = [{"index": 1, "offsetSeconds": 2}, {"index": 2, "offsetSeconds": 20}, {"index": 3, "offsetSeconds": 50},
                 {"index": 4, "offsetSeconds": 70}]
        visible, hidden = ps.map_marks(marks, segs((5, 40), (60, 90)), ".")
        self.assertEqual([(m["index"], m["offsetSeconds"]) for m in visible], [(2, 15), (4, 45)])
        self.assertEqual([m["index"] for m in hidden], [1, 3])
        self.assertEqual(visible[1]["sourceOffsetSeconds"], 70)
        self.assertEqual(hidden[1]["offsetSeconds"], 50)  # hidden marks keep source time

    def test_mark_on_boundary_is_kept(self):
        visible, _ = ps.map_marks([{"index": 1, "offsetSeconds": 40}], segs((5, 40), (60, 90)), ".")
        self.assertEqual(visible[0]["offsetSeconds"], 35)


class Transcript(unittest.TestCase):
    def sentence(self, a, b):
        return {"start": a, "end": b, "text": "x", "tokens": [{"text": "a", "start": a, "end": a + 0.2},
                                                              {"text": "b", "start": b - 0.2, "end": b}]}

    def test_sentence_mostly_kept_is_clamped(self):
        out = ps.map_sentences([self.sentence(38, 48)], segs((0, 45), (60, 90)), ".")
        self.assertEqual(len(out), 1)
        self.assertAlmostEqual(out[0]["start"], 38)
        self.assertAlmostEqual(out[0]["end"], 45)
        self.assertEqual([t["text"] for t in out[0]["tokens"]], ["a"])  # the token inside the cut is gone

    def test_sentence_mostly_cut_drops(self):
        self.assertEqual(ps.map_sentences([self.sentence(42, 52)], segs((0, 45), (60, 90)), "."), [])

    def test_sentence_split_by_middle_cut(self):
        out = ps.map_sentences([self.sentence(10, 20)], segs((0, 14), (15, 30)), ".")
        self.assertAlmostEqual(out[0]["start"], 10)
        self.assertAlmostEqual(out[0]["end"], 19)

    def test_narration_quotes_only_kept_speech(self):
        sentences = [{"start": 0, "end": 3, "text": "", "tokens": [{"text": " kept", "start": 1, "end": 2}]},
                     {"start": 10, "end": 13, "text": "", "tokens": [{"text": " gone", "start": 11, "end": 12}]},
                     {"start": 20, "end": 23, "text": "", "tokens": [{"text": " later", "start": 21, "end": 22}]}]
        mapped = ps.map_sentences(sentences, segs((0, 5), (18, 30)), ".")
        tokens = [t for s in mapped for t in s["tokens"]]
        self.assertEqual(ps.narration_window(tokens, 4, 20, 10), "kept ⚑ later")


class Activity(unittest.TestCase):
    def test_state_carries_into_each_kept_range(self):
        items = [{"offsetSeconds": 0, "app": "A"}, {"offsetSeconds": 10, "app": "B"}, {"offsetSeconds": 30, "app": "C"}]
        out = ps.map_states(items, segs((0, 5), (20, 40)), ".")
        self.assertEqual([(i["offsetSeconds"], i["app"]) for i in out], [(0, "A"), (5, "B"), (15, "C")])

    def test_points_drop_inside_cuts(self):
        items = [{"offsetSeconds": 1}, {"offsetSeconds": 7}, {"offsetSeconds": 25}]
        self.assertEqual([i["offsetSeconds"] for i in ps.map_points(items, segs((0, 5), (20, 40)), ".")], [1, 10])


class Validation(unittest.TestCase):
    def test_backwards_segment_is_rejected(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / "edits.json").write_text(json.dumps({"segments": [{"start": 5, "end": 2}]}))
            with self.assertRaises(ValueError):
                ps.load_edits(Path(d))

    def test_missing_edits_is_none(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            self.assertIsNone(ps.load_edits(Path(d)))


if __name__ == "__main__":
    unittest.main()
