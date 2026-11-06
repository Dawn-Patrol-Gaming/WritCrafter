"""Offline sanity checks for the addon (there's no Lua interpreter on this machine).

Not a full parser. It catches the mistakes that most often stop an ESO addon from loading:
  - unbalanced function/if/for/while/do/repeat blocks and brackets
  - strings left open at the end of a line
  - C-style operators (!=, &&, ||) that Lua doesn't have
  - accidental globals (top-level assignments without `local`)
  - manifest entries that don't exist, and .lua files the manifest forgot
  - SecurePostHook on a control (it only accepts tables)
  - tonumber() wrapped directly around a call, which throws when the call returns nothing
  - `local a, b = x and f()`: and/or keep only a call's first value, so b is always nil

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
  | (?P<badstring>["'])
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
        if kind == "badstring":
            errors.append(f"{path.name}:{line}: string never closed on this line (write line breaks as \\n)")
        elif kind == "badop":
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

    # A local function called on a line above its definition, with no forward declaration
    # ("local Name" on its own) above the call: Lua resolves that call to a missing global.
    lines = text.splitlines()
    for number, raw in enumerate(lines, 1):
        d = re.match(r"^\s*local\s+function\s+([A-Za-z_]\w*)\s*\(", raw)
        if not d:
            continue
        name = d.group(1)
        call = re.compile(r"(?<![\w.:])" + re.escape(name) + r"\s*\(")
        declared = re.compile(r"^\s*local\s+" + re.escape(name) + r"\s*$")
        for earlier, line_text in enumerate(lines[:number - 1], 1):
            if declared.match(line_text):
                break
            code = line_text.split("--", 1)[0]
            if call.search(code):
                errors.append(f"{path.name}:{earlier}: calls local function '{name}' before it's defined (line {number})")
                break

    for number, raw in enumerate(text.splitlines(), 1):
        # Top-level assignment to a bare name = a global.
        g = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=[^=]", raw)
        if g and g.group(1) not in ALLOWED_GLOBALS:
            errors.append(f"{path.name}:{number}: global assignment to '{g.group(1)}'")
        code = raw.split("--", 1)[0]
        # SecurePostHook only takes tables; tooltips and other controls are userdata.
        h = re.search(r"SecurePostHook\(\s*([A-Za-z_]\w*(?:Tooltip|Control|Window)\b)", code)
        if h:
            errors.append(f"{path.name}:{number}: SecurePostHook on control '{h.group(1)}'; use ZO_PostHook")
        # A call that returns nothing (bare `return`, select() past the end) makes tonumber throw.
        if re.search(r"\btonumber\(\s*[A-Za-z_][\w.:]*\(", code):
            errors.append(f"{path.name}:{number}: tonumber() of a call result; capture it in a local first")
        # `a, b = x and f()`: and/or truncate the call to one value, so b is always nil.
        m = re.match(r"^\s*(?:local\s+)?[A-Za-z_][\w.]*\s*,\s*[A-Za-z_][\w.,\s]*=\s*(.*)$", code)
        if m and re.search(r"\b(?:and|or)\s+[A-Za-z_][\w.:]*\(", m.group(1)) and "{" not in m.group(1):
            errors.append(f"{path.name}:{number}: several values from 'x and f()'; and/or keep only the first, use an if")
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
