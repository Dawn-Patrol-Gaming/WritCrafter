"""Offline sanity checks for the addon (there's no Lua interpreter on this machine).

Not a full parser. It catches the mistakes that most often stop an ESO addon from loading:
  - unbalanced function/if/for/while/do/repeat blocks and brackets
  - C-style operators (!=, &&, ||) that Lua doesn't have
  - accidental globals (top-level assignments without `local`)
  - manifest entries that don't exist, and .lua files the manifest forgot

Usage: python -I scripts/check_lua.py
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "WritCrafter.addon"
ALLOWED_GLOBALS = {"WritCrafter"}
SKIP_DIRS = {".git", "docs", "scripts", "tests", ".claude"}

TOKEN = re.compile(
    r"""
    (?P<longcomment>--\[(?P<lceq>=*)\[.*?\](?P=lceq)\])
  | (?P<comment>--[^\n]*)
  | (?P<longstring>\[(?P<lseq>=*)\[.*?\](?P=lseq)\])
  | (?P<string>"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*')
  | (?P<badop>!=|&&|\|\|)
  | (?P<name>[A-Za-z_][A-Za-z0-9_]*)
  | (?P<bracket>[(){}\[\]])
  | (?P<newline>\n)
  | (?P<other>.)
    """,
    re.VERBOSE | re.DOTALL,
)

OPENERS = {"function", "if", "for", "while", "do", "repeat"}
PAIRS = {")": "(", "}": "{", "]": "["}


def check_file(path):
    errors = []
    text = path.read_text(encoding="utf-8")
    line = 1
    blocks = []      # (keyword, line)
    brackets = []    # (char, line)
    pending_do = 0   # `for`/`while` own the next `do`
    for m in TOKEN.finditer(text):
        kind = m.lastgroup
        value = m.group(kind)
        if kind in ("longcomment", "longstring"):
            line += value.count("\n")
            continue
        if kind == "newline":
            line += 1
            continue
        if kind == "badop":
            errors.append(f"{path.name}:{line}: '{value}' is not a Lua operator")
        elif kind == "bracket":
            if value in "({[":
                brackets.append((value, line))
            elif not brackets or brackets[-1][0] != PAIRS[value]:
                errors.append(f"{path.name}:{line}: unmatched '{value}'")
            else:
                brackets.pop()
        elif kind == "name":
            if value in ("for", "while"):
                blocks.append((value, line))
                pending_do += 1
            elif value == "do":
                if pending_do:
                    pending_do -= 1
                else:
                    blocks.append(("do", line))
            elif value in OPENERS:
                blocks.append((value, line))
            elif value == "end":
                if not blocks or blocks[-1][0] == "repeat":
                    errors.append(f"{path.name}:{line}: 'end' without an open block")
                else:
                    blocks.pop()
            elif value == "until":
                if not blocks or blocks[-1][0] != "repeat":
                    errors.append(f"{path.name}:{line}: 'until' without 'repeat'")
                else:
                    blocks.pop()
    for keyword, opened in blocks:
        errors.append(f"{path.name}:{opened}: '{keyword}' is never closed")
    for char, opened in brackets:
        errors.append(f"{path.name}:{opened}: '{char}' is never closed")

    # Top-level assignment to a bare name = a global.
    for number, raw in enumerate(text.splitlines(), 1):
        g = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=[^=]", raw)
        if g and g.group(1) not in ALLOWED_GLOBALS:
            errors.append(f"{path.name}:{number}: global assignment to '{g.group(1)}'")
    return errors


def manifest_files():
    files = []
    for raw in MANIFEST.read_text(encoding="utf-8").splitlines():
        entry = raw.strip()
        if entry and not entry.startswith((";", "#")):
            files.append(entry.replace("\\", "/"))
    return files


def main():
    errors = []
    listed = manifest_files()
    for entry in listed:
        if "$(" in entry:
            continue
        if not (ROOT / entry).is_file():
            errors.append(f"manifest: '{entry}' does not exist")
    on_disk = sorted(
        p.relative_to(ROOT).as_posix()
        for p in ROOT.rglob("*.lua")
        if not SKIP_DIRS.intersection(p.relative_to(ROOT).parts)
    )
    for rel in on_disk:
        if rel not in listed:
            errors.append(f"manifest: '{rel}' is not listed")
        errors.extend(check_file(ROOT / rel))
    for e in errors:
        print(e)
    print(f"{len(on_disk)} Lua files checked, {len(errors)} problem(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
