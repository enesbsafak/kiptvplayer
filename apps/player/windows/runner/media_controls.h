#ifndef RUNNER_MEDIA_CONTROLS_H_
#define RUNNER_MEDIA_CONTROLS_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <winrt/Windows.Media.h>

#include <memory>
#include <optional>

// Windows media controls (SMTC): the media flyout, keyboard media keys and
// the lock screen show what is playing and send play / pause / next /
// previous / stop back to Dart over "karadelik/media".
//
// Button presses arrive on a WinRT thread; they are posted to the window and
// forwarded from the platform thread, where Flutter channels must be used.
class MediaControls {
 public:
  // [enabled] false (offscreen test runs): the channel answers, Windows sees nothing.
  MediaControls(HWND window, flutter::BinaryMessenger* messenger, bool enabled);
  ~MediaControls();

  // Runs before plugins see the message; a value means "handled".
  std::optional<LRESULT> HandleTopLevel(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);

 private:
  void Update(const flutter::EncodableMap& args);

  HWND window_;
  winrt::Windows::Media::SystemMediaTransportControls smtc_{nullptr};
  winrt::event_token button_token_{};
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_MEDIA_CONTROLS_H_
