#!/usr/bin/env python3
"""Stage the downstream CCD correction without modifying the upstream submodule.

Both CMake and SCons compile these sources instead of the upstream copies. Fail
closed on source changes so dependency upgrades require reviewing the correction.
Only time of impact is changed; the separate shape-cast target is untouched.
"""
from __future__ import annotations

import hashlib
import sys
from pathlib import Path


DISTANCE_SHA256 = "52210be1d2ba16702b1d5d8e88d3a5d3ba6b3706dda4f9566573ba723854189d"
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

MESH_OLD = """\ttoiContext->toiInput.proxyA.points = triangle;
\ttoiContext->toiInput.proxyA.count = 3;

\tb3TOIOutput output = b3TimeOfImpact( &toiContext->toiInput );"""
MESH_NEW = """\ttoiContext->toiInput.proxyA.points = triangle;
\ttoiContext->toiInput.proxyA.count = 3;
\t// Solid mesh/heightfield manifolds subtract this offset from separation.
\t// Include it in the sweep so the handoff is separated in solver space too.
\ttoiContext->toiInput.proxyA.radius = toiContext->isSensor ? 0.0f : B3_MESH_REST_OFFSET;

\tb3TOIOutput output = b3TimeOfImpact( &toiContext->toiInput );"""
CORRECTIONS = {
    "distance.c": (DISTANCE_SHA256, OLD, NEW),
    "shape.c": ("6b6b9dea2161a8ed5e561b4c684311c1ab2f068f62ce25e5b578e435afb7b4fe", MESH_OLD, MESH_NEW),
}


def prepare(source: Path, destination: Path) -> Path:
    original = source.read_bytes()
    # Accept Git's CRLF checkout mode on Windows, but preserve the source otherwise.
    normalized = original.replace(b"\r\n", b"\n")
    digest, before, after = CORRECTIONS[source.name]
    if hashlib.sha256(normalized).hexdigest() != digest:
        raise RuntimeError(f"Box3D {source.name} changed; review the CCD correction before building")
    text = normalized.decode("utf-8")
    if text.count(before) != 1:
        raise RuntimeError(f"Expected exactly one CCD correction site in {source.name}")
    corrected = text.replace(before, after).encode("utf-8")
    destination.parent.mkdir(parents=True, exist_ok=True)
    if not destination.exists() or destination.read_bytes() != corrected:
        destination.write_bytes(corrected)
    return destination


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: prepare_box3d.py SOURCE_C OUTPUT_C")
    prepare(Path(sys.argv[1]), Path(sys.argv[2]))
