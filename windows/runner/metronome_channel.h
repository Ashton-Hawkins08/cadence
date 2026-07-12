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
  // Each sound has raw PCM bytes + a ring of WAVEHDRs so the beat thread can
  // queue a new buffer while earlier ones are still draining through the
  // driver. waveOut buffer-completion latency can run well past the audio's
  // own playback length, so 2 buffers starve (and silently drop beats) once
  // the interval gets short — e.g. 16th notes at 300 BPM is a 50 ms gap.
  // 4 buffers give roughly double the headroom.
  static constexpr int kWavBufferCount = 4;
  struct WavSound {
    std::vector<char> pcm;                    // raw 16-bit mono PCM (WAV header stripped)
    WAVEHDR           hdrs[kWavBufferCount]{}; // buffer ring
    int               nextHdr{0};
  };
  static HWAVEOUT                         s_hWaveOut;
  static std::map<std::string, WavSound>  s_wavSounds;
  static std::mutex                       s_wavMutex;

  static void PlayPcm(const std::string& name);
  static void CloseWaveOut();

  // ── Keep-alive pings ─────────────────────────────────────────────────────
  // A maintenance thread pings 10 ms of silence through the click handle
  // every ~1.5 s while not actively playing, so neither the render route
  // nor the click stream ever idles long enough to pay a restart spike on
  // the next real click. (See StartKeepAliveLoop in the .cpp for why this
  // is periodic writes and NOT a driver-looped buffer.)
  static std::thread       s_keepAliveThread;
  static std::atomic<bool> s_keepAliveRunning;
  static void StartKeepAliveLoop();
  static void StopKeepAliveLoop();

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
