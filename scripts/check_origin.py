r"""Looks for code WritCrafter may share with other add-ons.

Usage: python -I scripts\check_origin.py <writcrafter dir> <reference dir> [<reference dir> ...]

Four checks, each reported with file:line on both sides:
  1. exact token runs: RUN_EXACT tokens in a row identical (comments dropped, strings kept)
  2. shape runs: RUN_SHAPE tokens in a row identical after renaming every identifier to ID,
     every number to N and every string to S (catches copied code with renamed variables)
  3. distinctive lines: a whole non-trivial line identical after whitespace normalisation
  4. number runs: NUM_RUN numbers (5+ digits, i.e. item IDs) appearing in the same order
"""
import os
import re
import sys
from collections import defaultdict

RUN_EXACT = 18
RUN_SHAPE = 28
NUM_RUN = 5
MIN_LINE_LEN = 40

TOKEN = re.compile(
    r'--\[(=*)\[.*?\]\1\]'            # long comment
    r'|--[^\n]*'                       # line comment
    r'|\[(=*)\[.*?\]\2\]'              # long string
    r'|"(?:\\.|[^"\\\n])*"'
    r"|'(?:\\.|[^'\\\n])*'"
    r'|0[xX][0-9a-fA-F]+|\d+\.?\d*(?:[eE][-+]?\d+)?'
    r'|[A-Za-z_][A-Za-z0-9_]*'
    r'|\.\.\.|\.\.|==|~=|<=|>=|::|[^\s]',
    re.S)
KEYWORDS = set('and break do else elseif end false for function goto if in local nil not or '
               'repeat return then true until while'.split())


def tokens(text):
    """[(kind, value, line)] without comments."""
    out = []
    for m in TOKEN.finditer(text):
        value = m.group(0)
        if value.startswith('--'):
            continue
        line = text.count('\n', 0, m.start()) + 1
        if value[0] in '"\'' or value.startswith('[['):
            kind = 'S'
        elif value[0].isdigit():
            kind = 'N'
        elif re.match(r'[A-Za-z_]', value):
            kind = 'K' if value in KEYWORDS else 'ID'
        else:
            kind = 'P'
        out.append((kind, value, line))
    return out


def lua_files(root):
    for folder, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in ('.git', 'docs', 'scripts', '__pycache__')]
        for name in files:
            if name.lower().endswith('.lua'):
                yield os.path.join(folder, name)


def load(root):
    result = {}
    for path in lua_files(root):
        with open(path, encoding='utf-8', errors='replace') as f:
            text = f.read()
        result[path] = (text, tokens(text))
    return result


LOGIC = {'if', 'then', 'for', 'while', 'return', 'elseif', 'else', 'function', 'repeat', 'until'}


def is_logic(window):
    """Real code, not a table of data: several control-flow keywords and few table commas."""
    words = sum(1 for k, v, _ in window if k == 'K' and v in LOGIC)
    commas = sum(1 for k, v, _ in window if v == ',')
    return words >= 4 and commas <= len(window) // 8


def runs(toks, size, shape):
    for i in range(len(toks) - size + 1):
        window = toks[i:i + size]
        if shape:
            if not is_logic(window):
                continue
            key = tuple(v if k in ('K', 'P') else k for k, v, _ in window)
        else:
            key = tuple(v for _, v, _ in window)
        yield key, window[0][2], window[-1][2]


def index_runs(files, size, shape):
    idx = defaultdict(list)
    for path, (_, toks) in files.items():
        for key, a, b in runs(toks, size, shape):
            idx[key].append((path, a, b))
    return idx


def merge(hits):
    """Collapse overlapping (ours, theirs) line ranges into spans."""
    hits.sort()
    merged = []
    for h in hits:
        if merged and h[0] == merged[-1][0] and h[3] == merged[-1][3] and h[1] <= merged[-1][2] + 1:
            last = merged[-1]
            merged[-1] = (last[0], last[1], max(last[2], h[2]), last[3], min(last[4], h[4]), max(last[5], h[5]))
        else:
            merged.append(h)
    return merged


def short(path, roots):
    for r in roots:
        if path.startswith(r):
            return os.path.basename(r.rstrip('\\/')) + path[len(r):]
    return path


def main():
    ours_root, refs = sys.argv[1], sys.argv[2:]
    ours = load(ours_root)
    theirs = {}
    for r in refs:
        theirs.update(load(r))
    roots = [ours_root] + refs
    print(f"WritCrafter: {len(ours)} Lua files; references: {len(theirs)} Lua files")

    for title, size, shape in (('1. Exact token runs', RUN_EXACT, False),
                               ('2. Shape runs (identifiers renamed)', RUN_SHAPE, True)):
        idx = index_runs(theirs, size, shape)
        hits = []
        for path, (_, toks) in ours.items():
            for key, a, b in runs(toks, size, shape):
                for tpath, ta, tb in idx.get(key, ()):
                    hits.append((path, a, b, tpath, ta, tb))
        spans = merge(hits)
        print(f"\n== {title} ({size} tokens): {len(spans)} span(s)")
        for p, a, b, tp, ta, tb in spans:
            print(f"  {short(p, roots)}:{a}-{b}  ~  {short(tp, roots)}:{ta}-{tb}")

    # 3. Distinctive identical lines.
    def norm_lines(text):
        for n, line in enumerate(text.split('\n'), 1):
            code = re.sub(r'--.*', '', line).strip()
            code = re.sub(r'\s+', ' ', code)
            if len(code) >= MIN_LINE_LEN:
                yield code, n
    their_lines = defaultdict(list)
    for path, (text, _) in theirs.items():
        for code, n in norm_lines(text):
            their_lines[code].append((path, n))
    found = []
    for path, (text, _) in ours.items():
        for code, n in norm_lines(text):
            if code in their_lines:
                tp, tn = their_lines[code][0]
                found.append((short(path, roots), n, short(tp, roots), tn, code))
    print(f"\n== 3. Identical lines ({MIN_LINE_LEN}+ chars): {len(found)}")
    for p, n, tp, tn, code in found:
        print(f"  {p}:{n}  ~  {tp}:{tn}\n      {code[:140]}")

    # 4. Item-ID-like numbers in the same order.
    def numbers(toks):
        return [(v, line) for k, v, line in toks if k == 'N' and len(v) >= 5]
    idx = defaultdict(list)
    for path, (_, toks) in theirs.items():
        nums = numbers(toks)
        for i in range(len(nums) - NUM_RUN + 1):
            idx[tuple(v for v, _ in nums[i:i + NUM_RUN])].append((path, nums[i][1], nums[i + NUM_RUN - 1][1]))
    hits = []
    for path, (_, toks) in ours.items():
        nums = numbers(toks)
        for i in range(len(nums) - NUM_RUN + 1):
            key = tuple(v for v, _ in nums[i:i + NUM_RUN])
            for tpath, ta, tb in idx.get(key, ()):
                hits.append((path, nums[i][1], nums[i + NUM_RUN - 1][1], tpath, ta, tb))
    spans = merge(hits)
    print(f"\n== 4. Runs of {NUM_RUN}+ item-ID-like numbers in the same order: {len(spans)} span(s)")
    for p, a, b, tp, ta, tb in spans:
        print(f"  {short(p, roots)}:{a}-{b}  ~  {short(tp, roots)}:{ta}-{tb}")


if __name__ == '__main__':
    main()
