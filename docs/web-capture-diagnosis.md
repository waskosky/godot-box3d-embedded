# Web result capture and remaining text artifacts

The smoke runner distinguishes a physics result from a submitted result frame.
After writing its final status, the fixture waits for a process frame and two
`RenderingServer.frame_post_draw` signals before printing
`Smoke result frame submitted`. The runner requires that marker and records its
time separately from the console physics PASS. This avoids taking a successful
capture solely because a console message arrived before the overlay was drawn.
It is a render-submission fence, not a pixel-correctness or hardware certificate.

Each load retains its HTTP status and required checks. Firefox can return HTTP
304 for a successful cached navigation. That status is accepted only alongside
every fresh backend, physics and frame marker; engine/browser errors still fail.
Before this correction, a reproduced reload passed every check but failed solely
because Playwright's `response.ok` excludes 304.

## Bounded investigation, November 14

Local ordinary Release Web checks used official Godot 4.7 and Playwright 1.60.0.
The tested terrain side module was
`0afa4735e145aa8b062b29a3853e19e48213cc0db4eb826b2a5ec7a07f19e713`.
The custom dynamic-link template was
`3f0ee7c6a4e3813b4ab266a1eead55ed5dcb91b84c2f5736b6dc05f69ed5d08d`.

| Case | Observed result |
| --- | --- |
| Box3D scene, custom template, headless Chromium/Firefox | Physics passes; some captures have missing glyphs. |
| Same export, captures immediately and after 0.5, 2.5 and 12.5 seconds | Waiting alone does not consistently repair the text. |
| Label-only control, official non-threaded template, no Box3D | Inspected Firefox captures have complete text. |
| Label-only control, custom dynamic-link template, no Box3D | Inspected Firefox captures have complete text. |
| Full fixture with GodotPhysics and official template, no Box3D | Inspected Firefox text is complete; expected Box3D-specific physics/backend checks fail. |
| Box3D scene, official dynamic-link template | One inspected Firefox run has complete text and physics PASS; not proof of a general fix. |
| Batched status writes plus frame fence | Initial frames are complete; repeat captures reproduce missing text. Batching was therefore removed. |
| Headed Firefox on this macOS host | A run reaches all physics/frame markers and its inspected frame has complete text; not device/performance qualification. |

The underlying text defect has **not** been isolated to the physics adapter,
font layout, template build, browser driver or readback path. Do not infer a
solver memory defect from these screenshots, or claim that a frame fence fixes
the persistent glyph loss. Native sanitizers and browser physics checks remain
separate evidence. The headed run also does not qualify Chromium's SwiftShader
timing as hardware performance, or turn headless graphics flags into a GPU check.

Local investigation receipts and frames are retained under
`build/capture-diagnosis/`. The ordinary baseline export manifest, control
projects and template/source hashes are retained alongside them. Published
preview 3 remains unchanged. Real-GPU visual acceptance, repeated headed runs,
WebKit, physical mobile devices and background/resume remain open gates.
