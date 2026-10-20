#ifndef RUNNER_CUSTOMIZE_WINDOW_H_
#define RUNNER_CUSTOMIZE_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>
#include <string>

#include "win32_window.h"

// The Customize window: an ordinary app window, the only window of a
// separate process (the app started with --customize) running the
// `customizeMain` Dart entry point. Closing it ends that process, so it
// leaves nothing behind in the charm.
//
// It owns no settings. Messages from its UI go to the charm process, which
// applies and saves them, and the charm's replies come back here; both as
// JSON strings over WM_COPYDATA (see app_messages.h).
class CustomizeWindow : public Win32Window {
 public:
  explicit CustomizeWindow(const flutter::DartProject& project);
  ~CustomizeWindow() override;

 protected:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // Smallest size the window may be dragged to, in logical pixels.
  static constexpr int kMinWidth = 680;
  static constexpr int kMinHeight = 480;

  void HandleCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Shows the Windows "Open" dialog for pictures. Empty if cancelled.
  std::wstring PickImage();

  flutter::DartProject project_;
  std::unique_ptr<flutter::FlutterViewController> controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_CUSTOMIZE_WINDOW_H_
