# Charm App: Phase 0 prototype

A gold bead on a rope hanging from the top of the screen. Grab and throw it,
brush past it, drag the pin to move it. Everything else on screen stays
clickable through it.

```
charm_app/
├── packages/charm_physics/   rope physics, pure Dart, unit-tested
└── app_desktop/              Flutter desktop app (Windows overlay implemented)
    ├── lib/overlay/          overlay widget, painter, native channel
    └── windows/runner/       transparent click-through overlay window (C++)
```

## Run it (Windows)

```bash
cd app_desktop && flutter build windows --release
```

Then start `app_desktop/build/windows/x64/runner/Release/charm_desktop.exe`.

- **Drag the bead** and let go: it swings back no further than where you
  let go. Let go while moving to throw it: it leaves at your hand's speed
- **Sweep the cursor through it** to knock it, in proportion to how fast
  you swept (passing close without touching does nothing)
- **Drag the dark pin** at the top to move the charm along the screen edge.
  The charm swings no further than you moved the pin
- **Right-click the bead**: Thread / Gold Chain / Neon rope, Quit

It starts hanging still. Every swing comes from you.

No Flutter plugins are used, so Windows Developer Mode is not needed.

## How the overlay works (Windows)

- A borderless `WS_POPUP` window: topmost, tool window (no taskbar or Alt+Tab
  entry), `WS_EX_NOACTIVATE` (never steals focus), transparent through
  `DwmExtendFrameIntoClientArea`.
- Click-through comes from `WS_EX_LAYERED | WS_EX_TRANSPARENT`. Dart sends the
  clickable areas (bead, pin, menu) only when they move. A 30 ms native timer
  checks the cursor against them and turns click-through off only while the
  cursor is over one. Dart hears about the cursor only when it comes near.
- The window is 520×420 logical px, just big enough for the swing. Dragging
  the pin slides the whole window, and the physics treats that as the anchor
  moving (`RopeSim.shiftFrame`). This is also the base for "hang from the
  active window" later.

## Phase 0 results (Windows 11, 2560×1600 at 175%, Intel UHD, 60 Hz)

| Check | Result |
|---|---|
| Transparent overlay, only charm drawn | ✅ |
| Click-through except bead/pin/menu (verified with `WindowFromPoint`) | ✅ |
| Grabbing the charm doesn't take focus from the active app | ✅ |
| Grab, drag, throw, brush-nudge, rope style switch | ✅ |
| Drag the pin → window follows, charm trails and settles | ✅ |
| Physics tests (swing never exceeds the user's motion, natural decay, stretch ≤ 1.02×, fixed 240 Hz, sleep, throw speed, anchor drag, nudge proportional) | ✅ 27/27 |
| On screen: starts still · near-miss cursor does nothing · let go at −204 px → +157, −126, +110, −89 · sweep 3× faster → 3.2× wider swing | ✅ |
| CPU at rest (charm asleep) | ✅ ~0.4–1.2% of one core (target < 1%) |
| CPU while swinging | ⚠️ ~32–44% of one core (≈3–4% of the 12-core CPU), only for the few seconds it swings |
| Physics on its own | 0.2–0.4% of one core |
| Memory | ~145–200 MB working set |

**Where the swinging cost goes:** Flutter's own per-frame cost is about 19% of
one core even when drawing one circle. The rope and bead drawing adds about
12%. Shrinking the window from full width to 520 px saved about 14 points.
Not the cause: physics, the blurred shadow, the layered window style.
Ideas for Phase 1: cache the charm as an image, use a simpler rope path,
lower the frame rate in the last part of the settle, and 30 fps in battery
saver.

## Not done yet (rest of Phase 0)

| Item | Status |
|---|---|
| macOS overlay | Not started. Needs a Mac: an `NSPanel` (non-activating, `ignoresMouseEvents` toggled the same way) in `macos/Runner`. Today the Dart code runs there as a normal window. |
| Linux X11 overlay | Not started. Needs a Linux machine/VM: GTK window with RGBA visual + input shape (`gdk_window_input_shape_combine_region`). |
| Linux Wayland check | Not started. Needs `wlr-layer-shell` (KDE, Sway, Hyprland); GNOME expected to be limited. |
| Active-window tracking spike | Not started. Windows: `SetWinEventHook` for foreground and location changes → `moveBy`. |
| Multi-monitor / DPI change while running | Untested (one display here). |
