#!/usr/bin/env python3

from concurrent.futures import ThreadPoolExecutor
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


MODULE_PATH = Path(__file__).with_name("typst_indexed_spacing.py")
SPEC = importlib.util.spec_from_file_location("typst_indexed_spacing", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class CandidateTests(unittest.TestCase):
    def scan(self, source: str) -> list[str]:
        with tempfile.NamedTemporaryFile("w", suffix=".typ", encoding="utf-8") as file:
            file.write(source)
            file.flush()
            return [item["expression"] for item in MODULE.candidates(Path(file.name))]

    def test_finds_simple_and_parenthesized_subscripts(self):
        self.assertEqual(
            self.scan("$f_a(x) + Phi_(A)(z) + g_(i + 1)(t) + φ_n(x)$"),
            ["f_a(", "Phi_(A)(", "g_(i + 1)(", "φ_n("],
        )

    def test_accepts_spaced_indexed_calls(self):
        self.assertEqual(self.scan("$f_a (x) + Phi_(A) (z)$"), [])

    def test_ignores_typst_code_and_prose(self):
        source = """
        #let f_a(x) = x
        The text f_a(x) is not math.
        `"f_a(x)"`
        // $comment_a(x)$
        /* $blocked_a(x)$ */
        $"string_a(x)" + #code_a(x) + real_a(x)$
        """
        self.assertEqual(self.scan(source), ["real_a("])

    def test_handles_multiline_math_and_nested_subscript(self):
        source = """
        $
          h_(sigma(i))(x)
          + k_n(y)
        $
        """
        self.assertEqual(self.scan(source), ["h_(sigma(i))(", "k_n("])

    def test_ignores_unindexed_calls(self):
        self.assertEqual(self.scan("$clos(x) + abs(y) + f (z)$"), [])

    def test_ignores_binary_typ_suffixed_files(self):
        with tempfile.NamedTemporaryFile("wb", suffix=".typ") as file:
            file.write(b"Vim\x00binary\xff$f_a(x)$")
            file.flush()
            self.assertEqual(MODULE.candidates(Path(file.name)), [])

    def test_ignores_editor_state_paths(self):
        path = Path(
            "/Users/example/.local/state/nvim/undo/%Users%example%notes.typ"
        )
        self.assertTrue(MODULE.is_ignored_path(path))


class EventCursorTests(unittest.TestCase):
    def test_consumes_only_complete_records_after_cursor(self):
        first = b"/tmp/first.typ\0"
        data = first + b"/tmp/ignore.txt\0/tmp/second.typ"
        paths, offset = MODULE.pending_event_paths(data, 0)
        self.assertEqual(paths, [Path("/tmp/first.typ")])
        self.assertEqual(offset, len(first) + len(b"/tmp/ignore.txt\0"))

        completed = data + b"\0"
        paths, next_offset = MODULE.pending_event_paths(completed, offset)
        self.assertEqual(paths, [Path("/tmp/second.typ")])
        self.assertEqual(next_offset, len(completed))

    def test_invalid_or_truncated_cursor_restarts_safely(self):
        data = b"/tmp/file.typ\0"
        for offset in (-1, len(data) + 1, "bad"):
            with self.subTest(offset=offset):
                paths, next_offset = MODULE.pending_event_paths(data, offset)
                self.assertEqual(paths, [Path("/tmp/file.typ")])
                self.assertEqual(next_offset, len(data))

    def test_does_not_advance_past_partial_record(self):
        paths, offset = MODULE.pending_event_paths(b"/tmp/file.typ", 0)
        self.assertEqual(paths, [])
        self.assertEqual(offset, 0)


class StateWriteTests(unittest.TestCase):
    def test_concurrent_writes_use_distinct_temporary_files(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "session.json"
            states = [{"events_offset": offset} for offset in range(100)]

            with ThreadPoolExecutor(max_workers=8) as executor:
                list(executor.map(lambda state: MODULE.write_state(path, state), states))

            self.assertIn(json.loads(path.read_text(encoding="utf-8")), states)
            self.assertEqual(list(Path(directory).glob("*.tmp")), [])


if __name__ == "__main__":
    unittest.main()
