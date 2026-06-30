#pragma once

#include <windows.h>
#include <mmsystem.h>
#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <atomic>
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

struct BeatDef {
  std::string sound;
  double      multiplier;
  float       volume;
};

// Handles the 'cadence/metronome' MethodChannel on Windows.
//
// Audio is played via waveOut from a dedicated TIME_CRITICAL-priority thread
// driven by QueryPerformanceCounter, completely independent of the Dart event
// loop. Dart's 4 ms polling timer handles only visual state (beat-dot animation).
class MetronomeChannel {
 public:
  static void Register(flutter::BinaryMessenger* messenger);

 private:
  static std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      s_channel;

  // ── waveOut audio ────────────────────────────────────────────────────────
  // Each sound has raw PCM bytes + double-buffered WAVEHDRs so the beat thread
  // can queue the next buffer while the previous one drains.
  struct WavSound {
    std::vector<char> pcm;       // raw 16-bit mono PCM (WAV header stripped)
    WAVEHDR           hdrs[2]{}; // double-buffer
    int               nextHdr{0};
  };
  static HWAVEOUT                         s_hWaveOut;
  static std::map<std::string, WavSound>  s_wavSounds;
  static std::mutex                       s_wavMutex;

  static void PlayPcm(const std::string& name);
  static void CloseWaveOut();

  // ── Beat thread ──────────────────────────────────────────────────────────
  static std::thread       s_beatThread;
  static std::atomic<bool> s_running;
  static std::atomic<bool> s_beatExited;
  static std::atomic<bool> s_paused;
  static std::atomic<int>  s_bpm;
  static std::atomic<bool> s_resetRequested;
  static std::mutex           s_ticksMutex;
  static std::vector<BeatDef> s_ticks;

  static void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  static void StartBeatThread();
  static void StopBeatThread();
  static void RunBeatLoop();

  static std::vector<BeatDef> ParseTicks(const flutter::EncodableList& raw);
  static std::wstring Utf8ToWide(const std::string& utf8);
  static std::vector<char> ReadFile(const std::string& utf8Path);
};
