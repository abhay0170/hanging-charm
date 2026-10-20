#ifndef RUNNER_TRAY_ICON_H_
#define RUNNER_TRAY_ICON_H_

#include <windows.h>

#include <functional>

// The app's icon in the notification area, and the menu it opens.
//
// The owner window forwards its messages to HandleMessage, which shows the
// menu when the icon is clicked and returns what was picked. It also puts
// the icon back if Explorer restarts.
class TrayIcon {
 public:
  enum class Command {
    kNone,
    kToggleVisible,
    kToggleFollow,
    kToggleLaunchAtLogin,
    kQuit,
  };

  // What the menu's check marks show.
  struct State {
    bool visible;
    bool follow;
    bool launch_at_login;
  };

  // The message the icon sends its owner window.
  static constexpr UINT kMessage = WM_APP + 1;

  explicit TrayIcon(HWND owner);
  ~TrayIcon();

  TrayIcon(const TrayIcon&) = delete;
  TrayIcon& operator=(const TrayIcon&) = delete;

  // Returns the command picked from the menu, or kNone when |message| was
  // not a click on the icon (or the menu was dismissed). |state| is only
  // asked for when the menu is about to open.
  Command HandleMessage(UINT message, LPARAM lparam,
                        const std::function<State()>& state);

 private:
  void Add();
  Command ShowMenu(const State& state);

  HWND owner_;
  HICON icon_;
  UINT taskbar_created_;
};

#endif  // RUNNER_TRAY_ICON_H_
