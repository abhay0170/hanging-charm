#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter_windows.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

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

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  // A window just big enough for the charm to swing in, hanging from the top
  // of the primary display with its anchor at the window's top centre.
  // Dragging the anchor moves the whole window.
  constexpr double kWindowWidth = 520;
  constexpr double kWindowHeight = 420;
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
  if (!window.Create(L"Charm", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
