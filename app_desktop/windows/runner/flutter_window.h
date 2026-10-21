#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <array>
#include <cstdint>
#include <memory>
#include <vector>

#include "anchor_tracker.h"
#include "tray_icon.h"
#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  struct HitRect {
    double left, top, right, bottom;
  };

  static constexpr UINT_PTR kCursorTimer = 1;
  static constexpr UINT kCursorIntervalMs = 30;
  // How close, in logical pixels, the cursor must come to a hit rect before
  // Dart is told where it is.
  static constexpr double kNearMargin = 60;

  // Answers the Dart side of the "charm/overlay" channel.
  void HandleOverlayCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Makes the window click-through unless the cursor is over a hit rect, and
  // reports the cursor to Dart while it is near one.
  void CheckCursor();

  // Puts the window's top centre (where the rope hangs from) on |anchor|.
  // When the window the charm hangs from moved, tells Dart so the rope
  // swings; when it jumped elsewhere, the charm simply goes along.
  void OnAnchorChanged(POINT anchor, bool moved, bool hidden);

  // Shows the charm unless the user hid it or a full-screen app is in front.
  void UpdateVisibility();

  // Acts on a pick from the tray menu. Launch at login is handled here;
  // everything the app remembers goes to Dart, which saves it.
  void OnTrayCommand(TrayIcon::Command command);

  // Starts the Customize process (showing the first-launch welcome if
  // |welcome|), or brings its window to the front if it is already open.
  void OpenCustomize(bool welcome);

  std::unique_ptr<AnchorTracker> anchor_tracker_;
  std::unique_ptr<TrayIcon> tray_;

  // The Customize window that last wrote to us, to reply to.
  HWND customize_ = nullptr;
  bool user_visible_ = true;
  bool fullscreen_hidden_ = false;

  std::vector<HitRect> hit_rects_;
  bool hold_interactive_ = false;
  bool interactive_ = false;
  bool cursor_was_near_ = false;
  // Tell Dart where the cursor is as it moves (for the mouse-wiggle
  // reaction). Off unless the user asked for that reaction.
  bool cursor_stream_ = false;

  // Chimes being played. PlaySound reads from memory while it plays, so a
  // sound stays in its slot until a later one takes the slot over.
  std::array<std::vector<uint8_t>, 4> sound_buffers_;
  size_t next_sound_ = 0;
  POINT last_cursor_ = {};

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      overlay_channel_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
