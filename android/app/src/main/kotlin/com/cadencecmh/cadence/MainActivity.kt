package com.cadencecmh.cadence

import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

class MainActivity : FlutterActivity() {

    // ── Click player pools ─────────────────────────────────────────────────────
    //
    // Four AudioTrack instances per sound name, cycled round-robin.
    //
    // WHY AudioTrack instead of SoundPool:
    //   SoundPool.play() can silently return 0 under OEM-specific resource
    //   pressure, and even a non-zero stream ID does not guarantee that
    //   AudioFlinger actually feeds the hardware output.  AudioTrack in
    //   MODE_STATIC writes PCM data directly to a hardware buffer — play()
    //   either starts or throws; there is no silent-drop failure mode.
    //
    // WHY four instances per sound:
    //   MODE_STATIC tracks must be stopped before rewinding.  Four instances
    //   ensure we never have to stop a still-draining track to reuse it:
    //   the worst-case reuse gap is 4 × intervalMs (≥ 200 ms at max BPM/sub),
    //   while the longest click is 12 ms.

    private data class ClickPool(
        val tracks: Array<AudioTrack>,
        val idx:    AtomicInteger = AtomicInteger(0),
    )

    private val clickPools = ConcurrentHashMap<String, ClickPool>()

    // Called from the beat thread (URGENT_AUDIO priority).
    private fun playClick(name: String, volume: Float) {
        val pool  = clickPools[name] ?: return
        val track = pool.tracks[pool.idx.getAndIncrement() and (POOL_SIZE - 1)]
        // stop() is a no-op if the track is already stopped (normal case).
        // If the track is somehow still playing (shouldn't happen with pool
        // size 4), stop() truncates the tail — inaudible at <1 ms residual.
        track.stop()
        track.setPlaybackHeadPosition(0)
        track.setVolume(volume)
        track.play()
    }

    private fun releaseClickPools() {
        clickPools.values.forEach { pool -> pool.tracks.forEach { it.release() } }
        clickPools.clear()
    }

    // ── Beat thread ────────────────────────────────────────────────────────────

    private var beatThread: Thread? = null

    // Flags written from UI thread, read from beat thread (@Volatile = visibility).
    @Volatile private var threadRunning = false
    @Volatile private var threadPaused  = false
    @Volatile private var currentBpm: Int = 120

    // Tick list replaced atomically (volatile reference → single write is atomic).
    data class TickDef(val sound: String, val multiplier: Double, val volume: Float)
    @Volatile private var currentTicks: List<TickDef> = emptyList()

    // Set to true by updatePattern/start; beat thread resets tickIdx on detection.
    private val resetRequested = AtomicBoolean(false)
    private val beatGeneration = AtomicInteger(0)

    // The "start" MethodChannel result, held open until the beat thread's
    // first tick actually plays — see runBeatLoop(). This is what lets Dart
    // anchor its visual timer to the real native start time instead of
    // racing the thread's OS scheduling delay.
    @Volatile private var pendingStartResult: MethodChannel.Result? = null

    // ──────────────────────────────────────────────────────────────────────────

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cadence/metronome")
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // ── init: load WAV files into AudioTrack pools ─────────
                    "init" -> {
                        stopBeatThread()
                        releaseClickPools()

                        // Start foreground service: keeps the process alive when
                        // screen is off and holds a partial wake lock.
                        val svc = Intent(this@MainActivity, MetronomeService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(svc)
                        } else {
                            startService(svc)
                        }

                        @Suppress("UNCHECKED_CAST")
                        val paths = call.arguments as Map<String, String>

                        try {
                            paths.forEach { (name, path) ->
                                val pcm   = loadPcm(path)
                                val pool  = Array(POOL_SIZE) { buildAudioTrack(pcm) }
                                clickPools[name] = ClickPool(pool)
                            }
                            // Warm up: one silent play so the hardware audio path
                            // is already open before the first real beat.
                            clickPools.values.firstOrNull()?.tracks?.first()?.let { t ->
                                t.setVolume(0f)
                                t.play()
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            releaseClickPools()
                            stopService(Intent(this@MainActivity, MetronomeService::class.java))
                            result.error("INIT_FAILED", e.message, null)
                        }
                    }

                    // ── start: launch native beat thread ───────────────────
                    "start" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as Map<String, Any>
                        currentBpm   = (args["bpm"] as Number).toInt()
                        currentTicks = parseTicks(args["ticks"] as List<*>)
                        resetRequested.set(false)
                        // Resolve any orphaned result from a start() that was
                        // superseded before its first beat fired.
                        pendingStartResult?.success(null)
                        pendingStartResult = result
                        startBeatThread()
                        // result.success() is deferred — see runBeatLoop().
                    }

                    // ── stop ───────────────────────────────────────────────
                    "stop" -> {
                        stopBeatThread()
                        // If start() never got to fire its first beat before
                        // stop() arrived, resolve it now so Dart's await
                        // doesn't hang.
                        val pending = pendingStartResult
                        pendingStartResult = null
                        pending?.success(null)
                        result.success(null)
                    }

                    // ── pause / resume ─────────────────────────────────────
                    "pause"  -> { threadPaused = true;  result.success(null) }
                    "resume" -> { threadPaused = false; result.success(null) }

                    // ── setBpm: live tempo change (no pattern reset) ───────
                    "setBpm" -> {
                        currentBpm = (call.argument<Any>("bpm") as Number).toInt()
                        result.success(null)
                    }

                    // ── updatePattern: section transition or subdivision change
                    "updatePattern" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as Map<String, Any>
                        currentBpm   = (args["bpm"] as Number).toInt()
                        currentTicks = parseTicks(args["ticks"] as List<*>)
                        resetRequested.set(true)
                        result.success(null)
                    }

                    // ── dispose: release all resources ─────────────────────
                    "dispose" -> {
                        stopBeatThread()
                        releaseClickPools()
                        stopService(Intent(this@MainActivity, MetronomeService::class.java))
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

    @Suppress("UNCHECKED_CAST")
    private fun parseTicks(raw: List<*>): List<TickDef> = raw.map { item ->
        val m = item as Map<String, Any>
        TickDef(
            sound      = m["sound"]       as String,
            multiplier = (m["multiplier"] as Number).toDouble(),
            volume     = (m["volume"]     as Number).toFloat(),
        )
    }

    // WAV files written by Dart's WavGenerator: 44-byte RIFF header + 16-bit
    // mono PCM at 22050 Hz.  We strip the header and hand raw PCM to AudioTrack.
    private fun loadPcm(path: String): ShortArray {
        val bytes = RandomAccessFile(path, "r").use { f ->
            val data = ByteArray(f.length().toInt())
            f.readFully(data)
            data
        }
        require(bytes.size > 44) { "WAV file too small: $path" }
        val buf = ByteBuffer.wrap(bytes, 44, bytes.size - 44)
            .order(ByteOrder.LITTLE_ENDIAN)
            .asShortBuffer()
        return ShortArray(buf.remaining()) { buf.get() }
    }

    private fun buildAudioTrack(pcm: ShortArray): AudioTrack {
        val sampleRate = 22050
        val bufBytes   = pcm.size * 2 // 16-bit = 2 bytes / sample

        val attrs = AudioAttributes.Builder()
            // USAGE_MEDIA keeps audio alive when the screen turns off;
            // USAGE_GAME can be silenced by OEM battery optimizers.
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
            .build()
        val fmt = AudioFormat.Builder()
            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
            .setSampleRate(sampleRate)
            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
            .build()

        // PERFORMANCE_MODE_LOW_LATENCY (API 26+) routes audio through the
        // shortest hardware path, cutting first-play latency by ~10-40 ms
        // on most devices.  Falls back to the standard path on older builds.
        val builder = AudioTrack.Builder()
            .setAudioAttributes(attrs)
            .setAudioFormat(fmt)
            .setBufferSizeInBytes(bufBytes)
            .setTransferMode(AudioTrack.MODE_STATIC)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            builder.setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
        }

        val track: AudioTrack = try {
            builder.build()
        } catch (_: Exception) {
            // PERFORMANCE_MODE_LOW_LATENCY not supported on this device; retry
            // with the default performance mode.
            AudioTrack.Builder()
                .setAudioAttributes(attrs)
                .setAudioFormat(fmt)
                .setBufferSizeInBytes(bufBytes)
                .setTransferMode(AudioTrack.MODE_STATIC)
                .build()
        }

        val written = track.write(pcm, 0, pcm.size)
        check(written == pcm.size) { "AudioTrack.write wrote $written of ${pcm.size} frames" }
        return track
    }

    private fun startBeatThread() {
        stopBeatThread()
        val gen = beatGeneration.incrementAndGet()
        threadRunning = true
        threadPaused  = false
        beatThread = Thread({ runBeatLoop(gen) }, "cadence-beat").also { t ->
            t.isDaemon = true
            t.start()
        }
    }

    private fun stopBeatThread() {
        threadRunning = false
        beatThread?.interrupt()
        try { beatThread?.join(300) } catch (_: InterruptedException) {}
        beatThread = null
    }

    // Called from the beat thread the moment the first beat actually plays.
    // Posts back to the UI thread since MethodChannel results must complete
    // there.
    private fun resolvePendingStart() {
        val pending = pendingStartResult
        if (pending != null) {
            pendingStartResult = null
            runOnUiThread { pending.success(null) }
        }
    }

    // ── Beat loop (runs on dedicated audio-priority thread) ────────────────────
    //
    // Uses System.nanoTime() — a monotonic hardware counter unaffected by wall-
    // clock adjustments or Dart GC — for sub-millisecond scheduling precision.
    //
    // Sleep/spin strategy:
    //   > 3 ms until next beat  →  sleep (remaining − 3 ms) in one shot
    //   ≤ 3 ms until next beat  →  spin-wait  (guarantees ±1 ms accuracy)
    //
    // One long sleep per beat interval (not hundreds of 1 ms sleeps) reduces
    // context-switch overhead and allows the OS to make better scheduling
    // decisions.  Spurious InterruptedExceptions (rare but possible on some
    // OEM kernels) are handled by re-checking the loop condition rather than
    // silently killing the thread.
    private fun runBeatLoop(myGen: Int) {
        // URGENT_AUDIO (-19) resists kernel-level preemption (USB negotiation,
        // charger plug) better than AUDIO (-16). Falls back if the OS refuses.
        try {
            android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_URGENT_AUDIO)
        } catch (_: SecurityException) {
            android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_AUDIO)
        }

        var nextBeatNs = System.nanoTime()
        var pausedAtNs = 0L
        var localTickIdx = 0

        while (threadRunning && beatGeneration.get() == myGen) {

            // ── Pause handling ─────────────────────────────────────────────
            if (threadPaused) {
                if (pausedAtNs == 0L) pausedAtNs = System.nanoTime()
                try {
                    Thread.sleep(4)
                } catch (_: InterruptedException) {
                    if (!threadRunning || beatGeneration.get() != myGen) break
                    Thread.interrupted() // clear flag; spurious — keep running
                }
                continue
            }
            if (pausedAtNs != 0L) {
                // Shift deadline forward by the exact pause duration so the
                // next beat fires at the correct offset from resume time.
                nextBeatNs += System.nanoTime() - pausedAtNs
                pausedAtNs  = 0L
            }

            // ── Pattern reset (section transition / new piece start) ───────
            if (resetRequested.compareAndSet(true, false)) {
                localTickIdx = 0
                nextBeatNs   = System.nanoTime()
            }

            val nowNs = System.nanoTime()

            if (nowNs >= nextBeatNs) {
                // Snapshot shared state once per beat (volatile reads).
                val ticks = currentTicks
                val bpm   = currentBpm

                if (ticks.isEmpty()) {
                    resolvePendingStart()
                    try {
                        Thread.sleep(4)
                    } catch (_: InterruptedException) {
                        if (!threadRunning || beatGeneration.get() != myGen) break
                        Thread.interrupted()
                    }
                    continue
                }

                val tick = ticks[localTickIdx % ticks.size]
                playClick(tick.sound, tick.volume)

                // This is the actual first audible beat of this thread
                // generation — resolve the "start" result now so Dart's
                // visual timer anchors to this exact moment.
                if (localTickIdx == 0) {
                    resolvePendingStart()
                }

                val intervalNs = (tick.multiplier * 60_000_000_000.0 / bpm).toLong()
                nextBeatNs    += intervalNs
                localTickIdx  ++

                // Burst prevention: only skip ahead for a genuine stall (e.g.
                // a long Doze wakeup) — at least 4 intervals or 250 ms behind,
                // whichever is larger.  A small overrun from transient jitter
                // catches up naturally on the very next loop iteration (fires
                // that beat slightly early) rather than dropping it silently.
                val behindNs     = System.nanoTime() - nextBeatNs
                val maxCatchUpNs = maxOf(intervalNs * 4, 250_000_000L)
                if (behindNs > maxCatchUpNs) {
                    nextBeatNs = System.nanoTime() + intervalNs
                }

            } else {
                val remainingNs = nextBeatNs - nowNs

                if (remainingNs > 3_000_000L) {
                    // Sleep (remaining − 3 ms) in one call rather than
                    // polling with hundreds of sleep(1 ms) calls.  This
                    // yields the CPU efficiently while preserving the 3 ms
                    // spin window for sub-ms arrival precision.
                    val sleepMs = (remainingNs - 3_000_000L) / 1_000_000L
                    try {
                        Thread.sleep(sleepMs)
                    } catch (_: InterruptedException) {
                        if (!threadRunning || beatGeneration.get() != myGen) break
                        Thread.interrupted() // spurious; re-enter loop immediately
                    }
                }
                // ≤ 3 ms remaining: spin-wait for sub-millisecond precision.
            }
        }
    }

    companion object {
        // Must be a power of 2 (used for bitwise index wrapping in playClick).
        private const val POOL_SIZE = 4
    }
}
