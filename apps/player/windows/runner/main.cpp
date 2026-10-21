#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <algorithm>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");
  // Impeller costs ~800 ms of engine start-up on Windows here (it falls back
  // to OpenGL ES; measured 2026-10-20 on Flutter 3.47.7, RTX 4070 SUPER):
  // blank app reaches Dart main at ~1.1 s with Impeller, ~0.3 s with Skia.
  // Flutter plans to remove this opt-out, so re-measure on every upgrade.
  project.set_impeller_switch(flutter::ImpellerSwitch::Disabled);

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  // Process creation time (Unix ms) so the app can measure cold start from
  // the moment Windows created the process, not from when Dart woke up.
  FILETIME created, exited, kernel, user;
  if (::GetProcessTimes(::GetCurrentProcess(), &created, &exited, &kernel, &user)) {
    ULARGE_INTEGER t;
    t.LowPart = created.dwLowDateTime;
    t.HighPart = created.dwHighDateTime;
    const unsigned long long unix_ms = (t.QuadPart - 116444736000000000ULL) / 10000ULL;
    command_line_arguments.push_back("--kp-process-start-ms=" + std::to_string(unix_ms));
  }

  // Read before the arguments are moved into the project below.
  const bool offscreen =
      std::find(command_line_arguments.begin(), command_line_arguments.end(),
                "--kp-offscreen") != command_line_arguments.end();

  // One player per user: a second launch brings the running window forward
  // instead of opening another mpv and another provider connection.
  // Off-screen test runs are exempt so they can run side by side.
  HANDLE single_instance = nullptr;
  if (!offscreen) {
    single_instance = ::CreateMutexW(nullptr, TRUE, L"Local\\KaradelikIPTVPlayer");
    if (::GetLastError() == ERROR_ALREADY_EXISTS) {
      if (HWND existing = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Karadelik IPTV Player")) {
        if (::IsIconic(existing)) ::ShowWindow(existing, SW_RESTORE);
        ::SetForegroundWindow(existing);
      }
      if (single_instance) ::CloseHandle(single_instance);
      return EXIT_SUCCESS;
    }
  }

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  window.SetOffscreen(offscreen);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 800);
  if (!window.Create(L"Karadelik IPTV Player", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  // Shut the engine (and the player's GPU surfaces and threads) down while
  // COM is still initialised. Left to the destructor, it ran after
  // CoUninitialize and crashed in flutter_windows.dll on every exit that
  // came through PostQuitMessage.
  window.Destroy();
  ::CoUninitialize();
  if (single_instance) ::CloseHandle(single_instance);
  return EXIT_SUCCESS;
}
