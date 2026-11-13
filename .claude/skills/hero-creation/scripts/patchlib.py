"""Exact-string patches that keep a file's line endings.

Some repo files are CRLF (HeroClips, CombatSimulation, EntityRenderer, ...), others LF. This
reads UTF-8 bytes, normalises to LF while editing, and writes back with the original endings.
Each replacement must match exactly the expected number of times, or it stops.

    import sys; sys.path.insert(0, r"<repo>/.claude/skills/hero-creation/scripts")
    from patchlib import File
    f = File("src/ReplicatedStorage/Assets/HeroRig/HeroClips.luau")
    f.rep("old text", "new text")
    f.save()

Paths are relative to the current folder: run from the repository root.
"""

import os

ROOT = os.getcwd()


class File:
    def __init__(self, rel):
        self.path = rel if os.path.isabs(rel) else os.path.join(ROOT, rel)
        raw = open(self.path, "rb").read().decode("utf-8")
        self.crlf = "\r\n" in raw
        self.s = raw.replace("\r\n", "\n")

    def rep(self, old, new, count=1):
        n = self.s.count(old)
        assert n == count, (self.path, old[:80], n)
        self.s = self.s.replace(old, new)

    def save(self):
        out = self.s.replace("\n", "\r\n") if self.crlf else self.s
        open(self.path, "wb").write(out.encode("utf-8"))
