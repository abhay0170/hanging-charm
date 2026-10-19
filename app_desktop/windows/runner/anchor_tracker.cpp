#include "anchor_tracker.h"

#include <dwmapi.h>

#include <algorithm>
#include <cmath>
#include <cwchar>

namespace {

// Closest the anchor may come to either end of the edge, in logical pixels.
constexpr double kEdgeMargin = 16;

// Windows smaller than this (physical pixels) are not worth hanging from.
constexpr LONG kMinWidth = 200;
constexpr LONG kMinHeight = 100;

// Shell surfaces that come to the front briefly (taskbar, Start, Alt+Tab,
// the tray overflow). The charm stays where it is while they are open.
constexpr const wchar_t* kTransientClasses[] = {
    L"Shell_TrayWnd",
    L"Shell_SecondaryTrayWnd",
    L"Windows.UI.Core.CoreWindow",
    L"XamlExplorerHostIslandWindow",
    L"TopLevelWindowForOverflowXamlIsland",
    L"NotifyIconOverflowWindow",
    L"ForegroundStaging",
    L"MultitaskingViewFrame",
    L"TaskListThumbnailWnd",
};

// The desktop itself. Clicking it sends the charm back to the screen edge.
constexpr const wchar_t* kDesktopClasses[] = {L"Progman", L"WorkerW"};

template <size_t N>
bool ClassIn(HWND hwnd, const wchar_t* const (&classes)[N]) {
  wchar_t name[128] = {};
  GetClassNameW(hwnd, name, 128);
  for (const wchar_t* c : classes) {
    if (wcscmp(name, c) == 0) return true;
  }
  return false;
}

// The window's visible frame, without the invisible resize borders that
// GetWindowRect includes on Windows 10 and 11.
RECT VisibleFrame(HWND hwnd) {
  RECT frame;
  if (FAILED(DwmGetWindowAttribute(hwnd, DWMWA_EXTENDED_FRAME_BOUNDS, &frame,
                                   sizeof(frame)))) {
    GetWindowRect(hwnd, &frame);
  }
  return frame;
}

}  // namespace

AnchorTracker* AnchorTracker::instance_ = nullptr;

AnchorTracker::AnchorTracker(HWND overlay, POINT initial_anchor,
                             Listener listener)
    : overlay_(overlay), listener_(std::move(listener)),
      anchor_(initial_anchor) {
  instance_ = this;
  foreground_hook_ = SetWinEventHook(
      EVENT_SYSTEM_FOREGROUND, EVENT_SYSTEM_FOREGROUND, nullptr, OnWinEvent, 0,
      0, WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS);
}

AnchorTracker::~AnchorTracker() {
  if (location_hook_) UnhookWinEvent(location_hook_);
  if (foreground_hook_) UnhookWinEvent(foreground_hook_);
  if (instance_ == this) instance_ = nullptr;
}

void AnchorTracker::SetFollowActiveWindow(bool follow) {
  follow_ = follow;
  if (follow) {
    OnForeground(GetForegroundWindow());
  } else {
    SetTarget(nullptr);
  }
}

LONG AnchorTracker::SlideBy(LONG dx) {
  const Edge edge = CurrentEdge();
  const LONG margin = Margin();
  const LONG lo = edge.left + margin;
  const LONG hi = std::max(lo, edge.right - margin);
  const LONG x = std::clamp(anchor_.x + dx, lo, hi);
  const LONG applied = x - anchor_.x;
  const double width = static_cast<double>(edge.right - edge.left);
  if (width > 0) {
    (target_ ? window_fraction_ : screen_fraction_) = (x - edge.left) / width;
  }
  Update(false);
  return applied;
}

void AnchorTracker::Validate() {
  if (target_ && !IsUsable(target_)) SetTarget(nullptr);
}

// static
void CALLBACK AnchorTracker::OnWinEvent(HWINEVENTHOOK, DWORD event,
                                        HWND hwnd, LONG id_object,
                                        LONG id_child, DWORD, DWORD) {
  AnchorTracker* self = instance_;
  if (!self) return;
  if (event == EVENT_SYSTEM_FOREGROUND) {
    self->OnForeground(hwnd);
  } else if (event == EVENT_OBJECT_LOCATIONCHANGE && hwnd == self->target_ &&
             id_object == OBJID_WINDOW && id_child == CHILDID_SELF) {
    if (self->IsUsable(hwnd)) {
      self->Update(true);
    } else {
      self->SetTarget(nullptr);
    }
  }
}

void AnchorTracker::OnForeground(HWND hwnd) {
  if (!follow_ || !hwnd || hwnd == overlay_) return;
  if (ClassIn(hwnd, kTransientClasses)) return;
  if (ClassIn(hwnd, kDesktopClasses)) {
    SetTarget(nullptr);
    return;
  }
  if (IsUsable(hwnd)) SetTarget(hwnd);
}

void AnchorTracker::SetTarget(HWND hwnd) {
  if (hwnd != target_) {
    if (location_hook_) {
      UnhookWinEvent(location_hook_);
      location_hook_ = nullptr;
    }
    target_ = hwnd;
    if (hwnd) {
      // Location events only from the target's own thread, so cursor and
      // caret movement elsewhere does not wake this process.
      DWORD pid = 0;
      const DWORD tid = GetWindowThreadProcessId(hwnd, &pid);
      location_hook_ = SetWinEventHook(
          EVENT_OBJECT_LOCATIONCHANGE, EVENT_OBJECT_LOCATIONCHANGE, nullptr,
          OnWinEvent, pid, tid, WINEVENT_OUTOFCONTEXT);
    }
  }
  Update(false);
}

bool AnchorTracker::IsUsable(HWND hwnd) const {
  if (!IsWindow(hwnd) || !IsWindowVisible(hwnd) || IsIconic(hwnd)) {
    return false;
  }
  if (GetWindowLongPtr(hwnd, GWL_EXSTYLE) & WS_EX_TOOLWINDOW) return false;
  BOOL cloaked = FALSE;
  DwmGetWindowAttribute(hwnd, DWMWA_CLOAKED, &cloaked, sizeof(cloaked));
  if (cloaked) return false;
  const RECT frame = VisibleFrame(hwnd);
  return frame.right - frame.left >= kMinWidth &&
         frame.bottom - frame.top >= kMinHeight;
}

bool AnchorTracker::IsFullScreen(HWND hwnd) const {
  MONITORINFO monitor = {sizeof(monitor)};
  GetMonitorInfo(MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST), &monitor);
  const RECT frame = VisibleFrame(hwnd);
  return frame.left <= monitor.rcMonitor.left &&
         frame.top <= monitor.rcMonitor.top &&
         frame.right >= monitor.rcMonitor.right &&
         frame.bottom >= monitor.rcMonitor.bottom;
}

AnchorTracker::Edge AnchorTracker::CurrentEdge() const {
  if (target_) {
    const RECT frame = VisibleFrame(target_);
    return {frame.left, frame.right, frame.top};
  }
  MONITORINFO monitor = {sizeof(monitor)};
  GetMonitorInfo(MonitorFromPoint(anchor_, MONITOR_DEFAULTTONEAREST),
                 &monitor);
  return {monitor.rcMonitor.left, monitor.rcMonitor.right,
          monitor.rcMonitor.top};
}

LONG AnchorTracker::Margin() const {
  return static_cast<LONG>(kEdgeMargin * GetDpiForWindow(overlay_) / 96.0);
}

void AnchorTracker::Update(bool moved) {
  const bool hidden = target_ && IsFullScreen(target_);
  const Edge edge = CurrentEdge();
  const double fraction = target_ ? window_fraction_ : screen_fraction_;
  const LONG margin = Margin();
  const LONG lo = edge.left + margin;
  const LONG hi = std::max(lo, edge.right - margin);
  const LONG x = std::clamp(
      edge.left + static_cast<LONG>(std::lround((edge.right - edge.left) *
                                                fraction)),
      lo, hi);
  const POINT anchor = {x, edge.top};
  if (anchor.x == anchor_.x && anchor.y == anchor_.y && hidden == hidden_) {
    return;
  }
  anchor_ = anchor;
  hidden_ = hidden;
  listener_(anchor, moved, hidden);
}
