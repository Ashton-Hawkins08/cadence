#include "metronome_channel.h"

#include <windows.h>
#include <mmsystem.h>
#include <flutter/standard_method_codec.h>

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
    MetronomeChannel::s_channel;
std::map<std::string, std::wstring> MetronomeChannel::s_soundPaths;

static std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) return {};
  int len = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
  if (len <= 0) return {};
  std::wstring ws(len - 1, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, ws.data(), len);
  return ws;
}

void MetronomeChannel::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto& method = call.method_name();

  if (method == "init") {
    const auto* args =
        std::get_if<flutter::EncodableMap>(call.arguments());
    if (args) {
      s_soundPaths.clear();
      for (const auto& [key, value] : *args) {
        const auto* k = std::get_if<std::string>(&key);
        const auto* v = std::get_if<std::string>(&value);
        if (k && v) {
          s_soundPaths[*k] = Utf8ToWide(*v);
        }
      }
    }
    result->Success();
  } else if (method == "play") {
    const auto* args =
        std::get_if<flutter::EncodableMap>(call.arguments());
    if (args) {
      auto it = args->find(flutter::EncodableValue(std::string("sound")));
      if (it != args->end()) {
        const auto* sound = std::get_if<std::string>(&it->second);
        if (sound) {
          auto pathIt = s_soundPaths.find(*sound);
          if (pathIt != s_soundPaths.end()) {
            PlaySoundW(pathIt->second.c_str(), nullptr,
                       SND_FILENAME | SND_ASYNC | SND_NODEFAULT);
          }
        }
      }
    }
    result->Success();
  } else if (method == "dispose") {
    PlaySoundW(nullptr, nullptr, SND_PURGE);
    s_soundPaths.clear();
    result->Success();
  } else {
    result->NotImplemented();
  }
}

void MetronomeChannel::Register(flutter::BinaryMessenger* messenger) {
  s_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "cadence/metronome",
          &flutter::StandardMethodCodec::GetInstance());
  s_channel->SetMethodCallHandler(HandleMethodCall);
}
