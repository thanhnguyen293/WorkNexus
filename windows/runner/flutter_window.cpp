#include "flutter_window.h"

#include <flutter/standard_method_codec.h>
#include <shobjidl.h>

#include <cstdint>
#include <optional>
#include <vector>

#include "activation.h"
#include "flutter/generated_plugin_registrant.h"

namespace {

// Shows and focuses |window|, as a second launch asks (see activation.h).
// ShowWindow, called from this process, tells the window it is shown
// (WM_SHOWWINDOW, which Flutter follows to leave its hidden state — SetWindowPos
// does not send it), restores a minimized window to the state it had, and
// leaves a maximized one maximized.
void ActivateWindow(HWND window) {
  if (IsIconic(window)) {
    ShowWindow(window, SW_RESTORE);
  } else if (!IsWindowVisible(window)) {
    ShowWindow(window, SW_SHOW);
  }
  if (!SetForegroundWindow(window)) {
    // Windows may still keep a background process from the foreground; flash
    // the taskbar button so the user is told.
    FLASHWINFO flash{};
    flash.cbSize = sizeof(flash);
    flash.hwnd = window;
    flash.dwFlags = FLASHW_TRAY | FLASHW_TIMERNOFG;
    flash.uCount = 3;
    FlashWindowEx(&flash);
  }
}

// An icon from |size|×|size| straight RGBA pixels, or null when they do not
// add up to that size.
HICON CreateBadgeIcon(const std::vector<uint8_t>& rgba, int size) {
  if (size <= 0 || rgba.size() != static_cast<size_t>(size) * size * 4) {
    return nullptr;
  }
  BITMAPV5HEADER header = {};
  header.bV5Size = sizeof(header);
  header.bV5Width = size;
  header.bV5Height = -size;  // Top-down rows, as Dart drew them.
  header.bV5Planes = 1;
  header.bV5BitCount = 32;
  header.bV5Compression = BI_BITFIELDS;
  header.bV5RedMask = 0x00FF0000;
  header.bV5GreenMask = 0x0000FF00;
  header.bV5BlueMask = 0x000000FF;
  header.bV5AlphaMask = 0xFF000000;
  void* bits = nullptr;
  HDC screen = GetDC(nullptr);
  HBITMAP color =
      CreateDIBSection(screen, reinterpret_cast<BITMAPINFO*>(&header),
                       DIB_RGB_COLORS, &bits, nullptr, 0);
  ReleaseDC(nullptr, screen);
  if (!color || !bits) {
    if (color) DeleteObject(color);
    return nullptr;
  }
  // Icons keep straight (not premultiplied) alpha, in BGRA order.
  auto* out = static_cast<uint8_t*>(bits);
  for (size_t i = 0; i < rgba.size(); i += 4) {
    out[i] = rgba[i + 2];
    out[i + 1] = rgba[i + 1];
    out[i + 2] = rgba[i];
    out[i + 3] = rgba[i + 3];
  }
  // The alpha channel decides transparency; the mask only has to exist.
  std::vector<uint8_t> mask_bits(((size + 15) / 16) * 2 * size, 0);
  HBITMAP mask = CreateBitmap(size, size, 1, 1, mask_bits.data());
  ICONINFO info = {};
  info.fIcon = TRUE;
  info.hbmMask = mask;
  info.hbmColor = color;
  HICON icon = mask ? CreateIconIndirect(&info) : nullptr;
  if (mask) DeleteObject(mask);
  DeleteObject(color);
  return icon;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetUpBadgeChannel();
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Dart shows the window itself, maximized when it was left maximized; Show()
  // (SW_SHOWNORMAL) on the first frame would then shrink it back to its normal
  // size. It only steps in if Dart has not shown the window.
  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    if (!::IsWindowVisible(GetHandle())) this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  badge_channel_ = nullptr;
  if (badge_icon_) {
    DestroyIcon(badge_icon_);
    badge_icon_ = nullptr;
  }
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::SetUpBadgeChannel() {
  badge_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "worknexus/app_icon_badge",
          &flutter::StandardMethodCodec::GetInstance());
  badge_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() != "set") {
          result->NotImplemented();
          return;
        }
        // No arguments clears the badge.
        HICON icon = nullptr;
        if (const auto* args =
                std::get_if<flutter::EncodableMap>(call.arguments())) {
          const auto rgba = args->find(flutter::EncodableValue("rgba"));
          const auto size = args->find(flutter::EncodableValue("size"));
          if (rgba != args->end() && size != args->end()) {
            const auto* pixels =
                std::get_if<std::vector<uint8_t>>(&rgba->second);
            const auto* side = std::get_if<int32_t>(&size->second);
            if (pixels && side) icon = CreateBadgeIcon(*pixels, *side);
          }
        }
        if (badge_icon_) DestroyIcon(badge_icon_);
        badge_icon_ = icon;
        ApplyBadge();
        result->Success();
      });
}

void FlutterWindow::ApplyBadge() {
  ITaskbarList3* taskbar = nullptr;
  if (FAILED(CoCreateInstance(CLSID_TaskbarList, nullptr, CLSCTX_INPROC_SERVER,
                              IID_PPV_ARGS(&taskbar)))) {
    return;
  }
  if (SUCCEEDED(taskbar->HrInit())) {
    taskbar->SetOverlayIcon(GetHandle(), badge_icon_, L"");
  }
  taskbar->Release();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // The taskbar button is (re)made after the window first shows and whenever
  // it comes back from the tray; an overlay set before then is lost.
  static const UINT taskbar_button_created =
      RegisterWindowMessage(L"TaskbarButtonCreated");
  if (message == taskbar_button_created && badge_icon_) {
    ApplyBadge();
  }

  // A second launch asks this instance to show itself.
  static const UINT activate_window =
      RegisterWindowMessage(kActivateMessageName);
  if (message == activate_window) {
    ActivateWindow(hwnd);
    return 0;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
