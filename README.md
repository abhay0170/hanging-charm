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
- **Lockets** (My charms → New locket): a photo charm with a cover. It
  hangs closed as an engraved piece of metal (an initial, up to three
  letters in any supported script, or a sparkle) with a hinge and clasp.
  Tap it (a press under 0.5 s that moves under 6 px, so dragging still
  swings it) and it turns over about its vertical axis in about a quarter of
  a second to show the photo inside; tap again to close it. It closes by
  itself after 8 seconds, so a photo is never left on your screen. The
  cover and the inside are saved as two PNGs (`<id>.png` and
  `<id>_open.png`, listed as `openArt` in `my_charms.json`); deleting the
  charm deletes both, and an entry whose inside is missing is left out.
- **Mouse wiggle** (Settings → Sway when I shake the mouse; off by default):
  shake the mouse side to side (four strokes of at least 40 px within 0.8 s,
  faster than 450 px/s on average) and the charm gives a small sway away
  from the cursor. The push is 60 to 140 px/s depending on how hard you
  shake, which swings it 8° at most on any rope (tested), so a wiggle can
  never make a big swing. A quick sweep across the screen, a slow back and
  forth, and hand tremor do nothing, and it waits 1.5 s before reacting
  again. Only the cursor's sideways position is looked at, and only while
  the switch is on; nothing is kept or sent. A keyboard nudge was left out
  on purpose: noticing keystrokes needs a global keyboard hook, which is
  how key loggers work, and a privacy-first app shouldn't do that.
- **Save power on battery** (Settings, on by default): when the computer is
  on battery or in Windows' Battery Saver, the charm draws about 30 frames a
  second at most from the start (instead of every display refresh until the
  swing calms), and animated charms hold still. Dragging the charm is always
  smooth. It asks Windows every 20 seconds, so it follows plugging in and
  out. Measured on this laptop (on battery, Battery Saver on): an animated
  charm 5–7% of one core with the setting off, 1–3% on; a thrown swing
  20–21% off, 12–15% on. The saving is modest for swings (they calm within
  a couple of seconds anyway) and large for animations.
- **Reduce Motion**: with Windows' "Show animations" off, animated charms
  hold still, a locket opens at once instead of turning over, and the mouse
  wiggle is not listened for. Touching and dragging the charm still works in
  full.
- **Chime** (Settings → Chime volume; off until you choose a volume): a soft
  bell when the charm is swept by the cursor, let go of at speed, or a
  locket opens (and when you let go of the volume slider, so you hear it).
  The sound is made in code, not from a file: four partials of a struck
  bell, each fading at its own rate, over a pentatonic scale, so nothing is
  downloaded or shipped and any two chimes sound fine together. A harder
  strike is louder (25–100% of the volume), a heavy charm (mass 18 or more)
  rings an octave lower, and there is at most one every quarter of a second.
  It plays through Windows' own `PlaySound` from memory, with no audio
  library. Each sound is 1.1 s, 44 KB, made when needed.
- **Several charms on one rope** (Library → "On your rope", and the + on any
  charm card): your main charm plus up to two more (three in all, which is
  plenty), hung from the same ring on cords of different lengths. They are
  laid out as a loose, staggered cluster: the first goes out to the right,
  the second to the left and lower, each cord just long enough that no charm
  touches another (sized from the artwork, with a 6 px gap), so they never
  sit in a clump. They swing apart and together, knock (and chime, if the chime is on) with
  a sound by the lighter charm's weight, and each can be picked up and
  carried; let go and it swings back. The main charm carries the ring and is
  not pushed around by the extras, so its swing is unchanged. Extra charms
  are shown as they are (a locket stays closed, a GIF plays); only the main
  charm's locket opens on a tap. The window is taller (340 instead of 240
  logical pixels) to leave room. A knock is reported once, when two charms
  meet, so charms resting against each other stay quiet.
- **Breeze** (Settings → Breeze: off, light, breezy, windy; off by default):
  a slow wind from the clock: three gentle waves (0.13, 0.21 and 0.34 Hz,
  well under the rope's own 0.8 Hz, so they never build up) push the rope
  both ways, never past about 1.5 times the strength set (10° at windy; 3°,
  6° and 10° for light, breezy and windy; tested on all nine ropes). It uses
  no weather service, no internet and no location. It pauses while saving
  power, with Windows animations off, and while the charm is hidden. It
  keeps the charm moving, so it costs about 5–7% of one core more than a
  charm at rest (3% idle → 8–10% measured), at about 20 frames a second.
- **Hang from a screen edge** (Settings → Where it hangs: Window, Top, Left,
  Right): besides the active window and the top of the screen, the charm can
  hang beside the left or right edge of the screen. The pin sits 40 px in
  from the edge, slides up and down when dragged (its place is saved per
  edge), and keeps 300 px clear of the bottom so the rope and charm fit.
  The edge of the screen is a wall: the rope and every charm stop with their
  edge on it, keeping a quarter of their speed the other way, so a swing
  never goes out of sight (tested, with extras too). The taskbar is not an
  anchor: a charm hanging from it would cover the taskbar's own icons.
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
| Locket on screen (heart, gold chain): tap turns it edge-on then shows the photo; it closes by itself after about 8 s. Covers checked for heart, circle, oval and rounded square with Latin and Malayalam engraving and none | ✅ |
| Locket tests: engraving cut by visible letters, every shape × engraving draws, `openArt` accepted only for user files (path tricks refused), saved and deleted with its inside, sprite holds cover and inside and doesn't play (5) | ✅ |
| "New locket" in Customize (file picker, Cover/Inside preview, engraving field) | Written and analyzed, not clicked through |
| Mouse wiggle on screen (cursor shaken 400 px below the charm, off the charm): charm sways, ~7 px measured at its centre; a straight sweep of the same distance: 0 px | ✅ |
| Wiggle tests: shake noticed once, harder = stronger, fast sweep / slow back-and-forth / tremor / strokes spread over seconds ignored, cooldown (7) · physics: strongest wiggle nudge under 9° on all 9 ropes (1) | ✅ |
| Battery saver on screen (laptop on battery with Battery Saver on): animated charm 5–7% → 1–3%, thrown swing 20–21% → 12–15%; frames confirmed at 30 a second with the saver on | ✅ |
| Power state tests: native answer read, battery or Battery Saver means low power, odd answers mean plugged in, equality (4) · Settings tests cover the switch | ✅ |
| Reduce Motion (animations off, instant locket flip, wiggle ignored) | Written, not tested: Windows' setting was on here and I didn't change it |
| Chime on screen: sweeping the cursor over the charm made one chime; Windows' `PlaySound` accepted it (returned true). I can't hear it from here, so how it sounds is for your ears | ✅ played · 🔊 untested by ear |
| Chime tests: valid 16-bit mono WAV of the right length, peak follows volume and never clips, starts and ends without a click, rings at the pitch asked for, strength by speed, heavy charms an octave lower (6) · Settings tests cover the volume | ✅ |
| Cluster on screen (bead + star, heart, clover, coin on a gold chain): charms hang fanned on their cords; dragging the coin carries it with the hand and it swings back when let go | ✅ |
| Breeze on screen / CPU: idle 3%, with breeze 8–10%; with the saver forced on, 3% again | ✅ |
| Physics tests (15 new, 82 in all): breeze sways both ways within 1.5× its angle on every rope, stronger = wider, stops and sleeps when off, never adds to a thrown swing, bad values safe · extras settle apart and asleep, stay on their cords through throws on every rope, knocks reported once and not for a gentle sway, an extra can be carried, rope never stretches, 40 random grabs stay finite, extras sway in a breeze, removing them restores the plain charm | ✅ |
| Settings tests: extra charms kept in order, at most four, strings only; breeze clamped (2) | ✅ |
| Library "On your rope" strip, the + buttons and the Breeze slider | Written and analyzed; not clicked through (settings changes were tested through the settings file) |
| Edges on screen: left and right anchors hang 40 px in from the edge; dragging the left pin down 300 px moved it and saved its place (0.20 → 0.49) | ✅ |
| Wall tests (6): without a wall it swings past the line, left and right walls stop the charm's edge on them, it comes back with less energy, extras stop at the wall and settle, removing the walls frees it (88 physics tests in all) · Settings tests cover the edge and pin place | ✅ |
| Wall on screen (a hard throw into the edge), and the Where it hangs buttons in Customize | Not tested on screen (physics tested; settings changed through the settings file) |
| Cluster layout on screen (bead with star and heart, clover with coin and horseshoe, gem with moon and leaf): staggered, one lower than the other, no overlap | ✅ |
| Layout tests (4): sides alternate and each hangs lower; 200 random sets of sizes never overlap; small charms hang closer than big ones | ✅ |
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
