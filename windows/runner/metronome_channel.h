#pragma once

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <map>
#include <memory>
#include <string>

// Handles the 'cadence/metronome' MethodChannel on Windows.
// Uses PlaySoundW to play pre-generated WAV files with zero threading overhead,
// replacing the audioplayers path which fires events from the wrong thread.
class MetronomeChannel {
 public:
  static void Register(flutter::BinaryMessenger* messenger);

 private:
  static std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      s_channel;
  static std::map<std::string, std::wstring> s_soundPaths;

  static void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};
