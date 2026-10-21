#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter_windows.h>
#include <windows.h>

#include <algorithm>
#include <memory>

#include "app_messages.h"
#include "customize_window.h"
#include "flutter_window.h"
#include "utils.h"

namespace {

// Runs |window|'s message loop until it closes.
void RunMessageLoop() {
  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }
}

// The charm: a window just big enough for it to swing in, hanging from the
// top of the primary display with its anchor at the window's top centre.
// Moving the anchor moves the whole window.
int RunCharm(flutter::DartProject project) {
  // One charm at a time: a second copy (say, started again while launch at
  // login already started one) quietly exits. The mutex lives until exit.
  CreateMutexW(nullptr, FALSE, L"Local\\CharmApp.SingleInstance");
  if (GetLastError() == ERROR_ALREADY_EXISTS) return EXIT_SUCCESS;

  // The bead's centre is at most one rope length (180) from the anchor and
  // its image reaches 34 further, so 214 each way covers every swing.
  constexpr double kWindowWidth = 460;
  constexpr double kWindowHeight = 340;
  constexpr double kAnchorAt = 0.72;  // fraction of the screen width
  HMONITOR monitor = MonitorFromPoint({0, 0}, MONITOR_DEFAULTTOPRIMARY);
  MONITORINFO monitor_info = {sizeof(monitor_info)};
  GetMonitorInfo(monitor, &monitor_info);
  const RECT& screen = monitor_info.rcMonitor;
  const double scale = FlutterDesktopGetDpiForMonitor(monitor) / 96.0;
  const double anchor_x =
      screen.left + (screen.right - screen.left) * kAnchorAt;

  FlutterWindow window(project);
  Win32Window::Point origin(
      static_cast<unsigned int>(anchor_x - kWindowWidth / 2 * scale),
      screen.top);
  Win32Window::Size size(static_cast<unsigned int>(kWindowWidth * scale),
                         static_cast<unsigned int>(kWindowHeight * scale));
  if (!window.Create(app_messages::kCharmTitle, origin, size,
                     Win32Window::Kind::kOverlay)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);
  RunMessageLoop();
  return EXIT_SUCCESS;
}

// The Customize window, in a process of its own so that closing it gives
// all of its memory back. With |welcome| it shows the first-launch welcome.
int RunCustomize(flutter::DartProject project, bool welcome) {
  // One Customize window at a time: bring the open one forward instead.
  CreateMutexW(nullptr, FALSE, L"Local\\CharmApp.Customize");
  if (GetLastError() == ERROR_ALREADY_EXISTS) {
    if (HWND open = app_messages::FindCustomize()) SetForegroundWindow(open);
    return EXIT_SUCCESS;
  }

  // Centred on the screen the cursor is on.
  const int kWidth = welcome ? 720 : 860;
  const int kHeight = welcome ? 580 : 600;
  POINT cursor;
  GetCursorPos(&cursor);
  HMONITOR monitor = MonitorFromPoint(cursor, MONITOR_DEFAULTTONEAREST);
  MONITORINFO info = {sizeof(info)};
  GetMonitorInfo(monitor, &info);
  const RECT& work = info.rcWork;
  const double scale = FlutterDesktopGetDpiForMonitor(monitor) / 96.0;
  const LONG width = static_cast<LONG>(kWidth * scale);
  const LONG height = static_cast<LONG>(kHeight * scale);

  project.set_dart_entrypoint("customizeMain");
  CustomizeWindow window(project);
  Win32Window::Point origin(
      static_cast<unsigned int>(work.left + (work.right - work.left - width) / 2),
      static_cast<unsigned int>(work.top + (work.bottom - work.top - height) / 2));
  Win32Window::Size size(static_cast<unsigned int>(width),
                         static_cast<unsigned int>(height));
  if (!window.Create(
          welcome ? app_messages::kWelcomeTitle : app_messages::kCustomizeTitle,
          origin, size, Win32Window::Kind::kNormal)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);
  RunMessageLoop();
  return EXIT_SUCCESS;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");
  std::vector<std::string> arguments = GetCommandLineArguments();
  auto has = [&arguments](const char* flag) {
    return std::find(arguments.begin(), arguments.end(), flag) !=
           arguments.end();
  };
  const bool customize = has("--customize");
  const bool welcome = has("--welcome");
  // The Customize side's Dart reads --welcome from these too.
  project.set_dart_entrypoint_arguments(std::move(arguments));

  const int code = customize ? RunCustomize(std::move(project), welcome)
                             : RunCharm(std::move(project));
  ::CoUninitialize();
  return code;
}
