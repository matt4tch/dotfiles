#!/usr/bin/env python3

import importlib.util
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


if __name__ == "__main__":
    unittest.main()
