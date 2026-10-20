#include "media_controls.h"

#include <flutter/standard_method_codec.h>
#include <systemmediatransportcontrolsinterop.h>

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Storage.Streams.h>

#include <string>

#pragma comment(lib, "windowsapp.lib")

namespace {

using winrt::Windows::Media::MediaPlaybackStatus;
using winrt::Windows::Media::MediaPlaybackType;
using winrt::Windows::Media::SystemMediaTransportControls;
using winrt::Windows::Media::SystemMediaTransportControlsButton;

// Posted to the window with the button in WPARAM.
constexpr UINT kButtonMessage = WM_APP + 0x4B;

std::string ReadString(const flutter::EncodableMap& map, const char* key) {
  auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) return {};
  if (auto s = std::get_if<std::string>(&it->second)) return *s;
  return {};
}

std::wstring Wide(const std::string& utf8) {
  if (utf8.empty()) return {};
  const int n = MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()), nullptr, 0);
  std::wstring out(n, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()), out.data(), n);
  return out;
}

const char* ButtonName(SystemMediaTransportControlsButton b) {
  switch (b) {
    case SystemMediaTransportControlsButton::Play: return "play";
    case SystemMediaTransportControlsButton::Pause: return "pause";
    case SystemMediaTransportControlsButton::Stop: return "stop";
    case SystemMediaTransportControlsButton::Next: return "next";
    case SystemMediaTransportControlsButton::Previous: return "previous";
    default: return nullptr;
  }
}

}  // namespace

MediaControls::MediaControls(HWND window, flutter::BinaryMessenger* messenger, bool enabled) : window_(window) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "karadelik/media", &flutter::StandardMethodCodec::GetInstance());
  // Automated runs answer the channel but never appear in the media flyout.
  if (enabled) try {
    auto interop = winrt::get_activation_factory<SystemMediaTransportControls, ISystemMediaTransportControlsInterop>();
    winrt::check_hresult(interop->GetForWindow(window_, winrt::guid_of<SystemMediaTransportControls>(), winrt::put_abi(smtc_)));
    smtc_.IsPlayEnabled(true);
    smtc_.IsPauseEnabled(true);
    smtc_.IsStopEnabled(true);
    smtc_.IsNextEnabled(true);
    smtc_.IsPreviousEnabled(true);
    smtc_.IsEnabled(false);  // until something plays
    HWND target = window_;
    button_token_ = smtc_.ButtonPressed([target](const auto&, const auto& args) {
      PostMessage(target, kButtonMessage, static_cast<WPARAM>(args.Button()), 0);
    });
  } catch (const winrt::hresult_error&) {
    smtc_ = nullptr;  // no media controls on this system; playback still works
  }
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() == "update") {
      if (const auto* args = std::get_if<flutter::EncodableMap>(call.arguments())) Update(*args);
      result->Success();
    } else {
      result->NotImplemented();
    }
  });
}

MediaControls::~MediaControls() {
  if (smtc_) {
    smtc_.ButtonPressed(button_token_);
    smtc_.IsEnabled(false);
  }
}

// {status: playing|paused|stopped|closed, title, subtitle, art (http URL)}.
// Next / previous mean "channel" for live and "seek" for files: Dart decides.
void MediaControls::Update(const flutter::EncodableMap& args) {
  if (!smtc_) return;
  try {
    const std::string status = ReadString(args, "status");
    if (status == "closed") {
      smtc_.DisplayUpdater().ClearAll();
      smtc_.IsEnabled(false);
      return;
    }
    smtc_.IsEnabled(true);
    smtc_.PlaybackStatus(status == "playing"  ? MediaPlaybackStatus::Playing
                         : status == "paused" ? MediaPlaybackStatus::Paused
                                              : MediaPlaybackStatus::Stopped);
    auto updater = smtc_.DisplayUpdater();
    updater.Type(MediaPlaybackType::Video);
    updater.AppMediaId(L"Karadelik IPTV Player");
    updater.VideoProperties().Title(Wide(ReadString(args, "title")));
    updater.VideoProperties().Subtitle(Wide(ReadString(args, "subtitle")));
    const std::string art = ReadString(args, "art");
    if (art.rfind("http://", 0) == 0 || art.rfind("https://", 0) == 0) {
      updater.Thumbnail(winrt::Windows::Storage::Streams::RandomAccessStreamReference::CreateFromUri(
          winrt::Windows::Foundation::Uri(Wide(art))));
    } else {
      updater.Thumbnail(nullptr);
    }
    updater.Update();
  } catch (const winrt::hresult_error&) {
    // A bad thumbnail URL or a busy flyout must never break playback.
  }
}

std::optional<LRESULT> MediaControls::HandleTopLevel(HWND, UINT message, WPARAM wparam, LPARAM) {
  if (message != kButtonMessage) return std::nullopt;
  if (const char* name = ButtonName(static_cast<SystemMediaTransportControlsButton>(wparam))) {
    channel_->InvokeMethod("button", std::make_unique<flutter::EncodableValue>(std::string(name)));
  }
  return 0;
}
