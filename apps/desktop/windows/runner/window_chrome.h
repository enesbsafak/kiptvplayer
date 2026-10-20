#ifndef RUNNER_WINDOW_CHROME_H_
#define RUNNER_WINDOW_CHROME_H_

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>
#include <optional>

// Native caption behaviour for the frameless window.
//
// Flutter draws the maximize button, but Windows 11 only offers the Snap
// Layouts flyout when the *top-level* window answers WM_NCHITTEST with
// HTMAXBUTTON. Dart reports the button's rectangle over the
// "karadelik/window" channel; inside it the Flutter view is made transparent
// to hit-testing, the top-level window claims HTMAXBUTTON, and hover / press
// state is sent back so the Flutter button can still draw its states.
class WindowChrome {
 public:
  WindowChrome(HWND top_level, HWND flutter_view, flutter::BinaryMessenger* messenger);
  ~WindowChrome();

  // Runs before plugins see the message; a value means "handled".
  std::optional<LRESULT> HandleTopLevel(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);

 private:
  static LRESULT CALLBACK ViewSubclassProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam,
                                           UINT_PTR id, DWORD_PTR ref);
  bool InMaxButton(LPARAM screen_point) const;
  void SetHover(bool hover);
  void SetPressed(bool pressed);

  HWND top_level_;
  HWND view_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  RECT max_button_{0, 0, 0, 0};  // physical pixels, top-level client coordinates
  bool hover_ = false;
  bool pressed_ = false;
};

#endif  // RUNNER_WINDOW_CHROME_H_
