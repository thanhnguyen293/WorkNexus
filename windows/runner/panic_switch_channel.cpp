#include "panic_switch_channel.h"

#include <dwmapi.h>
#include <flutter/standard_method_codec.h>
#include <shellapi.h>
#include <windows.h>

#include <algorithm>
#include <cwctype>
#include <iterator>
#include <map>
#include <string>
#include <vector>

#include "utils.h"

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

std::wstring Utf16FromUtf8(const std::string& utf8) {
  if (utf8.empty()) return std::wstring();
  const int length = MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                                         static_cast<int>(utf8.size()),
                                         nullptr, 0);
  std::wstring out(length, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                      out.data(), length);
  return out;
}

std::wstring Lower(std::wstring text) {
  std::transform(text.begin(), text.end(), text.begin(),
                 [](wchar_t c) { return static_cast<wchar_t>(std::towlower(c)); });
  return text;
}

// The full path of the executable that owns |window|; empty when unknown.
std::wstring ExecutableOf(HWND window) {
  DWORD pid = 0;
  GetWindowThreadProcessId(window, &pid);
  if (pid == 0 || pid == GetCurrentProcessId()) return std::wstring();
  HANDLE process =
      OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (!process) return std::wstring();
  wchar_t path[MAX_PATH * 2];
  DWORD size = static_cast<DWORD>(std::size(path));
  const BOOL ok = QueryFullProcessImageNameW(process, 0, path, &size);
  CloseHandle(process);
  return ok ? std::wstring(path, size) : std::wstring();
}

// Whether |window| is one a user sees as an app window: a visible, unowned,
// top-level window with a title, not a tool window and not cloaked (Windows
// keeps suspended Store apps' windows "visible" but cloaked).
bool IsAppWindow(HWND window) {
  if (!IsWindowVisible(window) || GetWindow(window, GW_OWNER) != nullptr) {
    return false;
  }
  if (GetWindowLongPtr(window, GWL_EXSTYLE) & WS_EX_TOOLWINDOW) return false;
  if (GetWindowTextLengthW(window) == 0) return false;
  DWORD cloaked = 0;
  DwmGetWindowAttribute(window, DWMWA_CLOAKED, &cloaked, sizeof(cloaked));
  return cloaked == 0;
}

// The app windows of every running app, by executable path (lower case).
std::map<std::wstring, std::vector<HWND>> AppWindows() {
  std::map<std::wstring, std::vector<HWND>> windows;
  EnumWindows(
      [](HWND window, LPARAM param) -> BOOL {
        if (!IsAppWindow(window)) return TRUE;
        const std::wstring exe = ExecutableOf(window);
        if (exe.empty()) return TRUE;
        auto* out =
            reinterpret_cast<std::map<std::wstring, std::vector<HWND>>*>(param);
        (*out)[Lower(exe)].push_back(window);
        return TRUE;
      },
      reinterpret_cast<LPARAM>(&windows));
  return windows;
}

// The executable's "File description" (e.g. "Android Studio"), else its file
// name without ".exe".
std::wstring DisplayName(const std::wstring& path) {
  DWORD handle = 0;
  const DWORD size = GetFileVersionInfoSizeW(path.c_str(), &handle);
  if (size > 0) {
    std::vector<BYTE> data(size);
    struct Translation {
      WORD language;
      WORD codepage;
    }* translations = nullptr;
    UINT length = 0;
    if (GetFileVersionInfoW(path.c_str(), 0, size, data.data()) &&
        VerQueryValueW(data.data(), L"\\VarFileInfo\\Translation",
                       reinterpret_cast<void**>(&translations), &length) &&
        length >= sizeof(Translation)) {
      wchar_t key[64];
      swprintf_s(key, L"\\StringFileInfo\\%04x%04x\\FileDescription",
                 translations[0].language, translations[0].codepage);
      wchar_t* value = nullptr;
      UINT value_length = 0;
      if (VerQueryValueW(data.data(), key, reinterpret_cast<void**>(&value),
                         &value_length) &&
          value_length > 1) {
        return std::wstring(value);
      }
    }
  }
  std::wstring name = path.substr(path.find_last_of(L"\\/") + 1);
  if (name.size() > 4 && Lower(name.substr(name.size() - 4)) == L".exe") {
    name.resize(name.size() - 4);
  }
  return name;
}

// Brings |window| to the front. Windows only lets the foreground process hand
// the foreground over; WorkNexus is usually in the background when the
// sticker arrives, so it first borrows the right: a synthetic Alt press counts
// as user input to this process, and attaching to the foreground thread's
// input shares its foreground permission.
void ForceForeground(HWND window) {
  if (IsIconic(window)) ShowWindow(window, SW_RESTORE);
  INPUT alt[2] = {};
  alt[0].type = INPUT_KEYBOARD;
  alt[0].ki.wVk = VK_MENU;
  alt[1].type = INPUT_KEYBOARD;
  alt[1].ki.wVk = VK_MENU;
  alt[1].ki.dwFlags = KEYEVENTF_KEYUP;
  SendInput(2, alt, sizeof(INPUT));

  HWND foreground = GetForegroundWindow();
  const DWORD foreground_thread =
      foreground ? GetWindowThreadProcessId(foreground, nullptr) : 0;
  const DWORD this_thread = GetCurrentThreadId();
  const bool attached = foreground_thread != 0 &&
                        foreground_thread != this_thread &&
                        AttachThreadInput(this_thread, foreground_thread, TRUE);
  BringWindowToTop(window);
  SetForegroundWindow(window);
  if (attached) AttachThreadInput(this_thread, foreground_thread, FALSE);
}

const std::string* StringArg(const flutter::MethodCall<EncodableValue>& call,
                             const char* key) {
  const auto* args = std::get_if<EncodableMap>(call.arguments());
  if (!args) return nullptr;
  const auto it = args->find(EncodableValue(key));
  return it == args->end() ? nullptr : std::get_if<std::string>(&it->second);
}

}  // namespace

PanicSwitchChannel::PanicSwitchChannel(flutter::BinaryMessenger* messenger) {
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "worknexus/panic_switch",
      &flutter::StandardMethodCodec::GetInstance());
  overlay_ = std::make_unique<PanicOverlayWindow>([this]() {
    channel_->InvokeMethod("overlayTriggered", nullptr);
  });
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        const std::string& method = call.method_name();
        if (method == "listApps") {
          std::vector<std::pair<std::wstring, std::wstring>> apps;
          for (const auto& entry : AppWindows()) {
            const std::wstring exe = ExecutableOf(entry.second.front());
            if (!exe.empty()) apps.emplace_back(DisplayName(exe), exe);
          }
          std::sort(apps.begin(), apps.end(), [](const auto& a, const auto& b) {
            return Lower(a.first) < Lower(b.first);
          });
          EncodableList list;
          for (const auto& [name, exe] : apps) {
            list.push_back(EncodableMap{
                {EncodableValue("id"), EncodableValue(Utf8FromUtf16(exe.c_str()))},
                {EncodableValue("name"),
                 EncodableValue(Utf8FromUtf16(name.c_str()))},
            });
          }
          result->Success(EncodableValue(list));
        } else if (method == "activate") {
          const std::string* id = StringArg(call, "id");
          if (!id) return result->Error("bad_args", "Missing id");
          const std::wstring exe = Utf16FromUtf8(*id);
          const auto windows = AppWindows();
          const auto it = windows.find(Lower(exe));
          if (it != windows.end()) {
            ForceForeground(it->second.front());
            return result->Success();
          }
          // Not running (or no window yet): start it; it comes up in front.
          const auto started = reinterpret_cast<INT_PTR>(ShellExecuteW(
              nullptr, L"open", exe.c_str(), nullptr, nullptr, SW_SHOWNORMAL));
          if (started <= 32) {
            return result->Error("open_failed", "Could not start the app");
          }
          result->Success();
        } else if (method == "hide") {
          const std::string* id = StringArg(call, "id");
          if (!id) return result->Error("bad_args", "Missing id");
          const auto windows = AppWindows();
          const auto it = windows.find(Lower(Utf16FromUtf8(*id)));
          if (it != windows.end()) {
            // Async: a hung app must not stall WorkNexus.
            for (HWND window : it->second) ShowWindowAsync(window, SW_MINIMIZE);
          }
          result->Success();
        } else if (method == "showOverlay") {
          const auto* args = std::get_if<EncodableMap>(call.arguments());
          const auto it =
              args ? args->find(EncodableValue("image")) : EncodableMap::const_iterator();
          const auto* image =
              args && it != args->end()
                  ? std::get_if<std::vector<uint8_t>>(&it->second)
                  : nullptr;
          if (!image || !overlay_->Show(*image)) {
            return result->Error("overlay_failed", "Could not show the button");
          }
          result->Success();
        } else if (method == "hideOverlay") {
          overlay_->Hide();
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
}
