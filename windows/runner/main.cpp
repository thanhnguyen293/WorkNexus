#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

constexpr wchar_t kSingleInstanceMutexName[] = L"Local\\WorkNexus";
constexpr wchar_t kWindowClassName[] = L"WORKNEXUS_RUNNER_WIN32_WINDOW";

HWND FindMainWindow() {
  for (int attempt = 0; attempt < 50; ++attempt) {
    HWND window = FindWindowW(kWindowClassName, nullptr);
    if (window != nullptr) {
      return window;
    }
    Sleep(100);
  }
  return nullptr;
}

void FocusExistingWindow() {
  HWND window = FindMainWindow();
  if (window == nullptr) {
    return;
  }

  ShowWindow(window, IsIconic(window) ? SW_RESTORE : SW_SHOW);
  if (!SetForegroundWindow(window)) {
    // Windows may block foreground promotion from a background process.
    // Flash the taskbar icon so the user is still notified.
    FLASHWINFO fi{};
    fi.cbSize = sizeof(fi);
    fi.hwnd = window;
    fi.dwFlags = FLASHW_TRAY | FLASHW_TIMERNOFG;
    fi.uCount = 3;
    FlashWindowEx(&fi);
  }
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  HANDLE instance_mutex =
      CreateMutexW(nullptr, TRUE, kSingleInstanceMutexName);
  const DWORD mutex_error = GetLastError();
  if (instance_mutex == nullptr) {
    return EXIT_FAILURE;
  }
  if (mutex_error == ERROR_ALREADY_EXISTS) {
    FocusExistingWindow();
    CloseHandle(instance_mutex);
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"WorkNexus", origin, size)) {
    ReleaseMutex(instance_mutex);
    CloseHandle(instance_mutex);
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  ReleaseMutex(instance_mutex);
  CloseHandle(instance_mutex);
  return EXIT_SUCCESS;
}
