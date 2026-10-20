#ifndef RUNNER_APP_MESSAGES_H_
#define RUNNER_APP_MESSAGES_H_

#include <windows.h>

#include <string>

// Messages between the charm process and the Customize process (the same
// app started with --customize). Each message is a UTF-8 JSON string sent
// with WM_COPYDATA; the native side never looks inside, Dart does.
namespace app_messages {

// The command-line switch that starts the Customize window instead of the
// charm.
constexpr wchar_t kCustomizeSwitch[] = L"--customize";

// WM_COPYDATA tags, so stray messages from elsewhere are ignored.
constexpr ULONG_PTR kToCharm = 0x43484D31;      // "CHM1"
constexpr ULONG_PTR kToCustomize = 0x43535A31;  // "CSZ1"

// Window titles each process finds the other by.
constexpr wchar_t kCharmTitle[] = L"Charm";
constexpr wchar_t kCustomizeTitle[] = L"Charm – Customize";

// The other process's top-level window with |title|, if it is running.
HWND Find(const wchar_t* title);

// Sends |json| to |target|, tagged |tag|, from |sender|. Returns false if the
// window is gone.
bool Send(HWND target, HWND sender, ULONG_PTR tag, const std::string& json);

// Reads a WM_COPYDATA message tagged |tag|. Returns false (and leaves |json|
// alone) if it has another tag or did not come from a copy of this app.
bool Receive(WPARAM wparam, LPARAM lparam, ULONG_PTR tag, std::string* json);

}  // namespace app_messages

#endif  // RUNNER_APP_MESSAGES_H_
