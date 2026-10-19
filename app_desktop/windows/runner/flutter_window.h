#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>
#include <vector>

#include "anchor_tracker.h"
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

  std::unique_ptr<AnchorTracker> anchor_tracker_;
  bool hidden_ = false;

  std::vector<HitRect> hit_rects_;
  bool hold_interactive_ = false;
  bool interactive_ = false;
  bool cursor_was_near_ = false;
  POINT last_cursor_ = {};

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      overlay_channel_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
