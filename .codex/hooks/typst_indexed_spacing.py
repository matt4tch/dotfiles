#!/usr/bin/env python3
"""Block Codex completion when edited Typst math violates source conventions."""

from __future__ import annotations

import json
import os
from pathlib import Path
import re
import shutil
import shlex
import signal
import subprocess
import sys
import tempfile
import time


HOME = Path.home()
STATE_DIR = HOME / ".codex" / "hook-state" / "typst-indexed-spacing"


def find_fswatch() -> Path:
    """Prefer the declarative Home Manager package, then fall back to PATH."""
    profile_candidates = (
        HOME / ".nix-profile" / "bin" / "fswatch",
        HOME / ".local" / "state" / "nix" / "profiles" / "profile" / "bin" / "fswatch",
    )
    for candidate in profile_candidates:
        if candidate.is_file():
            return candidate.resolve()
    executable = shutil.which("fswatch")
    return Path(executable).resolve() if executable else profile_candidates[0]


FSWATCH = find_fswatch()
WATCH_ROOT = HOME
IGNORED_PATH_PARTS = {
    ".cache",
    ".git",
    ".local",
    ".venv",
    "Library",
    "node_modules",
    "target",
    "venv",
}
BASE_PATTERN = re.compile(r"(?<![#\w])([^\W\d_][^\W_]*)_", re.UNICODE)
SAFE_SESSION_ID = re.compile(r"^[A-Za-z0-9-]+$")


def read_event() -> dict:
    try:
        value = json.load(sys.stdin)
    except json.JSONDecodeError as error:
        raise RuntimeError(f"invalid hook input: {error}") from error
    if not isinstance(value, dict):
        raise RuntimeError("hook input must be a JSON object")
    return value


def state_path(event: dict) -> Path:
    session_id = event.get("session_id")
    if not isinstance(session_id, str) or not SAFE_SESSION_ID.fullmatch(session_id):
        raise RuntimeError("hook input has no safe session_id")
    return STATE_DIR / f"{session_id}.json"


def math_mask(text: str) -> bytearray:
    """Mark characters in Typst math, excluding comments, strings, and raw text."""
    mask = bytearray(len(text))
    in_math = False
    index = 0

    while index < len(text):
        if text.startswith("//", index):
            newline = text.find("\n", index + 2)
            index = len(text) if newline < 0 else newline + 1
            continue

        if text.startswith("/*", index):
            depth = 1
            index += 2
            while index < len(text) and depth:
                if text.startswith("/*", index):
                    depth += 1
                    index += 2
                elif text.startswith("*/", index):
                    depth -= 1
                    index += 2
                else:
                    index += 1
            continue

        if text[index] == '"':
            index += 1
            while index < len(text):
                if text[index] == "\\":
                    index += 2
                elif text[index] == '"':
                    index += 1
                    break
                else:
                    index += 1
            continue

        if text[index] == "`":
            ticks = 1
            while index + ticks < len(text) and text[index + ticks] == "`":
                ticks += 1
            delimiter = "`" * ticks
            end = text.find(delimiter, index + ticks)
            index = len(text) if end < 0 else end + ticks
            continue

        if text[index] == "$" and (index == 0 or text[index - 1] != "\\"):
            in_math = not in_math
            index += 1
            continue

        if in_math:
            mask[index] = 1
        index += 1

    return mask


def padded_math_string_candidates(path: Path, text: str) -> list[dict]:
    """Find quoted math text with whitespace inside either quotation mark."""
    findings: list[dict] = []
    in_math = False
    index = 0

    while index < len(text):
        if text.startswith("//", index):
            newline = text.find("\n", index + 2)
            index = len(text) if newline < 0 else newline + 1
            continue

        if text.startswith("/*", index):
            depth = 1
            index += 2
            while index < len(text) and depth:
                if text.startswith("/*", index):
                    depth += 1
                    index += 2
                elif text.startswith("*/", index):
                    depth -= 1
                    index += 2
                else:
                    index += 1
            continue

        if text[index] == "`":
            ticks = 1
            while index + ticks < len(text) and text[index + ticks] == "`":
                ticks += 1
            delimiter = "`" * ticks
            end = text.find(delimiter, index + ticks)
            index = len(text) if end < 0 else end + ticks
            continue

        if text[index] == "$" and (index == 0 or text[index - 1] != "\\"):
            in_math = not in_math
            index += 1
            continue

        if text[index] == '"':
            quote_start = index
            index += 1
            content_start = index
            while index < len(text):
                if text[index] == "\\":
                    index += 2
                elif text[index] == '"':
                    break
                else:
                    index += 1

            if index < len(text) and in_math:
                content = text[content_start:index]
                if content and (content[0].isspace() or content[-1].isspace()):
                    line = text.count("\n", 0, quote_start) + 1
                    line_start = text.rfind("\n", 0, quote_start) + 1
                    line_end = text.find("\n", index)
                    if line_end < 0:
                        line_end = len(text)
                    findings.append(
                        {
                            "path": str(path),
                            "line": line,
                            "column": quote_start - line_start + 1,
                            "expression": text[quote_start : index + 1],
                            "context": text[line_start:line_end].strip(),
                            "rule": "padded-math-string",
                        }
                    )
            index += 1
            continue

        index += 1

    return findings


def balanced_subscript_end(text: str, start: int, mask: bytearray) -> int | None:
    if start >= len(text) or text[start] != "(" or not mask[start]:
        return None
    depth = 0
    index = start
    while index < len(text) and mask[index]:
        if text[index] == "(":
            depth += 1
        elif text[index] == ")":
            depth -= 1
            if depth == 0:
                return index + 1
        index += 1
    return None


def is_ignored_path(path: Path) -> bool:
    return any(part in IGNORED_PATH_PARTS for part in path.parts)


def read_typst_source(path: Path) -> str | None:
    """Return valid Typst source, ignoring editor state and other binary files."""
    if is_ignored_path(path):
        return None
    data = path.read_bytes()
    if b"\0" in data:
        return None
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        return None


def candidates(path: Path) -> list[dict]:
    text = read_typst_source(path)
    if text is None:
        return []
    mask = math_mask(text)
    findings = padded_math_string_candidates(path, text)

    for match in BASE_PATTERN.finditer(text):
        start = match.start()
        if not mask[start]:
            continue

        subscript_start = match.end()
        if subscript_start >= len(text):
            continue

        if text[subscript_start] == "(":
            end = balanced_subscript_end(text, subscript_start, mask)
            if end is None:
                continue
        else:
            end = subscript_start
            while (
                end < len(text)
                and mask[end]
                and (text[end].isalnum() or text[end] in "'′")
            ):
                end += 1
            if end == subscript_start:
                continue

        if end >= len(text) or text[end] != "(" or not mask[end]:
            continue

        line = text.count("\n", 0, start) + 1
        line_start = text.rfind("\n", 0, start) + 1
        line_end = text.find("\n", end)
        if line_end < 0:
            line_end = len(text)
        column = start - line_start + 1
        findings.append(
            {
                "path": str(path),
                "line": line,
                "column": column,
                "expression": text[start : end + 1],
                "context": text[line_start:line_end].strip(),
                "rule": "indexed-call",
            }
        )

    return findings


def block(reason: str) -> None:
    print(json.dumps({"decision": "block", "reason": reason}))


def watcher_paths(path: Path) -> tuple[Path, Path]:
    return path.with_suffix(".events"), path.with_suffix(".stderr")


def write_state(path: Path, state: dict) -> None:
    temporary_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=path.parent,
            prefix=f".{path.name}.",
            suffix=".tmp",
            delete=False,
        ) as temporary:
            temporary_path = Path(temporary.name)
            json.dump(state, temporary, sort_keys=True)
        temporary_path.replace(path)
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)


def pending_event_paths(data: bytes, offset: int) -> tuple[list[Path], int]:
    """Return complete fswatch records after offset and their commit position."""
    if not isinstance(offset, int) or offset < 0 or offset > len(data):
        offset = 0
    pending = data[offset:]
    last_separator = pending.rfind(b"\0")
    if last_separator < 0:
        return [], offset
    complete = pending[:last_separator]
    committed_offset = offset + last_separator + 1
    paths = [
        Path(raw.decode("utf-8", errors="surrogateescape"))
        for raw in complete.split(b"\0")
        if raw and raw.endswith(b".typ")
    ]
    return paths, committed_offset


def process_is_watcher(pid: int) -> bool:
    try:
        result = subprocess.run(
            ["/bin/ps", "-p", str(pid), "-o", "command="],
            check=False,
            capture_output=True,
            text=True,
            timeout=2,
        )
    except (OSError, subprocess.SubprocessError):
        return False
    if result.returncode != 0:
        return False
    try:
        command = shlex.split(result.stdout.strip())
    except ValueError:
        return False
    if not command:
        return False
    return (
        Path(command[0]).name == "fswatch"
        and "--print0" in command
        and "--recursive" in command
        and str(WATCH_ROOT) in command
    )


def stop_watcher(state: dict) -> None:
    pid = state.get("pid")
    if not isinstance(pid, int) or not process_is_watcher(pid):
        return
    try:
        os.killpg(pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    for _ in range(20):
        if not process_is_watcher(pid):
            return
        time.sleep(0.05)
    try:
        os.killpg(pid, signal.SIGKILL)
    except ProcessLookupError:
        pass


def cleanup(path: Path, state: dict | None = None) -> None:
    if state is None and path.exists():
        try:
            state = json.loads(path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            state = None
    if state is not None:
        stop_watcher(state)
    events_path, stderr_path = watcher_paths(path)
    path.unlink(missing_ok=True)
    events_path.unlink(missing_ok=True)
    stderr_path.unlink(missing_ok=True)


def start(event: dict) -> int:
    path = state_path(event)
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    cleanup(path)
    if not FSWATCH.is_file():
        raise RuntimeError(f"fswatch is unavailable at {FSWATCH}")

    events_path, stderr_path = watcher_paths(path)
    events_file = events_path.open("wb")
    stderr_file = stderr_path.open("wb")
    try:
        watcher = subprocess.Popen(
            [
                str(FSWATCH),
                "--print0",
                "--recursive",
                "--extended",
                "--latency",
                "0.1",
                str(WATCH_ROOT),
            ],
            stdin=subprocess.DEVNULL,
            stdout=events_file,
            stderr=stderr_file,
            start_new_session=True,
        )
    finally:
        events_file.close()
        stderr_file.close()

    state = {
        "pid": watcher.pid,
        "watch_root": str(WATCH_ROOT),
        "events_path": str(events_path),
        "stderr_path": str(stderr_path),
        "events_offset": 0,
    }
    write_state(path, state)
    time.sleep(0.15)
    if watcher.poll() is not None:
        details = stderr_path.read_text(encoding="utf-8", errors="replace").strip()
        cleanup(path, state)
        raise RuntimeError(f"fswatch exited during startup: {details or watcher.returncode}")
    return 0


def stop(event: dict) -> int:
    path = state_path(event)
    if not path.exists():
        start(event)
        block(
            "Typst indexed-spacing guard restored its missing session baseline. "
            "Continue once so the mandatory guard can verify subsequent edits."
        )
        return 0

    state = json.loads(path.read_text(encoding="utf-8"))
    pid = state.get("pid")
    if not isinstance(pid, int) or not process_is_watcher(pid):
        _, stderr_path = watcher_paths(path)
        details = (
            stderr_path.read_text(encoding="utf-8", errors="replace").strip()
            if stderr_path.exists()
            else ""
        )
        start(event)
        block(
            "Typst indexed-spacing filesystem watcher stopped unexpectedly; "
            "the guard restored a fresh session baseline. Continue once so it "
            "can verify subsequent edits."
            + (f"\n{details}" if details else "")
        )
        return 0

    time.sleep(0.25)
    events_path, _ = watcher_paths(path)
    event_data = events_path.read_bytes() if events_path.exists() else b""
    raw_changed, committed_offset = pending_event_paths(
        event_data, state.get("events_offset", 0)
    )
    changed = sorted(set(raw_changed))

    findings: list[dict] = []
    failures: list[str] = []
    for changed_path in changed:
        if not changed_path.is_file():
            continue
        try:
            findings.extend(candidates(changed_path))
        except (UnicodeDecodeError, PermissionError, OSError) as error:
            failures.append(f"{changed_path}: {error}")

    if failures:
        block(
            "The Typst indexed-spacing guard could not scan every changed file:\n"
            + "\n".join(failures)
        )
        return 0

    if findings:
        lines = [
            "Typst source review failed.",
            "Inspect and fix every candidate. Use `f_a (x)` for indexed calls, "
            "and remove padding inside quoted math text such as `\" text \"`.",
            "",
        ]
        for finding in findings[:100]:
            lines.append(
                f"{finding['path']}:{finding['line']}:{finding['column']}: "
                f"{finding['expression']}"
            )
            lines.append(f"  {finding['context']}")
        if len(findings) > 100:
            lines.append(f"... plus {len(findings) - 100} more candidates")
        block("\n".join(lines))
        return 0

    state["events_offset"] = committed_offset
    write_state(path, state)
    return 0


def end(event: dict) -> int:
    cleanup(state_path(event))
    return 0


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] not in {"start", "stop", "end"}:
        print("usage: typst_indexed_spacing.py {start|stop|end}", file=sys.stderr)
        return 2
    try:
        event = read_event()
        if sys.argv[1] == "start":
            return start(event)
        if sys.argv[1] == "stop":
            return stop(event)
        return end(event)
    except Exception as error:
        if sys.argv[1] == "stop":
            block(f"Typst indexed-spacing guard failed closed: {error}")
            return 0
        print(f"Typst indexed-spacing guard failed: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
