#ifndef RUNNER_PANIC_OVERLAY_WINDOW_H_
#define RUNNER_PANIC_OVERLAY_WINDOW_H_

#include <windows.h>

#include <cstdint>
#include <functional>
#include <vector>

// The panic switch's floating button (lib/features/panic_switch): a layered,
// always-on-top window showing the sticker with its own transparency. It never
// takes focus; drag to move it, click it three times in a row to trigger.
class PanicOverlayWindow {
 public:
  explicit PanicOverlayWindow(std::function<void()> on_trigger);
  ~PanicOverlayWindow();

  PanicOverlayWindow(const PanicOverlayWindow&) = delete;
  PanicOverlayWindow& operator=(const PanicOverlayWindow&) = delete;

  // Shows the PNG/JPEG |image|; false when it cannot be decoded.
  bool Show(const std::vector<uint8_t>& image);
  void Hide();

 private:
  static LRESULT CALLBACK WndProc(HWND window, UINT message, WPARAM wparam,
                                  LPARAM lparam);
  LRESULT HandleMessage(HWND window, UINT message, WPARAM wparam,
                        LPARAM lparam);
  bool EnsureWindow();
  void OnClick();

  std::function<void()> on_trigger_;
  HWND window_ = nullptr;
  bool placed_ = false;

  // Drag state: the cursor where the button went down, and whether it moved
  // far enough to be a drag rather than a click.
  POINT press_ = {};
  POINT window_at_press_ = {};
  bool pressed_ = false;
  bool dragged_ = false;

  // Clicks in a row, for the triple click.
  int clicks_ = 0;
  DWORD last_click_ = 0;
};

#endif  // RUNNER_PANIC_OVERLAY_WINDOW_H_
