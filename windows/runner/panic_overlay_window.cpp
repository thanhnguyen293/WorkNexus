#include "panic_overlay_window.h"

#include <flutter_windows.h>

#include <shlwapi.h>
#include <wincodec.h>
#include <windowsx.h>
#include <wrl/client.h>

#include <algorithm>
#include <cstdlib>

using Microsoft::WRL::ComPtr;

namespace {

constexpr wchar_t kClassName[] = L"WORKNEXUS_PANIC_OVERLAY";

// The button's width in pixels at 100% scaling.
constexpr int kWidth = 120;

// How far (in pixels) the cursor may move before a press becomes a drag.
constexpr int kDragSlop = 3;

// Decodes |image| scaled to |width| pixels wide (keeping its proportions) into
// a top-down 32-bit premultiplied BGRA DIB section, as UpdateLayeredWindow
// wants. Null when it cannot be decoded.
HBITMAP DecodeScaled(const std::vector<uint8_t>& image, int width, SIZE* size) {
  ComPtr<IWICImagingFactory> factory;
  if (FAILED(CoCreateInstance(CLSID_WICImagingFactory, nullptr,
                              CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&factory)))) {
    return nullptr;
  }
  ComPtr<IStream> stream;
  stream.Attach(SHCreateMemStream(image.data(), static_cast<UINT>(image.size())));
  if (!stream) return nullptr;
  ComPtr<IWICBitmapDecoder> decoder;
  ComPtr<IWICBitmapFrameDecode> frame;
  if (FAILED(factory->CreateDecoderFromStream(
          stream.Get(), nullptr, WICDecodeMetadataCacheOnDemand, &decoder)) ||
      FAILED(decoder->GetFrame(0, &frame))) {
    return nullptr;
  }
  UINT source_width = 0;
  UINT source_height = 0;
  if (FAILED(frame->GetSize(&source_width, &source_height)) ||
      source_width == 0) {
    return nullptr;
  }
  const UINT height = std::max<UINT>(
      1, static_cast<UINT>(static_cast<double>(width) * source_height /
                           source_width));
  ComPtr<IWICBitmapScaler> scaler;
  ComPtr<IWICFormatConverter> converter;
  if (FAILED(factory->CreateBitmapScaler(&scaler)) ||
      FAILED(scaler->Initialize(frame.Get(), width, height,
                                WICBitmapInterpolationModeHighQualityCubic)) ||
      FAILED(factory->CreateFormatConverter(&converter)) ||
      FAILED(converter->Initialize(scaler.Get(), GUID_WICPixelFormat32bppPBGRA,
                                   WICBitmapDitherTypeNone, nullptr, 0.0,
                                   WICBitmapPaletteTypeCustom))) {
    return nullptr;
  }
  BITMAPINFO info = {};
  info.bmiHeader.biSize = sizeof(info.bmiHeader);
  info.bmiHeader.biWidth = width;
  info.bmiHeader.biHeight = -static_cast<LONG>(height);  // Top-down.
  info.bmiHeader.biPlanes = 1;
  info.bmiHeader.biBitCount = 32;
  info.bmiHeader.biCompression = BI_RGB;
  void* bits = nullptr;
  HBITMAP bitmap =
      CreateDIBSection(nullptr, &info, DIB_RGB_COLORS, &bits, nullptr, 0);
  if (!bitmap || !bits) {
    if (bitmap) DeleteObject(bitmap);
    return nullptr;
  }
  const UINT stride = width * 4;
  if (FAILED(converter->CopyPixels(nullptr, stride, stride * height,
                                   static_cast<BYTE*>(bits)))) {
    DeleteObject(bitmap);
    return nullptr;
  }
  size->cx = width;
  size->cy = static_cast<LONG>(height);
  return bitmap;
}

}  // namespace

PanicOverlayWindow::PanicOverlayWindow(std::function<void()> on_trigger)
    : on_trigger_(std::move(on_trigger)) {}

PanicOverlayWindow::~PanicOverlayWindow() {
  if (window_) DestroyWindow(window_);
}

bool PanicOverlayWindow::EnsureWindow() {
  if (window_) return true;
  HINSTANCE instance = GetModuleHandle(nullptr);
  WNDCLASSEXW cls = {};
  if (!GetClassInfoExW(instance, kClassName, &cls)) {
    cls.cbSize = sizeof(cls);
    cls.lpfnWndProc = WndProc;
    cls.hInstance = instance;
    cls.hCursor = LoadCursor(nullptr, IDC_HAND);
    cls.lpszClassName = kClassName;
    if (!RegisterClassExW(&cls)) return false;
  }
  window_ = CreateWindowExW(
      WS_EX_LAYERED | WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
      kClassName, L"WorkNexus", WS_POPUP, 0, 0, kWidth, kWidth, nullptr,
      nullptr, instance, this);
  return window_ != nullptr;
}

bool PanicOverlayWindow::Show(const std::vector<uint8_t>& image) {
  if (!EnsureWindow()) return false;
  const UINT dpi = FlutterDesktopGetDpiForMonitor(
      MonitorFromWindow(window_, MONITOR_DEFAULTTOPRIMARY));
  const int width = MulDiv(kWidth, dpi ? dpi : 96, 96);
  SIZE size = {};
  HBITMAP bitmap = DecodeScaled(image, width, &size);
  if (!bitmap) return false;

  RECT bounds = {};
  GetWindowRect(window_, &bounds);
  POINT origin = {bounds.left, bounds.top};
  if (!placed_) {
    // First time: the middle of the primary screen's work area.
    RECT work = {};
    SystemParametersInfo(SPI_GETWORKAREA, 0, &work, 0);
    origin.x = work.left + (work.right - work.left - size.cx) / 2;
    origin.y = work.top + (work.bottom - work.top - size.cy) / 2;
    placed_ = true;
  }

  HDC screen = GetDC(nullptr);
  HDC memory = CreateCompatibleDC(screen);
  HGDIOBJ previous = SelectObject(memory, bitmap);
  POINT source = {0, 0};
  BLENDFUNCTION blend = {AC_SRC_OVER, 0, 255, AC_SRC_ALPHA};
  UpdateLayeredWindow(window_, screen, &origin, &size, memory, &source, 0,
                      &blend, ULW_ALPHA);
  SelectObject(memory, previous);
  DeleteDC(memory);
  ReleaseDC(nullptr, screen);
  DeleteObject(bitmap);

  SetWindowPos(window_, HWND_TOPMOST, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_SHOWWINDOW);
  return true;
}

void PanicOverlayWindow::Hide() {
  if (window_) ShowWindow(window_, SW_HIDE);
}

LRESULT CALLBACK PanicOverlayWindow::WndProc(HWND window, UINT message,
                                             WPARAM wparam, LPARAM lparam) {
  if (message == WM_NCCREATE) {
    auto* create = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(create->lpCreateParams));
  } else if (auto* self = reinterpret_cast<PanicOverlayWindow*>(
                 GetWindowLongPtr(window, GWLP_USERDATA))) {
    return self->HandleMessage(window, message, wparam, lparam);
  }
  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT PanicOverlayWindow::HandleMessage(HWND window, UINT message,
                                          WPARAM wparam, LPARAM lparam) {
  switch (message) {
    case WM_MOUSEACTIVATE:
      // Clicking it must not pull focus away from the app in front.
      return MA_NOACTIVATE;
    case WM_LBUTTONDOWN: {
      GetCursorPos(&press_);
      RECT bounds = {};
      GetWindowRect(window, &bounds);
      window_at_press_ = {bounds.left, bounds.top};
      pressed_ = true;
      dragged_ = false;
      SetCapture(window);
      return 0;
    }
    case WM_MOUSEMOVE: {
      if (!pressed_) break;
      POINT now = {};
      GetCursorPos(&now);
      const int dx = now.x - press_.x;
      const int dy = now.y - press_.y;
      if (!dragged_ && std::abs(dx) <= kDragSlop && std::abs(dy) <= kDragSlop) {
        return 0;
      }
      dragged_ = true;
      SetWindowPos(window, nullptr, window_at_press_.x + dx,
                   window_at_press_.y + dy, 0, 0,
                   SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
      return 0;
    }
    case WM_LBUTTONUP:
      if (!pressed_) break;
      pressed_ = false;
      ReleaseCapture();
      if (dragged_) {
        clicks_ = 0;
      } else {
        OnClick();
      }
      return 0;
    case WM_CAPTURECHANGED:
      pressed_ = false;
      return 0;
  }
  return DefWindowProc(window, message, wparam, lparam);
}

void PanicOverlayWindow::OnClick() {
  const DWORD now = GetTickCount();
  clicks_ = (clicks_ > 0 && now - last_click_ <= GetDoubleClickTime())
                ? clicks_ + 1
                : 1;
  last_click_ = now;
  if (clicks_ >= 3) {
    clicks_ = 0;
    if (on_trigger_) on_trigger_();
  }
}
