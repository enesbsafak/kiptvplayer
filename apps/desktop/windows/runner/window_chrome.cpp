#include "window_chrome.h"

#include <commctrl.h>
#include <flutter/standard_method_codec.h>
#include <windowsx.h>

#pragma comment(lib, "comctl32.lib")

namespace {

constexpr UINT_PTR kSubclassId = 0x4B50;  // "KP"

double ReadDouble(const flutter::EncodableMap& map, const char* key) {
  auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) return 0;
  if (auto d = std::get_if<double>(&it->second)) return *d;
  if (auto i = std::get_if<int32_t>(&it->second)) return *i;
  return 0;
}

}  // namespace

WindowChrome::WindowChrome(HWND top_level, HWND flutter_view, flutter::BinaryMessenger* messenger)
    : top_level_(top_level), view_(flutter_view) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "karadelik/window", &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() == "setMaxButtonRect") {
      // Logical pixels from Dart, scaled to this window's DPI.
      const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
      if (args) {
        const double scale = GetDpiForWindow(top_level_) / 96.0;
        max_button_ = RECT{static_cast<LONG>(ReadDouble(*args, "left") * scale),
                           static_cast<LONG>(ReadDouble(*args, "top") * scale),
                           static_cast<LONG>(ReadDouble(*args, "right") * scale),
                           static_cast<LONG>(ReadDouble(*args, "bottom") * scale)};
      }
      result->Success();
    } else {
      result->NotImplemented();
    }
  });
  SetWindowSubclass(view_, ViewSubclassProc, kSubclassId, reinterpret_cast<DWORD_PTR>(this));
}

WindowChrome::~WindowChrome() {
  RemoveWindowSubclass(view_, ViewSubclassProc, kSubclassId);
}

bool WindowChrome::InMaxButton(LPARAM screen_point) const {
  if (max_button_.right <= max_button_.left) return false;
  POINT p{GET_X_LPARAM(screen_point), GET_Y_LPARAM(screen_point)};
  ScreenToClient(top_level_, &p);
  return PtInRect(&max_button_, p) != 0;
}

void WindowChrome::SetHover(bool hover) {
  if (hover == hover_) return;
  hover_ = hover;
  channel_->InvokeMethod("maxHover", std::make_unique<flutter::EncodableValue>(hover));
}

void WindowChrome::SetPressed(bool pressed) {
  if (pressed == pressed_) return;
  pressed_ = pressed;
  channel_->InvokeMethod("maxPressed", std::make_unique<flutter::EncodableValue>(pressed));
}

LRESULT CALLBACK WindowChrome::ViewSubclassProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam,
                                                UINT_PTR, DWORD_PTR ref) {
  auto* self = reinterpret_cast<WindowChrome*>(ref);
  // Let the top-level window answer for the maximize button's area.
  if (message == WM_NCHITTEST && self->InMaxButton(lparam)) return HTTRANSPARENT;
  return DefSubclassProc(hwnd, message, wparam, lparam);
}

std::optional<LRESULT> WindowChrome::HandleTopLevel(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
  switch (message) {
    case WM_NCHITTEST:
      if (InMaxButton(lparam)) return HTMAXBUTTON;
      break;
    case WM_NCMOUSEMOVE:
      if (wparam == HTMAXBUTTON) {
        SetHover(true);
        TRACKMOUSEEVENT tme{sizeof(tme), TME_LEAVE | TME_NONCLIENT, hwnd, 0};
        TrackMouseEvent(&tme);
        // Default handling draws nothing for us but lets Windows show Snap.
      } else {
        SetHover(false);
        SetPressed(false);
      }
      break;
    case WM_NCMOUSELEAVE:
      SetHover(false);
      SetPressed(false);
      break;
    case WM_NCLBUTTONDOWN:
    case WM_NCLBUTTONDBLCLK:
      if (wparam == HTMAXBUTTON) {
        // Swallow: DefWindowProc would paint a classic caption button.
        SetPressed(true);
        return 0;
      }
      break;
    case WM_NCLBUTTONUP:
      if (wparam == HTMAXBUTTON) {
        const bool was_pressed = pressed_;
        SetPressed(false);
        if (was_pressed) ShowWindow(hwnd, IsZoomed(hwnd) ? SW_RESTORE : SW_MAXIMIZE);
        return 0;
      }
      break;
  }
  return std::nullopt;
}
