#ifndef RUNNER_ANCHOR_TRACKER_H_
#define RUNNER_ANCHOR_TRACKER_H_

#include <windows.h>

#include <functional>

// Decides where on screen the charm's anchor is: on the top edge of the
// window the user is working in, or on the top edge of the screen.
//
// It watches the foreground window with WinEvent hooks (no special
// permissions) and reports every change through a Listener:
// - the window it hangs from moved: |moved| is true, the charm should swing;
// - it jumped to another window or back to the screen: |moved| is false, the
//   charm goes along as it is;
// - a full-screen app is in front: |hidden| is true.
class AnchorTracker {
 public:
  using Listener = std::function<void(POINT anchor, bool moved, bool hidden)>;

  AnchorTracker(HWND overlay, POINT initial_anchor, Listener listener);
  ~AnchorTracker();

  AnchorTracker(const AnchorTracker&) = delete;
  AnchorTracker& operator=(const AnchorTracker&) = delete;

  // Hang from the active window (true) or the top of the screen (false).
  void SetFollowActiveWindow(bool follow);
  bool follows_active_window() const { return follow_; }

  // Slides the anchor along the edge it hangs from by |dx| physical pixels,
  // stopping short of the edge's ends. Returns how far it actually moved.
  // The listener hears about it with |moved| false: the caller already knows.
  LONG SlideBy(LONG dx);

  // Drops a window that has closed, been minimised or hidden. Cheap; call it
  // a few times a second.
  void Validate();

 private:
  // Where the anchor may sit: a span along a top edge.
  struct Edge {
    LONG left, right, top;
  };

  static void CALLBACK OnWinEvent(HWINEVENTHOOK hook, DWORD event, HWND hwnd,
                                  LONG id_object, LONG id_child,
                                  DWORD event_thread, DWORD event_time);

  void OnForeground(HWND hwnd);
  void SetTarget(HWND hwnd);
  bool IsUsable(HWND hwnd) const;
  bool IsFullScreen(HWND hwnd) const;
  Edge CurrentEdge() const;
  LONG Margin() const;
  void Update(bool moved);

  static AnchorTracker* instance_;

  HWND overlay_;
  Listener listener_;
  HWINEVENTHOOK foreground_hook_ = nullptr;
  HWINEVENTHOOK location_hook_ = nullptr;

  bool follow_ = false;
  HWND target_ = nullptr;
  bool hidden_ = false;
  POINT anchor_;

  // How far along the edge the anchor sits, 0 = left end, 1 = right end.
  // Kept separately for windows and the screen; dragging the pin sets it.
  double window_fraction_ = 0.72;
  double screen_fraction_ = 0.72;
};

#endif  // RUNNER_ANCHOR_TRACKER_H_
