#ifndef RUNNER_PANIC_OVERLAY_WINDOW_H_
#define RUNNER_PANIC_OVERLAY_WINDOW_H_

#include <windows.h>

#include <cstdint>
#include <functional>
#include <string>
#include <vector>

// The panic switch's floating button (lib/features/panic_switch): a layered,
// always-on-top window showing the sticker with its own transparency. It never
// takes focus; drag to move it. The chosen gesture (two or three clicks in a
// row, or a long press) triggers with demo = false on the left button and
// demo = true on the right one.
class PanicOverlayWindow {
 public:
  explicit PanicOverlayWindow(std::function<void(bool demo)> on_trigger);
  ~PanicOverlayWindow();

  PanicOverlayWindow(const PanicOverlayWindow&) = delete;
  PanicOverlayWindow& operator=(const PanicOverlayWindow&) = delete;

  // Shows the PNG/JPEG |image| |width| pixels wide (at 100% scaling) and
  // |opacity| (0-1) opaque, set off by |gesture|: "double", "triple" or
  // "hold". False when it cannot be decoded.
  bool Show(const std::vector<uint8_t>& image, int width, double opacity,
            const std::string& gesture);
  void Hide();

 private:
  static LRESULT CALLBACK WndProc(HWND window, UINT message, WPARAM wparam,
                                  LPARAM lparam);
  LRESULT HandleMessage(HWND window, UINT message, WPARAM wparam,
                        LPARAM lparam);
  bool EnsureWindow();
  // Counts a click of one button and triggers on the chosen gesture.
  void OnClick(bool demo);

  std::function<void(bool demo)> on_trigger_;
  HWND window_ = nullptr;
  bool placed_ = false;

  // Drag state: the cursor where the button went down, and whether it moved
  // far enough to be a drag rather than a click.
  POINT press_ = {};
  POINT window_at_press_ = {};
  bool pressed_ = false;
  bool dragged_ = false;

  // Clicks in a row, for the triple click, of each button (left, right).
  int clicks_[2] = {0, 0};
  DWORD last_click_[2] = {0, 0};
  // When each button went down, for the long press.
  DWORD pressed_at_[2] = {0, 0};
  std::string gesture_ = "triple";
};

#endif  // RUNNER_PANIC_OVERLAY_WINDOW_H_
