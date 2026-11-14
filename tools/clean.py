#!/usr/bin/env python3
import argparse
import difflib
import os
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

DEFAULT_SCAN_DIRS = ("swiftcode", "frameworks", "composer")

EXCLUDED_DIR_NAMES = {
    ".git",
    ".build",
    "build",
    "DerivedData",
    "node_modules",
    "Pods",
    "xcuserdata",
    "research",
    ".agents",
    ".swiftpm",
    "__pycache__",
    ".pytest_cache",
    ".mypy_cache",
    ".venv",
    "venv",
    "dist",
}

EXCLUDED_PATH_SEGMENTS = {"third-party", "thirdparty", "vendored", "generated"}

LICENSE_WORDS = ("license", "copyright", "spdx")

EXPRESSION_KEYWORDS = {
    "return", "throw", "try", "await", "case", "in", "where",
    "guard", "if", "while", "for", "switch", "catch", "do", "else",
    "repeat", "defer", "some", "any", "inout", "borrowing", "consuming",
    "isolated",
}

REGEX_ALLOW_CHARS = set("([{,;:?&|~=<>+-*%^/")


class StripError(Exception):
    pass


def is_word_char(ch):
    return ch.isalnum() or ch == "_" or ch == "$"


def leading_block_end(text, start):
    depth = 0
    j = start
    n = len(text)
    while j < n:
        if text.startswith("/*", j):
            depth += 1
            j += 2
        elif text.startswith("*/", j):
            depth -= 1
            j += 2
            if depth == 0:
                return j
        else:
            j += 1
    return n


def preserved_prefix(text):
    n = len(text)
    i = 0
    while i < n and text[i] in " \t\r\n":
        i += 1
    prefix = 0
    if text.startswith("// swift-tools-version:", i):
        j = text.find("\n", i)
        prefix = n if j == -1 else j + 1
        i = prefix
        while i < n and text[i] in " \t\r\n":
            i += 1
    j = i
    saw_comment = False
    while j < n:
        if text.startswith("//", j):
            saw_comment = True
            k = text.find("\n", j)
            j = n if k == -1 else k + 1
        elif text.startswith("/*", j):
            saw_comment = True
            j = leading_block_end(text, j)
        elif text[j] in " \t\r\n":
            j += 1
        else:
            break
    if saw_comment:
        head = text[i:j].lower()
        if any(word in head for word in LICENSE_WORDS):
            return j
    return prefix


class Stripper:
    def __init__(self, text):
        self.s = text
        self.n = len(text)
        self.out = []
        self.comment_count = 0
        self._cur_word = ""
        self._prev_word = ""
        self._prev_sig = None

    def _note(self, chunk):
        for ch in chunk:
            if is_word_char(ch):
                if len(self._cur_word) < 64:
                    self._cur_word += ch
                self._prev_sig = ch
            else:
                if self._cur_word:
                    self._prev_word = self._cur_word
                    self._cur_word = ""
                if ch not in " \t\r\n":
                    self._prev_sig = ch

    def emit(self, chunk):
        if chunk:
            self._note(chunk)
            self.out.append(chunk)

    def skip_line_comment(self, i):
        j = self.s.find("\n", i)
        return self.n if j == -1 else j

    def skip_block_comment(self, i):
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
        raise StripError("unterminated block comment")

    def _starts_string(self, i):
        j = i
        while j < self.n and self.s[j] == "#":
            j += 1
        return j < self.n and self.s[j] == '"'

    def _starts_regex(self, i):
        j = i
        while j < self.n and self.s[j] == "#":
            j += 1
        return j < self.n and self.s[j] == "/"

    def _regex_allowed(self):
        sig = self._prev_sig
        if sig is None:
            return True
        if sig in REGEX_ALLOW_CHARS:
            return True
        if is_word_char(sig):
            word = self._cur_word if self._cur_word else self._prev_word
            return word in EXPRESSION_KEYWORDS
        return False

    def consume_regex(self, i):
        s = self.s
        n = self.n
        hashes = 0
        j = i
        while j < n and s[j] == "#":
            hashes += 1
            j += 1
        k = j + 1
        in_class = False
        while k < n:
            ch = s[k]
            if ch == "\n":
                return None
            if ch == "\\" and k + 1 < n:
                k += 2
                continue
            if ch == "[" and not in_class:
                in_class = True
                k += 1
                if k < n and s[k] == "^":
                    k += 1
                if k < n and s[k] == "]":
                    k += 1
                continue
            if ch == "]" and in_class:
                in_class = False
                k += 1
                continue
            if ch == "/" and not in_class:
                if hashes == 0:
                    self.emit(s[i:k + 1])
                    return k + 1
                if s.startswith("#" * hashes, k + 1):
                    self.emit(s[i:k + 1 + hashes])
                    return k + 1 + hashes
                k += 1
                continue
            k += 1
        return None

    def consume_string(self, i):
        s = self.s
        n = self.n
        start = i
        hashes = 0
        while i < n and s[i] == "#":
            hashes += 1
            i += 1
        multiline = s.startswith('"""', i)
        i += 3 if multiline else 1
        self.emit(s[start:i])
        while i < n:
            c = s[i]
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
                self.emit(s[i:i + 2] if i + 1 < n else s[i:i + 1])
                i += 2 if i + 1 < n else 1
                continue
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
        raise StripError("unterminated string literal")

    def consume_interpolation(self, i):
        depth = 1
        while i < self.n:
            c = self.s[i]
            nxt = self.s[i + 1] if i + 1 < self.n else ""
            if c == "/" and nxt == "/":
                self.comment_count += 1
                j = self.skip_line_comment(i)
                i = j
                continue
            if c == "/" and nxt == "*":
                self.comment_count += 1
                j = self.skip_block_comment(i)
                seg = self.s[i:j]
                if "\n" in seg:
                    self.emit("\n" * seg.count("\n"))
                else:
                    self.emit(" ")
                i = j
                continue
            if c == '"' or (c == "#" and self._starts_string(i)):
                i = self.consume_string(i)
                continue
            if c == "#" and self._starts_regex(i):
                end = self.consume_regex(i)
                if end is not None:
                    i = end
                    continue
                self.emit(c)
                i += 1
                continue
            if c == "/" and self._regex_allowed():
                end = self.consume_regex(i)
                if end is not None:
                    i = end
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
        raise StripError("unterminated string interpolation")

    def run(self):
        s = self.s
        n = self.n
        i = 0
        while i < n:
            c = s[i]
            nxt = s[i + 1] if i + 1 < n else ""
            if c == "/" and nxt == "/":
                self.comment_count += 1
                j = self.skip_line_comment(i)
                i = j
                continue
            if c == "/" and nxt == "*":
                self.comment_count += 1
                j = self.skip_block_comment(i)
                seg = s[i:j]
                if "\n" in seg:
                    self.emit("\n" * seg.count("\n"))
                else:
                    self.emit(" ")
                i = j
                continue
            if c == '"' or (c == "#" and self._starts_string(i)):
                i = self.consume_string(i)
                continue
            if c == "#" and self._starts_regex(i):
                end = self.consume_regex(i)
                if end is not None:
                    i = end
                    continue
                self.emit(c)
                i += 1
                continue
            if c == "/" and self._regex_allowed():
                end = self.consume_regex(i)
                if end is not None:
                    i = end
                    continue
            self.emit(c)
            i += 1
        return "".join(self.out)


def strip_text(text):
    prefix = preserved_prefix(text)
    stripper = Stripper(text[prefix:])
    body = stripper.run()
    return text[:prefix] + body, stripper.comment_count


def is_excluded_dir(name):
    if name in EXCLUDED_DIR_NAMES:
        return True
    if name.startswith("."):
        return True
    if name.lower().startswith("vendor"):
        return True
    return name.lower() in EXCLUDED_PATH_SEGMENTS


def collect_files(scan_dirs):
    found = []
    skipped = []
    for base in scan_dirs:
        if not os.path.isdir(base):
            continue
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames[:] = [d for d in dirnames if not is_excluded_dir(d)]
            rel_dir = os.path.relpath(dirpath, REPO_ROOT)
            parts = [] if rel_dir == "." else rel_dir.split(os.sep)
            if any(p.lower() in EXCLUDED_PATH_SEGMENTS for p in parts):
                dirnames[:] = []
                continue
            for name in filenames:
                if not name.endswith(".swift"):
                    continue
                path = os.path.join(dirpath, name)
                rel = os.path.relpath(path, REPO_ROOT)
                if name.endswith(".generated.swift"):
                    skipped.append((rel, "generated file"))
                    continue
                if os.path.islink(path):
                    skipped.append((rel, "symbolic link"))
                    continue
                if any(p.lower() in EXCLUDED_PATH_SEGMENTS for p in rel.split(os.sep)):
                    skipped.append((rel, "excluded path segment"))
                    continue
                found.append(path)
    return sorted(found), skipped


def resolve_scan_dirs(target):
    if target is None:
        return [os.path.join(REPO_ROOT, d) for d in DEFAULT_SCAN_DIRS]
    resolved = os.path.abspath(target)
    if not os.path.isdir(resolved):
        print("target is not a directory: " + resolved, file=sys.stderr)
        return None
    try:
        common = os.path.commonpath([resolved, REPO_ROOT])
    except ValueError:
        common = ""
    if common != REPO_ROOT:
        print("target is outside the repository: " + resolved, file=sys.stderr)
        return None
    return [resolved]


def main():
    parser = argparse.ArgumentParser(
        description="Remove comments from SwiftCode Swift sources while preserving code, strings, and line numbers.")
    parser.add_argument("--target", default=None,
                        help="Directory to scan; must be inside the repository (default: swiftcode/, frameworks/, composer/)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Report files that would change without modifying them")
    parser.add_argument("--check", action="store_true",
                        help="Exit 1 if any file still contains strippable comments; change nothing")
    parser.add_argument("--diff", action="store_true",
                        help="Show unified diffs for files that would change")
    parser.add_argument("--verbose", "-v", action="store_true",
                        help="Report per-file comment counts and skipped files")
    args = parser.parse_args()

    scan_dirs = resolve_scan_dirs(args.target)
    if scan_dirs is None:
        return 2

    files, skipped = collect_files(scan_dirs)
    read_only = args.dry_run or args.check
    verb = "Would modify" if read_only else "Modified"

    scanned = 0
    modified = 0
    removed_total = 0
    failures = []

    for path in files:
        rel = os.path.relpath(path, REPO_ROOT)
        try:
            with open(path, "rb") as handle:
                raw = handle.read()
        except OSError as exc:
            failures.append((rel, "cannot read file: " + str(exc)))
            continue
        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError:
            failures.append((rel, "not valid UTF-8"))
            continue
        scanned += 1
        try:
            stripped, count = strip_text(text)
        except StripError as exc:
            failures.append((rel, str(exc)))
            continue
        if stripped != text:
            modified += 1
            removed_total += count
            if args.verbose:
                print(verb + ": " + rel + " (" + str(count) + " comments removed)")
            else:
                print(verb + ": " + rel)
            if args.diff:
                diff = difflib.unified_diff(
                    text.splitlines(keepends=True),
                    stripped.splitlines(keepends=True),
                    fromfile="a/" + rel,
                    tofile="b/" + rel)
                sys.stdout.writelines(diff)
            if not read_only:
                try:
                    with open(path, "w", encoding="utf-8", newline="") as handle:
                        handle.write(stripped)
                except OSError as exc:
                    failures.append((rel, "cannot write file: " + str(exc)))

    if args.verbose:
        for rel, reason in skipped:
            print("Skipped: " + rel + " (" + reason + ")")

    for rel, reason in failures:
        print("Failed: " + rel + ": " + reason, file=sys.stderr)

    if args.dry_run:
        summary = ("Dry run: scanned " + str(scanned) + " files; would modify "
                   + str(modified) + " files; would remove " + str(removed_total) + " comments")
    elif args.check:
        summary = ("Check: scanned " + str(scanned) + " files; " + str(modified)
                   + " files still contain strippable comments; " + str(removed_total)
                   + " comments found")
    else:
        summary = ("Scanned " + str(scanned) + " files; modified " + str(modified)
                   + " files; removed " + str(removed_total) + " comments")
    if failures:
        summary += "; " + str(len(failures)) + " files failed"
    print(summary)

    if failures:
        return 1
    if args.check and modified > 0:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
