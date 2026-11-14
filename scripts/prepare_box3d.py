#!/usr/bin/env python3
"""Stage the downstream CCD correction without modifying the upstream submodule.

Both CMake and SCons compile this distance.c instead of the upstream copy. Fail
closed on source changes so dependency upgrades require reviewing the correction.
Only time of impact is changed; the separate shape-cast target is untouched.
"""
from __future__ import annotations

import hashlib
import sys
from pathlib import Path


SOURCE_SHA256 = "52210be1d2ba16702b1d5d8e88d3a5d3ba6b3706dda4f9566573ba723854189d"
OLD = """\t// Setup target distance and tolerance
\tfloat linearSlop = B3_LINEAR_SLOP;
\tfloat totalRadius = proxyA.radius + proxyB.radius;
\tfloat target = b3MaxFloat( linearSlop, totalRadius - linearSlop );"""
NEW = """\t// Stop separated so the next step uses a hard speculative contact before
\t// integrating positions. Starting overlapped would use a soft constraint,
\t// allowing the remaining impact velocity to push small shapes through thin
\t// geometry. The tolerance below is smaller than this positive surface gap.
\tfloat linearSlop = B3_LINEAR_SLOP;
\tfloat totalRadius = proxyA.radius + proxyB.radius;
\tfloat target = totalRadius + linearSlop;"""


def prepare(source: Path, destination: Path) -> Path:
    original = source.read_bytes()
    # Accept Git's CRLF checkout mode on Windows, but preserve the source otherwise.
    normalized = original.replace(b"\r\n", b"\n")
    if hashlib.sha256(normalized).hexdigest() != SOURCE_SHA256:
        raise RuntimeError("Box3D distance.c changed; review the CCD correction before building")
    text = normalized.decode("utf-8")
    if text.count(OLD) != 1:
        raise RuntimeError("Expected exactly one Box3D TOI target to correct")
    corrected = text.replace(OLD, NEW).encode("utf-8")
    destination.parent.mkdir(parents=True, exist_ok=True)
    if not destination.exists() or destination.read_bytes() != corrected:
        destination.write_bytes(corrected)
    return destination


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: prepare_box3d.py SOURCE_DISTANCE_C OUTPUT_DISTANCE_C")
    prepare(Path(sys.argv[1]), Path(sys.argv[2]))
