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
    ├── assets/charms/        charm artwork (SVG) and catalog.json
    ├── lib/charms/           charm catalog and drawing charms to images
    ├── lib/settings/         saved settings (JSON, no plugins)
    ├── lib/customize/        Customize window UI and its link to the charm
    └── windows/runner/       overlay window, window tracking, tray icon,
                              launch at login, Customize process (C++)
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
- **Right-click the bead**: Customize…, Hang from window (on by default),
  Quit
- **Charms from your photos** (Customize → Library → My charms → New from
  a photo): pick a PNG, JPEG, WebP, BMP or GIF in the Windows file dialog,
  then choose a frame (circle, rounded square, heart, oval) and finish (gold,
  silver, rose gold, black), drag and zoom the photo, name it, and save. It
  hangs at once. Saved charms live in `%APPDATA%\Charm\charms\` (one PNG
  each plus `my_charms.json`) and can be deleted from the Library. The
  original photo is never copied or changed.
- **Charms from a name or word** (My charms → New from a name): English,
  Hindi, Tamil or Malayalam, up to 14 letters. Shapes: letters on a nameplate bar, or
  a round, bar or heart tag with the name stamped in. Finishes: gold,
  silver, rose gold or black. Lettering: classic (Georgia), modern (Segoe UI)
  or script (Segoe Script). Hindi, Tamil and Malayalam always use Nirmala UI, which
  shapes those scripts properly. The text shrinks to fit its plate or tag.
- **Animated charms** (My charms → New animated): pick a GIF or animated
  WebP (up to 8 MB; the first 120 frames are used), name it, set its size.
  It plays while it hangs, at the file's own timing (but never faster than
  about 16 frames a second, and the 0 and 10 ms delays many GIFs carry
  count as 100 ms, as in browsers). Frames are decoded once, no larger than
  needed, and drawn into cached images like any other charm. The animation
  stops while the charm is hidden (by you, or by a full-screen window), and
  Settings → Animate charms turns it off everywhere (one still frame). The
  file is copied into `%APPDATA%\Charm\charms\` unchanged.
  Cost: a charm that is asleep costs about 1% of one core; a 10 frames a
  second animation adds about 5–6% (Flutter's per-frame cost), so laptop
  users may prefer short or slow animations. Lottie is not supported yet.
- **Design your own** (My charms → Design your own): layers of photos,
  words (English, Hindi, Tamil, Malayalam) and stickers (18 Material symbols), each
  moved by dragging, resized with the scroll wheel or a slider, turned,
  recoloured (metal, white, black, red, blue) and ordered forward or back.
  They sit on a base (none, circle, rounded square, heart, oval, bar) with a
  fill (gold, silver, rose gold, or ivory, red, blue, green or midnight
  enamel), a border (none, plain rim, beaded, double) and a metal for the
  rim and loop. Layers are clipped to the base, and float freely with no
  base.
- **13 charms** in three collections (Classic, Luck, Nature), chosen in
  Customize → Library. Each has its own size, weight and hang point.
  These are simple original placeholders. See "Adding charms" below.
- **Nine ropes**, chosen in Customize: Thread, Leather, Gold Chain, Silver
  Chain, Neon, Spider Thread, Midnight Cord, Temple Thread, Silver Cord. Each
  has its own physics and look (see `packages/charm_physics/README.md`).
- **Tray icon** (next to the clock): Customize…, Show charm, Hang from
  window, Launch at login (off by default), Quit
- **Customize window** (tray or right-click → Customize…): Library, Ropes &
  Layout (rope with previews, hang from window or screen, pin position),
  Settings (show charm, launch at login, privacy, where settings are saved),
  About. Changes apply to the charm at once. Ctrl+1–4 switch tabs, Ctrl+W
  closes.

**First launch** opens a 3-step welcome: pick a charm, choose privacy, and
pick where it hangs and whether it starts at sign-in, with a few tips. Each
choice applies live. It counts as shown the moment it opens, so it appears
once even if closed early.

**Privacy:** the app makes no network requests at all. Sharing anonymous
usage stats is off unless chosen (in the welcome or Customize → Settings).
There is no stats server yet, so even when on, nothing is sent; the wording
says so. Opting in creates a random ID, and opting out deletes it. The
payload is limited to a fixed list (random ID, app version, OS, charm, rope,
hang mode), and "See what would be shared" shows it word for word
(`lib/privacy/usage_stats.dart`).

Your choices (rope, pin position, shown or hidden, hang from window) are
saved to `%APPDATA%\Charm\settings.json` and come back on the next launch.
Launch at login lives only in Windows' own startup list (`HKCU\...\Run`,
also shown in Task Manager → Startup apps). Only one copy runs at a time.

It starts hanging still. Every swing comes from you.

No Flutter plugins are used, so Windows Developer Mode is not needed.

## Adding charms

1. Export the artwork as **SVG** (preferred: it stays sharp at any screen
   scale) or **PNG** (at least 4× its display size), with a transparent
   background. Leave out the ring: the app draws the jump ring and the
   shadow.
2. Put it in a folder under `app_desktop/assets/charms/` (a new folder must
   also be listed under `assets:` in `pubspec.yaml`).
3. Add an entry to `assets/charms/catalog.json`:

```json
{ "id": "lotus", "name": "Lotus", "description": "One line for its card.",
  "art": "nature/lotus.svg", "size": 44, "mass": 8, "hang": [0.5, 0.05] }
```

| Field | Meaning |
|---|---|
| `id` | unique, saved in settings, so don't rename it later |
| `size` | width on screen in logical px (24–64); height follows the artwork |
| `mass` | weight (3–30). The bead is 12. Light charms drift, heavy ones swing steadily |
| `hang` | where the ring attaches, as (x, y) fractions of the artwork. (0.5, 0) is top centre. The charm hangs with this point straight above its centre |

Bad entries (missing art, wrong type, repeated id) are skipped rather than
breaking the app, and out-of-range numbers are pulled into range. A test
(`test/charm_catalog_test.dart`) fails if the shipped catalog has any of
these or points at a missing file, and `test/charm_sprite_test.dart` draws
every charm. If artwork fails to load in the app, the charm shows as the
gold bead and the reason goes to `%APPDATA%\Charm\charm.log`.

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
- **Customize runs as a separate process**: the same exe started with
  `--customize`. It opens in about 2–2.5 s and uses about 190 MB while
  open, and all of that is freed when it closes. Hosting it as a second
  Flutter engine inside the charm's process leaked about 90 MB on every
  open, so the charm kept growing (130 → 240 → 330 → 410 MB). The two
  processes exchange JSON strings over `WM_COPYDATA`
  (`windows/runner/app_messages.h`), and each side accepts messages only
  from a copy of the same exe. The charm owns the settings: Customize sends
  `update` with the changed fields and gets `state` back, and the tray,
  right-click menu and Customize all go through one apply step
  (`CharmOverlay._apply`).
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
| Physics tests for all nine ropes (swing never exceeds the user's motion, natural decay, settles within 12 s, stretch ≤ 1.02×, fixed 240 Hz, sleep, throw speed, anchor drag, nudge proportional, charm speed) | ✅ 64/64 |
| Nine ropes shown in Customize with previews, and applied live to the charm | ✅ |
| 13 charms: catalog tests (6), every charm draws (3), Library shows real artwork, a chosen charm hangs on the real rope with its ring and hang point | ✅ |
| Light (3) and heavy (30) charms on every rope never swing past the let-go; a weight change doesn't move the charm | ✅ |
| Welcome opens by itself on first launch (about 5 s after start), shows 3 steps, and is marked shown at once | ✅ |
| Stats consent: off by default, ID only on opt-in and deleted on opt-out, fixed field list (6 tests) | ✅ · nothing is sent (no server yet) |
| Photo charms: Windows file dialog → editor → saved PNG → hangs live on the real rope → listed in My charms → deleted (switches to the bead first) | ✅ |
| Photo charm tests: photo always covers the frame, PNG size and transparency per shape, storage round trip, unsafe or missing entries ignored (11) | ✅ |
| Name charms on screen: "Lucky" letters (gold), அம்மா heart tag (correct Tamil shaping), माँ silver bar tag (correct chandrabindu), saved and hanging, then deleted | ✅ |
| Name charm tests: script detection, Indic font choice, cut by visible letters, text fits every shape, every shape renders (5) | ✅ |
| Designer on screen: stickers, words, drag to move, midnight enamel with beaded border, saved and hanging, then deleted | ✅ · once, the controls list jumped back to the top between two test steps; not reproduced since |
| Animated charm on screen (12-frame GIF star): pulses and turns between frames while hanging; CPU 6.6% of one core at 10 fps animating, 1.1% with Animate charms off; memory 144 MB | ✅ |
| Animated charm tests: gif/webp accepted (path tricks and other types refused), frame timing (0 ms → 100 ms), frame chosen at each time and looping, time to next frame, file type kept on save and delete (5) · Settings tests cover the new switch | ✅ |
| "New animated" in Customize (file picker, 'doesn't move' and 'over 8 MB' messages) | Written and analyzed, not clicked through |
| Designer tests: every base and border renders, clipping inside a base, click finds the top layer even when turned, placement stays in range, stickers and words draw (5) | ✅ |
| On screen: starts still · near-miss cursor does nothing · let go at −204 px → +157, −126, +110, −89 · sweep 3× faster → 3.2× wider swing | ✅ |
| Hangs from the active window: attaches exactly on its top edge, follows a 300 px move (swing 182 px), gentle 40 px move swings 37 px | ✅ |
| Full-screen window hides the charm, and it comes back after | ✅ |
| Minimised window: charm moves to the next window in front | ✅ |
| Tray menu: show/hide, hang from window, launch at login on/off, quit | ✅ |
| Settings saved and restored across a restart (rope, pin at 40%, screen top) | ✅ · 6 settings tests (defaults, round trip, batched writes, damaged file, bad values) |
| Second copy exits, one charm only | ✅ |
| Customize: opens from tray, changes apply live both ways (rope, show/hide), tabs and shortcuts work | ✅ |
| Customize open/close ×3: charm stays at 132 MB; Customize process ~190 MB while open, gone after | ✅ |
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
