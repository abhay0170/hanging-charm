#include "tray_icon.h"

#include <shellapi.h>

#include "resource.h"

namespace {

constexpr UINT kIconId = 1;
constexpr wchar_t kTooltip[] = L"Charm";

enum MenuId : UINT {
  kMenuCustomize = 1,
  kMenuVisible,
  kMenuFollow,
  kMenuLaunchAtLogin,
  kMenuQuit,
};

}  // namespace

TrayIcon::TrayIcon(HWND owner)
    : owner_(owner),
      taskbar_created_(RegisterWindowMessageW(L"TaskbarCreated")) {
  const UINT dpi = GetDpiForWindow(owner);
  icon_ = static_cast<HICON>(LoadImageW(
      GetModuleHandle(nullptr), MAKEINTRESOURCEW(IDI_APP_ICON), IMAGE_ICON,
      GetSystemMetricsForDpi(SM_CXSMICON, dpi),
      GetSystemMetricsForDpi(SM_CYSMICON, dpi), LR_DEFAULTCOLOR));
  Add();
}

TrayIcon::~TrayIcon() {
  NOTIFYICONDATAW data = {sizeof(data)};
  data.hWnd = owner_;
  data.uID = kIconId;
  Shell_NotifyIconW(NIM_DELETE, &data);
  if (icon_) DestroyIcon(icon_);
}

void TrayIcon::Add() {
  NOTIFYICONDATAW data = {sizeof(data)};
  data.hWnd = owner_;
  data.uID = kIconId;
  data.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP | NIF_SHOWTIP;
  data.uCallbackMessage = kMessage;
  data.hIcon = icon_;
  wcscpy_s(data.szTip, kTooltip);
  Shell_NotifyIconW(NIM_ADD, &data);
}

TrayIcon::Command TrayIcon::HandleMessage(
    UINT message, LPARAM lparam, const std::function<State()>& state) {
  if (message == taskbar_created_) {
    // Explorer restarted and forgot every tray icon.
    Add();
    return Command::kNone;
  }
  if (message != kMessage) return Command::kNone;
  const UINT event = LOWORD(lparam);
  if (event != WM_LBUTTONUP && event != WM_RBUTTONUP) return Command::kNone;
  return ShowMenu(state());
}

TrayIcon::Command TrayIcon::ShowMenu(const State& state) {
  HMENU menu = CreatePopupMenu();
  auto check = [](bool on) { return on ? MF_CHECKED : MF_UNCHECKED; };
  AppendMenuW(menu, MF_STRING, kMenuCustomize, L"Customize…");
  SetMenuDefaultItem(menu, kMenuCustomize, FALSE);
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(menu, MF_STRING | check(state.visible), kMenuVisible,
              L"Show charm");
  AppendMenuW(menu, MF_STRING | check(state.follow), kMenuFollow,
              L"Hang from window");
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(menu, MF_STRING | check(state.launch_at_login),
              kMenuLaunchAtLogin, L"Launch at login");
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(menu, MF_STRING, kMenuQuit, L"Quit");

  POINT cursor;
  GetCursorPos(&cursor);
  // Without this the menu would not close when clicking elsewhere.
  SetForegroundWindow(owner_);
  const UINT picked = static_cast<UINT>(TrackPopupMenuEx(
      menu, TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON | TPM_BOTTOMALIGN,
      cursor.x, cursor.y, owner_, nullptr));
  PostMessage(owner_, WM_NULL, 0, 0);
  DestroyMenu(menu);

  switch (picked) {
    case kMenuCustomize:
      return Command::kOpenCustomize;
    case kMenuVisible:
      return Command::kToggleVisible;
    case kMenuFollow:
      return Command::kToggleFollow;
    case kMenuLaunchAtLogin:
      return Command::kToggleLaunchAtLogin;
    case kMenuQuit:
      return Command::kQuit;
    default:
      return Command::kNone;
  }
}
