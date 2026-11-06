# Box3D Dynamic Mover compatibility experiment

This branch evaluates original-maintainer commit
`336263320469e5e9febfe18697ab562488f7e97a`, merged in
[Box3D #202](https://github.com/erincatto/box3d/pull/202) on October 28.
It starts from downstream `6a4002c`. The submodule, dependency lock and verifier
agree on the candidate; the repository URL remains `erincatto/box3d`.

The release and deployment branches retain their qualified `f36d061` engine
pin. This branch is a compatibility candidate, not a new qualified static host.

## Recorded checks

On November 6, the complete adapter and candidate Box3D library build in
Release on macOS x86-64, using the existing Godot 4.3 bindings archive.
All 43 native physics tests pass with official Godot 4.7, including the
large-surface motion and shape-cast regressions. No unexpected error,
failure or Box3D RID-leak markers are reported.

The local build uses the existing cached-bindings CMake check project and
compiles this worktree's full adapter and Box3D sources. Logs are retained
locally under `build/validation/`; this does not establish fresh-platform,
sanitizer, Android or static-Web qualification. Ordinary Web compilation and
browser smoke are the next bounded compatibility check.

## What the new engine API means

The upstream change adds dynamic character-mover support, including mover and
pogo joints, along with new samples. The existing Godot adapter does not map
these new APIs. Passing compatibility tests means existing Godot behavior
continues to work in the sampled cases; it does not add a new Godot controller.

An optional dynamic controller may be worth a later experiment. It needs its
own behavior definition and evidence before it could replace or extend the
kinematic `CharacterBody3D` integration. The native sample alone does not
establish matching Godot recovery, floor snap, platform carry or query semantics.

## Before promotion

Qualify matching static Debug/Release hosts with the existing Chromium/Firefox
smoke and six-cycle workloads, preserve artifact/dependency receipts, and run
the normal cross-platform, minimum-version and sanitizer checks. Keep the
existing startup, hardware/device and memory limits explicit. New controller
features should be independently scoped after compatibility is established.
