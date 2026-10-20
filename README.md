# Charm App: Phase 0 prototype

A gold bead on a rope hanging from the top edge of the window you're working
in, or from the top of the screen. Move the window and the charm swings with
it. Grab and throw it, knock it, drag the pin to move it. Everything else on
screen stays clickable through it.

```
charm_app/
├── packages/charm_physics/   rope physics, pure Dart, unit-tested
└── app_desktop/              Flutter desktop app (Windows overlay implemented)
    ├── lib/overlay/          overlay widget, painter, native channel
    ├── lib/settings/         saved settings (JSON, no plugins)
    └── windows/runner/       overlay window, window tracking, tray icon,
                              launch at login (C++)
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
- **Drag the dark pin** to move the charm along the edge it hangs from.
  The charm swings no further than you moved the pin
- **Move the window** it hangs from: the charm swings no further than the
  window moved. Click another window and the charm moves to it; click the
  desktop and it goes back to the top of the screen
- **Full-screen apps** (video, games, F11 browser) hide the charm
- **Right-click the bead**: Thread / Gold Chain / Neon rope, Hang from
  window (on by default), Quit
- **Tray icon** (next to the clock): Show charm, Hang from window, Launch at
  login (off by default), Quit

Your choices (rope, pin position, shown or hidden, hang from window) are
saved to `%APPDATA%\Charm\settings.json` and come back on the next launch.
Launch at login lives only in Windows' own startup list (`HKCU\...\Run`,
also shown in Task Manager → Startup apps). Only one copy runs at a time.

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
- The window is 460×240 logical px, just big enough for the swing, with the
  anchor at its top centre. Moving the anchor moves the whole window, and the
  physics treats that as the anchor moving (`RopeSim.shiftFrame`).
- `AnchorTracker` (`windows/runner/anchor_tracker.cpp`) picks the anchor. It
  uses a WinEvent hook for the foreground window, and a second hook for moves
  of that one window, limited to its thread so other apps don't wake this one.
  It uses the window's visible frame (`DWMWA_EXTENDED_FRAME_BOUNDS`), and the
  pin keeps its place along the edge (72% by default, set by dragging it).
  - Taskbar, Start, Alt+Tab and tray pop-ups: the charm stays where it is.
  - The desktop: back to the top of the screen.
  - Tool windows, cloaked, minimised or tiny windows: ignored.
  - A window covering the whole monitor that isn't maximised (video, games,
    F11): the charm hides. Maximised windows count as normal, because with an
    auto-hiding taskbar they cover the monitor too.
- When the window it hangs from moves, the overlay follows at once. Dart gets
  `anchorMoved` and the rope swings. Jumping to a different window is not a
  move, so the charm goes along without swinging.
- The charm's centre is the rope's last particle, so the bead you see obeys
  the physics limits exactly. It used to hang 30 px below the rope's end,
  which acted as a longer lever and swung about 17% further.

## Phase 0 results (Windows 11, 2560×1600 at 175%, Intel UHD, 60 Hz)

| Check | Result |
|---|---|
| Transparent overlay, only charm drawn | ✅ |
| Click-through except bead/pin/menu (verified with `WindowFromPoint`) | ✅ |
| Grabbing the charm doesn't take focus from the active app | ✅ |
| Grab, drag, throw, brush-nudge, rope style switch | ✅ |
| Drag the pin → window follows, charm trails and settles | ✅ |
| Physics tests (swing never exceeds the user's motion, natural decay, stretch ≤ 1.02×, fixed 240 Hz, sleep, throw speed, anchor drag, nudge proportional, charm speed) | ✅ 28/28 |
| On screen: starts still · near-miss cursor does nothing · let go at −204 px → +157, −126, +110, −89 · sweep 3× faster → 3.2× wider swing | ✅ |
| Hangs from the active window: attaches exactly on its top edge, follows a 300 px move (swing 182 px), gentle 40 px move swings 37 px | ✅ |
| Full-screen window hides the charm, and it comes back after | ✅ |
| Minimised window: charm moves to the next window in front | ✅ |
| Tray menu: show/hide, hang from window, launch at login on/off, quit | ✅ |
| Settings saved and restored across a restart (rope, pin at 40%, screen top) | ✅ · 6 settings tests (defaults, round trip, batched writes, damaged file, bad values) |
| Second copy exits, one charm only | ✅ |
| CPU at rest (charm asleep) | ✅ ~0.4–1.2% of one core on the screen edge · ⚠️ 1.25% while attached to a busy window (target < 1%) |
| CPU while swinging briskly (60 fps) | ⚠️ ~35–75% of one core depending on machine state (≈3–6% of the 12-core CPU), only for the first few seconds of a swing |
| CPU while gently swaying (30 fps) | 24% of one core, was 37% at 60 fps (−35%, 4 alternating runs) |
| Physics on its own | 0.2–0.4% of one core |
| Memory | ~145–200 MB working set |

**Where the swinging cost goes:** almost all of it is Flutter's fixed cost
per frame. The physics is 0.4% of one core. Drawing the bead once and reusing
the image, and shrinking the window from 520×420 to 460×240, made no
measurable difference, so the drawing itself is cheap.

**What helped:** the overlay paces its own frames instead of using a ticker.
It runs every display refresh while the charm moves briskly or is held, about
30 fps once it has been only gently swaying (under ~10°) for a full swing,
and stops completely when it sleeps. A touch or a window move goes straight
back to full rate.

**Measuring:** readings drift by ±15 points with the machine's state (CPU
clock, other apps), so compare builds alternately. Build with
`--dart-define=BENCH_SWING=true` (starts swinging from 35° at the screen top)
and alternate old and new builds several times.

**Further options, if needed:** 30 fps throughout in a battery-saver mode, or
test Flutter's Impeller renderer on Windows once it's available in release.

## Not done yet (rest of Phase 0)

| Item | Status |
|---|---|
| macOS overlay | Not started. Needs a Mac: an `NSPanel` (non-activating, `ignoresMouseEvents` toggled the same way) in `macos/Runner`. Today the Dart code runs there as a normal window. |
| Linux X11 overlay | Not started. Needs a Linux machine/VM: GTK window with RGBA visual + input shape (`gdk_window_input_shape_combine_region`). |
| Linux Wayland check | Not started. Needs `wlr-layer-shell` (KDE, Sway, Hyprland); GNOME expected to be limited. |
| Active-window tracking | ✅ Windows done (see above). macOS needs Accessibility permission (`AXObserver`). Linux X11 via `_NET_ACTIVE_WINDOW`, and Wayland doesn't allow it. |
| Multi-monitor / DPI change while running | Untested (one display here). Moving the charm to a window on a monitor with a different scale needs a check. |
| Windows that are behind others | The charm is always on top, so it shows over a window that partly covers the one it hangs from. Possible fix: place the overlay just above the target in z-order instead of topmost. |
