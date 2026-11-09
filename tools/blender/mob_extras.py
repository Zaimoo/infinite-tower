"""
Extra-joint registry for tower mobs (docs/mob-reanimation-plan.md §3.8). Pure Python (no bpy), so it can be
checked outside Blender:  python tools/blender/mob_extras.py

Appendages that move on their own (tails, jaws, capes, censers...) are split out of their parent segment as
joints named "Extra<Base>[<n>][L|R]". They hang BELOW the clip joints and never rename or re-parent them.

Each base name lists:
  parents  joints the first piece may hang from. A trailing "*" matches any joint with that prefix.
  motion   the spring EnemyAnimator uses while no clip keys the joint:
           Cloth (soft, droops), Hanging (pendulum), Rigid (stiff wobble), Spin (turns steadily).
  keyed    True when motion sets will key it in clips (tails, jaws...); until then it springs.
  chain    True when numbered pieces form a chain: <Base>2 hangs from <Base>1, and so on.
Alpha "Trophy_*" joints are not in the registry: they spring as Rigid.
"""
import re

EXTRAS = {
    # keyed
    "Tail": {"parents": ["Body", "KneeL"], "motion": "Hanging", "keyed": True, "chain": True},
    "Sting": {"parents": ["ExtraTail*"], "motion": "Rigid", "keyed": True},
    "Elytra": {"parents": ["Body"], "motion": "Rigid", "keyed": True},
    "Shell": {"parents": ["Body"], "motion": "Rigid", "keyed": True},
    "Jaw": {"parents": ["Head"], "motion": "Rigid", "keyed": True},
    "Beak": {"parents": ["Head"], "motion": "Rigid", "keyed": True},
    "TailFan": {"parents": ["Body"], "motion": "Cloth", "keyed": True},
    "Frill": {"parents": ["Head"], "motion": "Cloth", "keyed": True},
    "Whip": {"parents": ["ForearmL", "ForearmR"], "motion": "Hanging", "keyed": True, "chain": True},
    "Chain": {"parents": ["ForearmL", "ForearmR"], "motion": "Hanging", "keyed": True, "chain": True},
    "Piston": {"parents": ["ForearmL", "ForearmR"], "motion": "Rigid", "keyed": True},
    "Bellows": {"parents": ["Body"], "motion": "Rigid", "keyed": True},
    "Crown": {"parents": ["Head"], "motion": "Rigid", "keyed": True},
    "Tome": {"parents": ["Body", "ForearmL", "ForearmR"], "motion": "Rigid", "keyed": True},
    # springs only
    "Key": {"parents": ["Body"], "motion": "Rigid"},  # its turn axis is horizontal; Spin only turns about up
    "Crest": {"parents": ["Head"], "motion": "Cloth"},
    "Cape": {"parents": ["Body"], "motion": "Cloth"},
    "WrapTail": {"parents": ["Head"], "motion": "Cloth"},
    "Hem": {"parents": ["Body"], "motion": "Cloth"},
    "Censer": {"parents": ["ForearmL", "ForearmR"], "motion": "Hanging"},
    "Lantern": {"parents": ["ForearmL", "ForearmR"], "motion": "Hanging"},
    "Ring": {"parents": ["Body", "Head"], "motion": "Spin"},
    "Mantle": {"parents": ["Body"], "motion": "Cloth"},
    "Branches": {"parents": ["Head"], "motion": "Rigid"},
    "Vines": {"parents": ["Body"], "motion": "Cloth"},
    "Tree": {"parents": ["Body", "ArmL", "ArmR"], "motion": "Rigid"},
    "Antenna": {"parents": ["Head"], "motion": "Rigid"},
    "Eye": {"parents": ["Head"], "motion": "Rigid"},
    "Skirt": {"parents": ["Body"], "motion": "Cloth"},
    "Sacs": {"parents": ["Body", "ArmL", "ArmR"], "motion": "Hanging"},
}
MOTIONS = ("Cloth", "Hanging", "Rigid", "Spin")

# Base names, longest first so "TailFan" wins over "Tail" and "WrapTail" is its own base.
_BASES = sorted(EXTRAS, key=len, reverse=True)
_NAME = re.compile(r"^Extra(?P<rest>[A-Za-z]+?)(?P<n>\d*)(?P<side>[LR]?)$")


def parse(name):
    """'ExtraTail3' -> ('Tail', 3, ''); 'ExtraTomeL' -> ('Tome', None, 'L'); None if not a registry name."""
    if not name.startswith("Extra"):
        return None
    body = name[len("Extra"):]
    for base in _BASES:
        if body.startswith(base):
            m = re.fullmatch(r"(\d*)([LR]?)", body[len(base):])
            if m:
                return base, (int(m.group(1)) if m.group(1) else None), m.group(2)
    return None


def _parent_ok(allowed, parent):
    for a in allowed:
        if a.endswith("*") and parent.startswith(a[:-1]):
            return True
        if a == parent:
            return True
    return False


def check(name, parent):
    """Raise AssertionError when `name` is not a registry extra hanging from an allowed parent."""
    parsed = parse(name)
    assert parsed, f"unknown extra joint {name} (add it to mob_extras.EXTRAS)"
    base, n, side = parsed
    spec = EXTRAS[base]
    assert parent, f"{name} needs a parent"
    if spec.get("chain") and n and n > 1:
        want = f"Extra{base}{n - 1}{side}"
        assert parent == want, f"{name} must hang from {want}, not {parent}"
    else:
        assert _parent_ok(spec["parents"], parent), f"{name} may hang from {spec['parents']}, not {parent}"


def motion_for(name):
    """The JSON/index fields for a joint: {'Motion': ..., 'Keyed': ...} or {} for clip joints."""
    if name.startswith("Trophy"):
        return {"Motion": "Rigid"}
    parsed = parse(name)
    if not parsed:
        return {}
    spec = EXTRAS[parsed[0]]
    out = {"Motion": spec["motion"]}
    if spec.get("keyed"):
        out["Keyed"] = True
    return out


if __name__ == "__main__":
    assert all(s["motion"] in MOTIONS for s in EXTRAS.values())
    assert parse("ExtraTailFan") == ("TailFan", None, "")
    assert parse("ExtraTail3") == ("Tail", 3, "")
    assert parse("ExtraWrapTail") == ("WrapTail", None, "")
    assert parse("ExtraTomeL") == ("Tome", None, "L")
    assert parse("ExtraCape2") == ("Cape", 2, "")
    assert parse("ExtraBogus") is None and parse("ArmL") is None
    check("ExtraTail1", "Body"); check("ExtraTail1", "KneeL"); check("ExtraTail2", "ExtraTail1")
    check("ExtraSting", "ExtraTail4"); check("ExtraCape2", "Body"); check("ExtraWhip2", "ExtraWhip1")
    for bad in (("ExtraTail2", "Body"), ("ExtraJaw", "Body"), ("ExtraBogus", "Body"), ("ExtraCape", None)):
        try:
            check(*bad)
        except AssertionError:
            continue
        raise SystemExit(f"should have failed: {bad}")
    assert motion_for("ExtraTail2") == {"Motion": "Hanging", "Keyed": True}
    assert motion_for("ExtraHem") == {"Motion": "Cloth"}
    assert motion_for("Trophy_Crown") == {"Motion": "Rigid"}
    assert motion_for("ArmL") == {}
    print("mob_extras: ok")
