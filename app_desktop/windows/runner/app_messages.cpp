#include "app_messages.h"

namespace {

constexpr wchar_t kWindowClass[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

// The full path of the executable that owns |hwnd|.
std::wstring ExecutableOf(HWND hwnd) {
  DWORD pid = 0;
  GetWindowThreadProcessId(hwnd, &pid);
  HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (!process) return {};
  wchar_t path[MAX_PATH] = {};
  DWORD size = MAX_PATH;
  const BOOL ok = QueryFullProcessImageNameW(process, 0, path, &size);
  CloseHandle(process);
  return ok ? std::wstring(path, size) : std::wstring();
}

std::wstring OwnExecutable() {
  wchar_t path[MAX_PATH] = {};
  GetModuleFileNameW(nullptr, path, MAX_PATH);
  return path;
}

}  // namespace

namespace app_messages {

HWND Find(const wchar_t* title) { return FindWindowW(kWindowClass, title); }

bool Send(HWND target, HWND sender, ULONG_PTR tag, const std::string& json) {
  if (!target || !IsWindow(target)) return false;
  COPYDATASTRUCT data = {};
  data.dwData = tag;
  data.cbData = static_cast<DWORD>(json.size());
  data.lpData = const_cast<char*>(json.data());
  DWORD_PTR result = 0;
  // A timeout rather than SendMessage, so a hung peer cannot hang this one.
  return SendMessageTimeoutW(target, WM_COPYDATA,
                             reinterpret_cast<WPARAM>(sender),
                             reinterpret_cast<LPARAM>(&data),
                             SMTO_ABORTIFHUNG, 1000, &result) != 0;
}

bool Receive(WPARAM wparam, LPARAM lparam, ULONG_PTR tag, std::string* json) {
  const auto* data = reinterpret_cast<const COPYDATASTRUCT*>(lparam);
  if (!data || data->dwData != tag) return false;
  // Only another copy of this very app may change its settings.
  const HWND sender = reinterpret_cast<HWND>(wparam);
  if (_wcsicmp(ExecutableOf(sender).c_str(), OwnExecutable().c_str()) != 0) {
    return false;
  }
  json->assign(static_cast<const char*>(data->lpData), data->cbData);
  return true;
}

}  // namespace app_messages
