#include "flutter_window.h"

#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <cmath>
#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "login_item.h"

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

  RECT window;
  GetWindowRect(GetHandle(), &window);
  const POINT anchor = {(window.left + window.right) / 2, window.top};
  anchor_tracker_ = std::make_unique<AnchorTracker>(
      GetHandle(), anchor, [this](POINT anchor, bool moved, bool hidden) {
        OnAnchorChanged(anchor, moved, hidden);
      });
  tray_ = std::make_unique<TrayIcon>(GetHandle());

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
    // Slides the anchor (and the window with it) along the edge it hangs
    // from by dx logical pixels. Returns the dx actually applied.
    const auto* dx = std::get_if<double>(call.arguments());
    if (!dx) {
      result->Error("bad_args", "moveBy expects a double");
      return;
    }
    const double scale = GetDpiForWindow(GetHandle()) / 96.0;
    const LONG applied =
        anchor_tracker_->SlideBy(static_cast<LONG>(std::lround(*dx * scale)));
    result->Success(flutter::EncodableValue(applied / scale));
  } else if (method == "setFollowActive") {
    // Hang from the active window (true) or the top of the screen (false).
    const auto* follow = std::get_if<bool>(call.arguments());
    if (!follow) {
      result->Error("bad_args", "setFollowActive expects a bool");
      return;
    }
    anchor_tracker_->SetFollowActiveWindow(*follow);
    result->Success();
  } else if (method == "setCharmVisible") {
    const auto* visible = std::get_if<bool>(call.arguments());
    if (!visible) {
      result->Error("bad_args", "setCharmVisible expects a bool");
      return;
    }
    user_visible_ = *visible;
    UpdateVisibility();
    result->Success();
  } else if (method == "getAnchorFractions") {
    result->Success(flutter::EncodableValue(std::vector<double>{
        anchor_tracker_->window_fraction(),
        anchor_tracker_->screen_fraction()}));
  } else if (method == "setAnchorFractions") {
    // [window fraction, screen fraction], restored from saved settings.
    const auto* values = std::get_if<std::vector<double>>(call.arguments());
    if (!values || values->size() != 2) {
      result->Error("bad_args", "setAnchorFractions expects 2 doubles");
      return;
    }
    anchor_tracker_->SetFractions((*values)[0], (*values)[1]);
    result->Success();
  } else if (method == "getLaunchAtLogin") {
    result->Success(flutter::EncodableValue(login_item::IsEnabled()));
  } else if (method == "setLaunchAtLogin") {
    const auto* enabled = std::get_if<bool>(call.arguments());
    if (!enabled) {
      result->Error("bad_args", "setLaunchAtLogin expects a bool");
      return;
    }
    result->Success(flutter::EncodableValue(login_item::SetEnabled(*enabled)));
  } else if (method == "quit") {
    PostMessage(GetHandle(), WM_CLOSE, 0, 0);
    result->Success();
  } else {
    result->NotImplemented();
  }
}

void FlutterWindow::UpdateVisibility() {
  HWND hwnd = GetHandle();
  if (!hwnd) return;
  const bool show = user_visible_ && !fullscreen_hidden_;
  if (show != (IsWindowVisible(hwnd) != FALSE)) {
    ShowWindow(hwnd, show ? SW_SHOWNOACTIVATE : SW_HIDE);
  }
}

void FlutterWindow::OnTrayCommand(TrayIcon::Command command) {
  const char* name = nullptr;
  switch (command) {
    case TrayIcon::Command::kToggleLaunchAtLogin:
      login_item::SetEnabled(!login_item::IsEnabled());
      return;
    case TrayIcon::Command::kToggleVisible:
      name = "toggleVisible";
      break;
    case TrayIcon::Command::kToggleFollow:
      name = "toggleFollow";
      break;
    case TrayIcon::Command::kQuit:
      // Dart saves what it is holding, then asks to quit.
      name = "quit";
      break;
    case TrayIcon::Command::kNone:
      return;
  }
  if (overlay_channel_) {
    overlay_channel_->InvokeMethod(
        "trayCommand", std::make_unique<flutter::EncodableValue>(name));
  }
}

void FlutterWindow::OnAnchorChanged(POINT anchor, bool moved, bool hidden) {
  HWND hwnd = GetHandle();
  if (!hwnd) return;
  if (hidden != fullscreen_hidden_) {
    fullscreen_hidden_ = hidden;
    UpdateVisibility();
  }
  RECT window;
  GetWindowRect(hwnd, &window);
  const LONG half_width = (window.right - window.left) / 2;
  const LONG dx = anchor.x - (window.left + half_width);
  const LONG dy = anchor.y - window.top;
  if (dx == 0 && dy == 0) return;
  SetWindowPos(hwnd, nullptr, anchor.x - half_width, anchor.y, 0, 0,
               SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
  if (moved && overlay_channel_) {
    const double scale = GetDpiForWindow(hwnd) / 96.0;
    overlay_channel_->InvokeMethod(
        "anchorMoved",
        std::make_unique<flutter::EncodableValue>(flutter::EncodableList{
            flutter::EncodableValue(dx / scale),
            flutter::EncodableValue(dy / scale)}));
  }
}

void FlutterWindow::CheckCursor() {
  HWND hwnd = GetHandle();
  if (!hwnd) return;
  if (anchor_tracker_) anchor_tracker_->Validate();
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
  tray_ = nullptr;
  anchor_tracker_ = nullptr;
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

  if (tray_) {
    const TrayIcon::Command command =
        tray_->HandleMessage(message, lparam, [this]() -> TrayIcon::State {
          return {user_visible_,
                  anchor_tracker_ && anchor_tracker_->follows_active_window(),
                  login_item::IsEnabled()};
        });
    if (command != TrayIcon::Command::kNone) {
      OnTrayCommand(command);
      return 0;
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
