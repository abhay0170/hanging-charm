#include "login_item.h"

#include <windows.h>

#include <string>

namespace {

constexpr wchar_t kRunKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kValueName[] = L"Charm";

// This executable's path, in quotes so spaces in it survive.
std::wstring Command() {
  wchar_t path[MAX_PATH] = {};
  GetModuleFileNameW(nullptr, path, MAX_PATH);
  return L"\"" + std::wstring(path) + L"\"";
}

}  // namespace

namespace login_item {

bool IsEnabled() {
  wchar_t value[MAX_PATH + 3] = {};
  DWORD size = sizeof(value);
  if (RegGetValueW(HKEY_CURRENT_USER, kRunKey, kValueName, RRF_RT_REG_SZ,
                   nullptr, value, &size) != ERROR_SUCCESS) {
    return false;
  }
  return _wcsicmp(value, Command().c_str()) == 0;
}

bool SetEnabled(bool enabled) {
  if (!enabled) {
    const LSTATUS status =
        RegDeleteKeyValueW(HKEY_CURRENT_USER, kRunKey, kValueName);
    return status == ERROR_SUCCESS || status == ERROR_FILE_NOT_FOUND;
  }
  const std::wstring command = Command();
  return RegSetKeyValueW(HKEY_CURRENT_USER, kRunKey, kValueName, REG_SZ,
                         command.c_str(),
                         static_cast<DWORD>((command.size() + 1) *
                                            sizeof(wchar_t))) == ERROR_SUCCESS;
}

}  // namespace login_item
