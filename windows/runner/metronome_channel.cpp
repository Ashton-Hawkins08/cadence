#include "metronome_channel.h"

#include <algorithm>
#include <cstdarg>
#include <cstdio>
#include <fstream>
#include <flutter/standard_method_codec.h>

// ── Debug timing probe (temporary) ───────────────────────────────────────────
// Appends QPC-timestamped audio events to C:\cadence\metro_debug.log so
// session-to-session differences (clustered starts, alternating sound) can be
// diagnosed from data instead of by ear. Strip once the timing bugs are dead.
namespace {
FILE*         g_dbg = nullptr;
LARGE_INTEGER g_dbgFreq{};
LARGE_INTEGER g_dbgT0{};

void DbgOpen() {
  if (g_dbg) return;
  if (fopen_s(&g_dbg, "C:\\cadence\\metro_debug.log", "w") != 0) {
    g_dbg = nullptr;
    return;
  }
  QueryPerformanceFrequency(&g_dbgFreq);
  QueryPerformanceCounter(&g_dbgT0);
}

void DbgLog(const char* fmt, ...) {
  if (!g_dbg) return;
  LARGE_INTEGER now;
  QueryPerformanceCounter(&now);
  const double ms = static_cast<double>(now.QuadPart - g_dbgT0.QuadPart) *
                    1000.0 / static_cast<double>(g_dbgFreq.QuadPart);
  fprintf(g_dbg, "%12.2f | ", ms);
  va_list ap;
  va_start(ap, fmt);
  vfprintf(g_dbg, fmt, ap);
  va_end(ap);
  fprintf(g_dbg, "\n");
  fflush(g_dbg);
}
}  // namespace

// ── Static member definitions ─────────────────────────────────────────────────

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
    MetronomeChannel::s_channel;

HWAVEOUT                         MetronomeChannel::s_hWaveOut{nullptr};
std::map<std::string, MetronomeChannel::WavSound> MetronomeChannel::s_wavSounds;
std::thread       MetronomeChannel::s_keepAliveThread;
std::atomic<bool> MetronomeChannel::s_keepAliveRunning{false};

std::thread       MetronomeChannel::s_beatThread;
std::atomic<bool> MetronomeChannel::s_running{false};
std::atomic<bool> MetronomeChannel::s_beatExited{true};
std::atomic<bool> MetronomeChannel::s_paused{false};
std::atomic<int>  MetronomeChannel::s_bpm{120};
std::atomic<bool> MetronomeChannel::s_resetRequested{false};
std::mutex        MetronomeChannel::s_ticksMutex;
std::mutex        MetronomeChannel::s_wavMutex;
std::vector<BeatDef> MetronomeChannel::s_ticks;

// ── Helpers ───────────────────────────────────────────────────────────────────

std::wstring MetronomeChannel::Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) return {};
  int len = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
  if (len <= 0) return {};
  std::wstring ws(len - 1, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, ws.data(), len);
  return ws;
}

std::vector<char> MetronomeChannel::ReadFile(const std::string& utf8Path) {
  std::wstring widePath = Utf8ToWide(utf8Path);
  std::ifstream f(widePath, std::ios::binary | std::ios::ate);
  if (!f.is_open()) return {};
  auto size = static_cast<std::streamsize>(f.tellg());
  if (size <= 0) return {};
  f.seekg(0);
  std::vector<char> data(size);
  f.read(data.data(), size);
  return data;
}

std::vector<BeatDef> MetronomeChannel::ParseTicks(
    const flutter::EncodableList& raw) {
  std::vector<BeatDef> out;
  out.reserve(raw.size());
  for (const auto& item : raw) {
    const auto* m = std::get_if<flutter::EncodableMap>(&item);
    if (!m) continue;

    auto getStr = [&](const char* key) -> std::string {
      auto it = m->find(flutter::EncodableValue(std::string(key)));
      if (it == m->end()) return {};
      const auto* s = std::get_if<std::string>(&it->second);
      return s ? *s : std::string{};
    };
    auto getDbl = [&](const char* key) -> double {
      auto it = m->find(flutter::EncodableValue(std::string(key)));
      if (it == m->end()) return 1.0;
      if (const auto* d   = std::get_if<double>  (&it->second)) return *d;
      if (const auto* i32 = std::get_if<int32_t> (&it->second)) return static_cast<double>(*i32);
      if (const auto* i64 = std::get_if<int64_t> (&it->second)) return static_cast<double>(*i64);
      return 1.0;
    };

    BeatDef def;
    def.sound      = getStr("sound");
    def.multiplier = getDbl("multiplier");
    def.volume     = static_cast<float>(getDbl("volume"));
    out.push_back(std::move(def));
  }
  return out;
}

// ── waveOut audio ─────────────────────────────────────────────────────────────
//
// Uses waveOutWrite to queue raw PCM buffers directly to the audio device.
// A buffer ring per sound (see kWavBufferCount) means the beat thread never
// blocks waiting for a previous buffer to drain.

void MetronomeChannel::CloseWaveOut() {
  std::lock_guard<std::mutex> lk(s_wavMutex);
  if (!s_hWaveOut) return;
  waveOutReset(s_hWaveOut); // marks all in-queue buffers as done
  for (auto& [name, ws] : s_wavSounds) {
    for (auto& hdr : ws.hdrs) {
      if (hdr.dwFlags & WHDR_PREPARED)
        waveOutUnprepareHeader(s_hWaveOut, &hdr, sizeof(WAVEHDR));
    }
  }
  waveOutClose(s_hWaveOut);
  s_hWaveOut = nullptr;
}

void MetronomeChannel::PlayPcm(const std::string& name) {
  std::lock_guard<std::mutex> lk(s_wavMutex);
  if (!s_hWaveOut) {
    DbgLog("PlayPcm %s: NO DEVICE", name.c_str());
    return;
  }
  auto it = s_wavSounds.find(name);
  if (it == s_wavSounds.end()) {
    DbgLog("PlayPcm %s: UNKNOWN SOUND", name.c_str());
    return;
  }

  WavSound& ws = it->second;
  if (ws.pcm.empty()) return;

  MMTIME mmt{};
  mmt.wType = TIME_SAMPLES;
  waveOutGetPosition(s_hWaveOut, &mmt, sizeof(mmt));

  // Try each buffer slot in sequence; prefer one not currently in the driver
  // queue. With kWavBufferCount = 4 and our longest click at 12 ms, all
  // slots should be free long before the same slot is re-requested. The
  // loop handles the pathological case of a slow driver without dropping the
  // beat on the first INQUEUE hit.
  WAVEHDR* hdrPtr = nullptr;
  for (int attempt = 0; attempt < kWavBufferCount; ++attempt) {
    const int idx = ws.nextHdr;
    ws.nextHdr    = (idx + 1) % kWavBufferCount;
    if (!(ws.hdrs[idx].dwFlags & WHDR_INQUEUE)) {
      hdrPtr = &ws.hdrs[idx];
      break;
    }
  }
  if (!hdrPtr) {
    DbgLog("PlayPcm %s: ALL 4 BUFFERS INQUEUE — beat dropped", name.c_str());
    return; // all buffers queued (shouldn't happen with 4 buffers)
  }

  WAVEHDR& hdr = *hdrPtr;

  if (hdr.dwFlags & WHDR_PREPARED)
    waveOutUnprepareHeader(s_hWaveOut, &hdr, sizeof(WAVEHDR));

  ZeroMemory(&hdr, sizeof(WAVEHDR));
  hdr.lpData         = ws.pcm.data();
  hdr.dwBufferLength = static_cast<DWORD>(ws.pcm.size());

  const MMRESULT prep = waveOutPrepareHeader(s_hWaveOut, &hdr, sizeof(WAVEHDR));
  MMRESULT write = MMSYSERR_ERROR;
  if (prep == MMSYSERR_NOERROR)
    write = waveOutWrite(s_hWaveOut, &hdr, sizeof(WAVEHDR));
  DbgLog("PlayPcm %-9s devicePos=%lu prep=%u write=%u", name.c_str(),
         static_cast<unsigned long>(mmt.u.sample), prep, write);
}

// Keeps the click stream warm by pinging 10 ms of silence through the click
// handle every ~1.5 s while the beat thread is NOT actively playing.
//
// History, because this spot has eaten three fixes:
//   1. Blocking warm-up at every start fixed beat SPACING but made beat 1
//      lag the tap by up to 150 ms.
//   2. An infinitely-looping silence buffer (WHDR_BEGINLOOP/dwLoops=∞) on a
//      second handle fixed the lag but produced constant STATIC on this
//      machine — the wave mapper's software loop path replays undefined
//      buffer memory on some drivers. Driver loops are the least-tested
//      legacy corner of waveOut; nothing mainstream uses them.
//   3. This version: plain periodic writes through the exact same PlayPcm
//      path every click uses (provably clean in the timing probe). While
//      playing, the beats themselves keep the stream warm; while stopped or
//      paused, the pings do. The beat thread's prime + 50 ms pre-roll
//      covers whatever residual cold-start remains.
void MetronomeChannel::StartKeepAliveLoop() {
  if (s_keepAliveRunning.load(std::memory_order_acquire)) return;
  s_keepAliveRunning.store(true, std::memory_order_release);
  s_keepAliveThread = std::thread([] {
    int sleepCycles = 0;
    while (s_keepAliveRunning.load(std::memory_order_relaxed)) {
      Sleep(100);
      if (++sleepCycles < 15) continue; // ~1.5 s between pings
      sleepCycles = 0;
      const bool playing = s_running.load(std::memory_order_acquire) &&
                           !s_paused.load(std::memory_order_acquire);
      if (!playing) PlayPcm("_prime");
    }
  });
}

void MetronomeChannel::StopKeepAliveLoop() {
  if (!s_keepAliveRunning.load(std::memory_order_acquire)) return;
  s_keepAliveRunning.store(false, std::memory_order_release);
  if (s_keepAliveThread.joinable()) s_keepAliveThread.join();
}

// ── Beat thread ───────────────────────────────────────────────────────────────
//
// Runs at THREAD_PRIORITY_TIME_CRITICAL, entirely independent of the Dart/Flutter
// event loop. Uses QueryPerformanceCounter (nanosecond-class hardware timer) for
// scheduling. PlayPcm queues PCM buffers via waveOut.
//
// Sleep/spin strategy:
//   > 2 ms until next beat  ->  Sleep(1)    (yield CPU to other threads)
//   <= 2 ms until next beat  ->  spin-wait  (sub-ms accuracy)

void MetronomeChannel::RunBeatLoop() {
  SetThreadPriority(GetCurrentThread(), THREAD_PRIORITY_TIME_CRITICAL);
  // Windows default timer resolution is ~15.6 ms, making Sleep(1) sleep for
  // up to 15 ms.  At 300 BPM with subdivisions the beat thread can overshoot
  // the deadline by 13 ms per sleep, causing audible timing drift.
  // timeBeginPeriod(1) raises the system-wide timer resolution to ~1 ms so
  // Sleep(1) is accurate to ±0.5 ms.  timeEndPeriod(1) restores it on exit.
  timeBeginPeriod(1);

  LARGE_INTEGER freq;
  QueryPerformanceFrequency(&freq);

  // Prime the click stream, then pre-roll beat 0.
  //
  // The keep-alive loop holds the shared-mode RENDER ROUTE open, but the
  // click handle's own stream still idles between sessions, and the first
  // waveOutWrite on an idle stream pays a priming latency that later
  // writes don't. If beat 0 takes that hit, it is HEARD late while beat 1
  // is on time — the "clustered start". So: pay the priming cost on
  // silence, and schedule beat 0 far enough out (kStartPreRollMs) that the
  // prime has finished by then. Dart mirrors the same constant when
  // anchoring its visual timer (metronome_engine.dart start()).
  constexpr LONGLONG kStartPreRollMs = 50;
  DbgLog("BEAT THREAD START (prime + %lld ms pre-roll)", kStartPreRollMs);
  PlayPcm("_prime");

  LARGE_INTEGER nextBeat;
  QueryPerformanceCounter(&nextBeat);
  nextBeat.QuadPart += (freq.QuadPart * kStartPreRollMs) / 1000;

  LARGE_INTEGER pausedAt = {};
  bool wasPaused = false;

  size_t localTickIdx = 0;

  while (s_running.load(std::memory_order_relaxed)) {

    // ── Pause handling ──────────────────────────────────────────────────────
    bool paused = s_paused.load(std::memory_order_acquire);
    if (paused) {
      if (!wasPaused) {
        QueryPerformanceCounter(&pausedAt);
        wasPaused = true;
      }
      // The keep-alive thread pings the stream during pauses, so the first
      // resumed beat plays on a warm stream with no priming spike.
      Sleep(4);
      if (!s_running.load(std::memory_order_relaxed)) break;
      continue;
    }
    if (wasPaused) {
      LARGE_INTEGER now;
      QueryPerformanceCounter(&now);
      nextBeat.QuadPart += now.QuadPart - pausedAt.QuadPart;
      wasPaused = false;
    }

    // ── Pattern reset (section transition / new start) ──────────────────────
    if (s_resetRequested.exchange(false, std::memory_order_acq_rel)) {
      localTickIdx = 0;
      QueryPerformanceCounter(&nextBeat);
    }

    LARGE_INTEGER now;
    QueryPerformanceCounter(&now);

    if (now.QuadPart >= nextBeat.QuadPart) {
      std::vector<BeatDef> ticks;
      {
        std::lock_guard<std::mutex> lk(s_ticksMutex);
        ticks = s_ticks;
      }
      const int bpm = s_bpm.load(std::memory_order_acquire);

      if (ticks.empty()) { Sleep(4); continue; }

      const BeatDef& tick = ticks[localTickIdx % ticks.size()];

      DbgLog("beat idx=%zu sound=%s vol=%.2f", localTickIdx, tick.sound.c_str(),
             tick.volume);
      PlayPcm(tick.sound);

      double intervalMs =
          tick.multiplier * 60000.0 / static_cast<double>(bpm);
      LONGLONG intervalQpc = static_cast<LONGLONG>(
          intervalMs * static_cast<double>(freq.QuadPart) / 1000.0);
      nextBeat.QuadPart += intervalQpc;
      ++localTickIdx;

      // Burst prevention: only skip ahead for a genuine stall (at least 4
      // intervals or 250 ms behind, whichever is larger). A small overrun
      // from transient jitter is left to catch up on the very next loop
      // iteration (fires slightly early) instead of silently dropping a beat.
      QueryPerformanceCounter(&now);
      LONGLONG behindQpc = now.QuadPart - nextBeat.QuadPart;
      LONGLONG maxCatchUpQpc = std::max(intervalQpc * 4, freq.QuadPart / 4);
      if (behindQpc > maxCatchUpQpc) {
        nextBeat.QuadPart = now.QuadPart + intervalQpc;
      }

    } else {
      double remainingMs =
          static_cast<double>(nextBeat.QuadPart - now.QuadPart)
          * 1000.0 / static_cast<double>(freq.QuadPart);

      if (remainingMs > 2.0) {
        Sleep(1);
      }
    }
  }
  timeEndPeriod(1);
  s_beatExited.store(true, std::memory_order_release);
}

void MetronomeChannel::StartBeatThread() {
  StopBeatThread();
  s_beatExited.store(false, std::memory_order_release);
  s_running.store(true, std::memory_order_release);
  s_paused.store(false, std::memory_order_release);
  s_beatThread = std::thread(&MetronomeChannel::RunBeatLoop);
}

void MetronomeChannel::StopBeatThread() {
  s_running.store(false, std::memory_order_release);
  if (!s_beatThread.joinable()) return;
  // Poll s_beatExited up to 200ms. Normal exit happens within ~15ms.
  // If the thread stalls (misbehaving waveOut driver), detach rather than
  // blocking the Flutter platform thread indefinitely.
  for (int ms = 0; ms < 200 && !s_beatExited.load(std::memory_order_acquire);
       ms += 4) {
    Sleep(4);
  }
  if (s_beatExited.load(std::memory_order_acquire)) {
    s_beatThread.join(); // fast — thread already returned
  } else {
    s_beatThread.detach(); // driver hang: orphan to avoid UI freeze
  }
}

// ── Method call handler ───────────────────────────────────────────────────────

void MetronomeChannel::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  const auto& method = call.method_name();

  // ── init: load WAV files and open waveOut device ──────────────────────────
  if (method == "init") {
    DbgOpen();
    DbgLog("== init ==");
    StopBeatThread();
    StopKeepAliveLoop();
    CloseWaveOut();
    s_wavSounds.clear();

    // Open waveOut with the format WavGenerator produces: 22050 Hz, 16-bit mono.
    WAVEFORMATEX wfx{};
    wfx.wFormatTag      = WAVE_FORMAT_PCM;
    wfx.nChannels       = 1;
    wfx.nSamplesPerSec  = 22050;
    wfx.wBitsPerSample  = 16;
    wfx.nBlockAlign     = 2;
    wfx.nAvgBytesPerSec = 44100;
    if (waveOutOpen(&s_hWaveOut, WAVE_MAPPER, &wfx, 0, 0, CALLBACK_NULL)
            != MMSYSERR_NOERROR) {
      s_hWaveOut = nullptr;
    }

    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (args && s_hWaveOut) {
      for (const auto& [key, value] : *args) {
        const auto* k = std::get_if<std::string>(&key);
        const auto* v = std::get_if<std::string>(&value);
        if (k && v) {
          auto wavData = ReadFile(*v);
          if (wavData.size() > 44) {
            WavSound ws;
            ws.pcm.assign(wavData.begin() + 44, wavData.end());
            // 16-bit PCM must be an even byte count: an odd-length buffer
            // byte-shifts the driver's sample framing and turns everything
            // after it into white noise.
            if (ws.pcm.size() & 1) ws.pcm.pop_back();
            s_wavSounds[*k] = std::move(ws);
          }
        }
      }

      // 10 ms of silence used to prime the click stream (see RunBeatLoop)
      // and to keep it warm between sessions and across pauses.
      // SAMPLE-ALIGNED: 220 samples × 2 bytes. The original byte math
      // (22050×2×10/1000 = 441) produced an ODD byte count — half a 16-bit
      // sample — which shifted the driver's sample framing so every buffer
      // queued after a ping decoded as white noise: the "constant static".
      {
        WavSound prime;
        prime.pcm.assign(220 * 2, 0);
        s_wavSounds["_prime"] = std::move(prime);
      }
      // Hold the render route open for the app's lifetime — no click ever
      // pays a route-restart spike, and start/resume need no blocking
      // warm-up (see StartKeepAliveLoop).
      StartKeepAliveLoop();
    }
    result->Success();

  // ── start ─────────────────────────────────────────────────────────────────
  } else if (method == "start") {
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (args) {
      auto bpmIt  = args->find(flutter::EncodableValue(std::string("bpm")));
      auto tickIt = args->find(flutter::EncodableValue(std::string("ticks")));

      if (bpmIt != args->end()) {
        if (const auto* i32 = std::get_if<int32_t>(&bpmIt->second))
          s_bpm.store(*i32, std::memory_order_release);
        else if (const auto* i64 = std::get_if<int64_t>(&bpmIt->second))
          s_bpm.store(static_cast<int>(*i64), std::memory_order_release);
      }
      if (tickIt != args->end()) {
        if (const auto* list =
                std::get_if<flutter::EncodableList>(&tickIt->second)) {
          std::lock_guard<std::mutex> lk(s_ticksMutex);
          s_ticks = ParseTicks(*list);
        }
      }
    }
    s_resetRequested.store(false, std::memory_order_release);
    {
      std::lock_guard<std::mutex> lk(s_ticksMutex);
      DbgLog("== start == bpm=%d ticks=%zu", s_bpm.load(), s_ticks.size());
    }
    // Route is already hot (keep-alive stream) — launch the thread
    // immediately so beat 0 lands within a few ms of the tap.
    StartBeatThread();
    result->Success();

  // ── stop ──────────────────────────────────────────────────────────────────
  } else if (method == "stop") {
    DbgLog("== stop ==");
    StopBeatThread();
    result->Success();

  // ── pause / resume ─────────────────────────────────────────────────────────
  } else if (method == "pause") {
    DbgLog("== pause ==");
    s_paused.store(true, std::memory_order_release);
    result->Success();

  } else if (method == "resume") {
    DbgLog("== resume ==");
    // Route is held hot by the keep-alive stream — just unpause.
    s_paused.store(false, std::memory_order_release);
    result->Success();

  // ── setBpm ────────────────────────────────────────────────────────────────
  } else if (method == "setBpm") {
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (args) {
      auto it = args->find(flutter::EncodableValue(std::string("bpm")));
      if (it != args->end()) {
        if (const auto* i32 = std::get_if<int32_t>(&it->second))
          s_bpm.store(*i32, std::memory_order_release);
        else if (const auto* i64 = std::get_if<int64_t>(&it->second))
          s_bpm.store(static_cast<int>(*i64), std::memory_order_release);
      }
    }
    result->Success();

  // ── updatePattern ──────────────────────────────────────────────────────────
  } else if (method == "updatePattern") {
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (args) {
      auto bpmIt  = args->find(flutter::EncodableValue(std::string("bpm")));
      auto tickIt = args->find(flutter::EncodableValue(std::string("ticks")));

      if (bpmIt != args->end()) {
        if (const auto* i32 = std::get_if<int32_t>(&bpmIt->second))
          s_bpm.store(*i32, std::memory_order_release);
        else if (const auto* i64 = std::get_if<int64_t>(&bpmIt->second))
          s_bpm.store(static_cast<int>(*i64), std::memory_order_release);
      }
      if (tickIt != args->end()) {
        if (const auto* list =
                std::get_if<flutter::EncodableList>(&tickIt->second)) {
          std::lock_guard<std::mutex> lk(s_ticksMutex);
          s_ticks = ParseTicks(*list);
        }
      }
    }
    s_resetRequested.store(true, std::memory_order_release);
    result->Success();

  // ── dispose ───────────────────────────────────────────────────────────────
  } else if (method == "dispose") {
    StopBeatThread();
    StopKeepAliveLoop();
    CloseWaveOut();
    s_wavSounds.clear();
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
