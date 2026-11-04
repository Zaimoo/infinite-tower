"""Replace one hero's block in HeroCostumes.luau, safely.

    python -I .claude/skills/hero-remodel/scripts/replace_costume_block.py "-- 11. SOLARIS" block.luau

The block runs from its "-- N. NAME" header line to the first line that is exactly "end".
The new block file must contain the header line through "end".

Why a script: writing the costume file with Python's default text encoding on Windows (cp1252)
crashed on the star characters in the headers and left the file empty. This reads and writes
UTF-8 bytes, keeps LF line endings, checks the header exists exactly once, and prints the piece
count and part total so you can check the 60-part budget.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
COSTUMES = ROOT / "src" / "ReplicatedStorage" / "Assets" / "HeroRig" / "HeroCostumes.luau"
RIG_PARTS = 16
BUDGET = 60

header, block_path = sys.argv[1], Path(sys.argv[2])
raw = COSTUMES.read_bytes()
if b"\r\n" in raw:
    sys.exit("HeroCostumes.luau has CRLF endings; expected LF. Not touching it.")
text = raw.decode("utf-8")

if text.count(header) != 1:
    sys.exit(f"Header {header!r} found {text.count(header)} times; expected exactly once.")
start = text.index(header)
end = text.index("\nend\n", start) + len("\nend\n")

block = block_path.read_bytes().decode("utf-8").replace("\r\n", "\n")
if not block.startswith(header):
    sys.exit(f"The new block must start with {header!r}.")
if not block.endswith("\n"):
    block += "\n"

COSTUMES.write_bytes((text[:start] + block + text[end:]).encode("utf-8"))

pieces = len(re.findall(r"^\s*piece\(", block, flags=re.M))
total = RIG_PARTS + pieces
print(f"Replaced {header!r}: {pieces} pieces, {total}/{BUDGET} parts" + ("  OVER BUDGET" if total > BUDGET else ""))
