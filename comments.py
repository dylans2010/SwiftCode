#!/usr/bin/env python3
"""Strip all comments from Swift source files under swiftcode/Sources.

String-literal aware and interpolation-aware: // and /* */ inside
"...", \"\"\"...\"\"\", and raw strings (#"..."#, #\"\"\"...\"\"\"#) are
preserved, and comments inside \\(...) / \\#(...) string interpolations are
still stripped. Block comments keep their newline characters so line
numbers survive.
"""

import os
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "swiftcode", "Sources")
EXT = ".swift"


class Stripper:
    def __init__(self, text: str):
        self.s = text
        self.n = len(text)
        self.out: list[str] = []

    # ---------- low-level helpers ----------

    def emit(self, chunk: str) -> None:
        self.out.append(chunk)

    def skip_line_comment(self, i: int) -> int:
        # i points at '//'; consume through (not incl.) newline
        j = self.s.find("\n", i)
        return self.n if j == -1 else j

    def skip_block_comment(self, i: int) -> int:
        # i points at '/*'; returns index after matching '*/' (nesting aware)
        depth = 0
        j = i
        while j < self.n:
            if self.s.startswith("/*", j):
                depth += 1
                j += 2
            elif self.s.startswith("*/", j):
                depth -= 1
                j += 2
                if depth == 0:
                    return j
            else:
                j += 1
        return self.n

    # ---------- string handling ----------

    def string_end(self, i: int):
        """i is just past the opening delimiter. Returns (end_index, kind)
        where end_index is just past the closing delimiter, or None if EOF."""
        s, n = self.s, self.n
        # determine delimiter already consumed by caller; we re-derive:
        raise NotImplementedError

    def consume_string(self, i: int) -> int:
        """i points at the start of a string literal (quote or hashes+quote).
        Appends the literal to output with interpolation comments stripped.
        Returns index just past the literal."""
        s, n = self.s, self.n
        start = i
        hashes = 0
        while i < n and s[i] == "#":
            hashes += 1
            i += 1
        multiline = s.startswith('"""', i)
        i += 3 if multiline else 1
        # emit opening delimiter verbatim
        self.emit(s[start:i])
        interp_hashes = hashes  # interpolation introducer is '\' + hashes + '('

        while i < n:
            c = s[i]
            # interpolation: backslash + `hashes` '#' + '('
            if c == "\\":
                j = i + 1
                k = 0
                while k < hashes and j < n and s[j] == "#":
                    j += 1
                    k += 1
                if k == hashes and j < n and s[j] == "(":
                    self.emit(s[i:j + 1])
                    i = self.consume_interpolation(j + 1)
                    continue
                # ordinary escape (or raw string without matching hashes): copy 2 chars
                self.emit(s[i:i + 2] if i + 1 < n else s[i:i + 1])
                i += 2 if i + 1 < n else 1
                continue
            # terminator
            if multiline:
                if s.startswith('"""' + "#" * hashes, i):
                    self.emit('"""' + "#" * hashes)
                    return i + 3 + hashes
            else:
                if s.startswith('"' + "#" * hashes, i):
                    self.emit('"' + "#" * hashes)
                    return i + 1 + hashes
            self.emit(c)
            i += 1
        return n

    def consume_interpolation(self, i: int) -> int:
        """i is just past '('. Lexes code until the matching ')' at depth 0,
        stripping comments. Returns index just past ')'."""
        depth = 1
        while i < self.n:
            c = self.s[i]
            nxt = self.s[i + 1] if i + 1 < self.n else ""
            if c == "/" and nxt == "/":
                j = self.skip_line_comment(i)
                if j < self.n:
                    self.emit("\n")
                i = j
                continue
            if c == "/" and nxt == "*":
                seg = self.s[i:self.skip_block_comment(i)]
                if "\n" in seg:
                    self.emit("\n" * seg.count("\n"))
                else:
                    self.emit(" ")
                i = self.skip_block_comment(i)
                continue
            if c == '"' or (c == "#" and self._starts_string(i)):
                i = self.consume_string(i)
                continue
            if c == "(":
                depth += 1
            elif c == ")":
                depth -= 1
                if depth == 0:
                    self.emit(")")
                    return i + 1
            self.emit(c)
            i += 1
        return self.n

    def _starts_string(self, i: int) -> bool:
        j = i
        while j < self.n and self.s[j] == "#":
            j += 1
        return j < self.n and self.s[j] == '"'

    # ---------- main ----------

    def run(self) -> str:
        s, n = self.s, self.n
        i = 0
        while i < n:
            c = s[i]
            nxt = s[i + 1] if i + 1 < n else ""
            if c == "/" and nxt == "/":
                j = self.skip_line_comment(i)
                if j < n:
                    self.emit("\n")
                i = j
                continue
            if c == "/" and nxt == "*":
                j = self.skip_block_comment(i)
                seg = s[i:j]
                self.emit("\n" * seg.count("\n") if "\n" in seg else " ")
                i = j
                continue
            if c == '"' or (c == "#" and self._starts_string(i)):
                i = self.consume_string(i)
                continue
            self.emit(c)
            i += 1
        return "".join(self.out)


def strip_comments(text: str) -> str:
    return Stripper(text).run()


def main() -> int:
    changed = 0
    for dirpath, _dirs, files in os.walk(ROOT):
        for name in files:
            if not name.endswith(EXT):
                continue
            path = os.path.join(dirpath, name)
            with open(path, "r", encoding="utf-8") as f:
                src = f.read()
            stripped = strip_comments(src)
            if stripped != src:
                with open(path, "w", encoding="utf-8") as f:
                    f.write(stripped)
                changed += 1
    print(f"{changed} file(s) updated")
    return 0


if __name__ == "__main__":
    sys.exit(main())
