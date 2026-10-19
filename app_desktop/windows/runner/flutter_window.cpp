#include "flutter_window.h"

#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <cmath>
#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  overlay_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "charm/overlay",
          &flutter::StandardMethodCodec::GetInstance());
  overlay_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleOverlayCall(call, std::move(result));
      });
  SetTimer(GetHandle(), kCursorTimer, kCursorIntervalMs, nullptr);

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::HandleOverlayCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = call.method_name();

  if (method == "setHitRects") {
    // Flat [left, top, right, bottom, ...] in logical pixels: the only places
    // the window takes clicks.
    const auto* values = std::get_if<std::vector<double>>(call.arguments());
    if (!values || values->size() % 4 != 0) {
      result->Error("bad_args", "setHitRects expects 4 doubles per rect");
      return;
    }
    hit_rects_.clear();
    for (size_t i = 0; i < values->size(); i += 4) {
      hit_rects_.push_back({(*values)[i], (*values)[i + 1], (*values)[i + 2],
                            (*values)[i + 3]});
    }
    CheckCursor();
    result->Success();
  } else if (method == "holdInteractive") {
    // Keeps clicks while a drag is in progress, even off the hit rects.
    const auto* hold = std::get_if<bool>(call.arguments());
    if (!hold) {
      result->Error("bad_args", "holdInteractive expects a bool");
      return;
    }
    hold_interactive_ = *hold;
    CheckCursor();
    result->Success();
  } else if (method == "moveBy") {
    // Slides the window sideways by dx logical pixels, keeping its centre
    // (the anchor) on the monitor. Returns the dx actually applied.
    const auto* dx = std::get_if<double>(call.arguments());
    if (!dx) {
      result->Error("bad_args", "moveBy expects a double");
      return;
    }
    HWND hwnd = GetHandle();
    RECT window;
    GetWindowRect(hwnd, &window);
    MONITORINFO monitor = {sizeof(monitor)};
    GetMonitorInfo(MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST),
                   &monitor);
    const double scale = GetDpiForWindow(hwnd) / 96.0;
    const LONG half_width = (window.right - window.left) / 2;
    const LONG margin = static_cast<LONG>(kAnchorEdgeMargin * scale);
    const LONG min_left = monitor.rcMonitor.left + margin - half_width;
    const LONG max_left = monitor.rcMonitor.right - margin - half_width;
    LONG left = window.left + static_cast<LONG>(std::lround(*dx * scale));
    left = std::clamp(left, min_left, max_left);
    SetWindowPos(hwnd, nullptr, left, window.top, 0, 0,
                 SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
    result->Success(
        flutter::EncodableValue((left - window.left) / scale));
  } else if (method == "quit") {
    PostMessage(GetHandle(), WM_CLOSE, 0, 0);
    result->Success();
  } else {
    result->NotImplemented();
  }
}

void FlutterWindow::CheckCursor() {
  HWND hwnd = GetHandle();
  if (!hwnd) return;
  POINT point;
  GetCursorPos(&point);
  ScreenToClient(hwnd, &point);
  const double scale = GetDpiForWindow(hwnd) / 96.0;
  const double x = point.x / scale;
  const double y = point.y / scale;

  bool inside = false;
  bool near_rect = false;
  for (const HitRect& r : hit_rects_) {
    inside |= x >= r.left && x <= r.right && y >= r.top && y <= r.bottom;
    near_rect |= x >= r.left - kNearMargin && x <= r.right + kNearMargin &&
                 y >= r.top - kNearMargin && y <= r.bottom + kNearMargin;
  }

  const bool interactive = hold_interactive_ || inside;
  if (interactive != interactive_) {
    interactive_ = interactive;
    LONG_PTR ex_style = GetWindowLongPtr(hwnd, GWL_EXSTYLE);
    ex_style = interactive ? (ex_style & ~WS_EX_TRANSPARENT)
                           : (ex_style | WS_EX_TRANSPARENT);
    SetWindowLongPtr(hwnd, GWL_EXSTYLE, ex_style);
  }

  // Dart only hears about the cursor when it moves near the charm, so a
  // resting charm costs nothing on the Dart side.
  if (!overlay_channel_) return;
  const bool moved = point.x != last_cursor_.x || point.y != last_cursor_.y;
  last_cursor_ = point;
  if (near_rect && moved) {
    overlay_channel_->InvokeMethod(
        "cursorNear",
        std::make_unique<flutter::EncodableValue>(flutter::EncodableList{
            flutter::EncodableValue(x), flutter::EncodableValue(y)}));
  } else if (!near_rect && cursor_was_near_) {
    overlay_channel_->InvokeMethod("cursorAway", nullptr);
  }
  cursor_was_near_ = near_rect;
}

void FlutterWindow::OnDestroy() {
  if (GetHandle()) KillTimer(GetHandle(), kCursorTimer);
  overlay_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_TIMER:
      if (wparam == kCursorTimer) {
        CheckCursor();
        return 0;
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
