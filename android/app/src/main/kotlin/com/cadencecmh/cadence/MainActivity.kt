package com.cadencecmh.cadence

import android.content.Intent
import android.media.AudioAttributes
import android.media.SoundPool
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

class MainActivity : FlutterActivity() {

    @Volatile private var soundPool: SoundPool? = null
    private val soundIds = ConcurrentHashMap<String, Int>()

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

    // ──────────────────────────────────────────────────────────────────────────

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cadence/metronome")
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // ── init: load WAV files into SoundPool ────────────────
                    "init" -> {
                        stopBeatThread()
                        val spOld = soundPool
                        soundPool = null
                        spOld?.release()
                        soundIds.clear()

                        // Start foreground service: keeps the process alive when
                        // screen is off and holds a partial wake lock.
                        val svc = Intent(this@MainActivity, MetronomeService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(svc)
                        } else {
                            startService(svc)
                        }

                        // USAGE_MEDIA keeps audio alive when the screen turns
                        // off; USAGE_GAME can be throttled/silenced by OEM
                        // battery optimizers once the activity is backgrounded.
                        val pool = SoundPool.Builder()
                            .setMaxStreams(16)
                            .setAudioAttributes(
                                AudioAttributes.Builder()
                                    .setUsage(AudioAttributes.USAGE_MEDIA)
                                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                                    .build()
                            )
                            .build()

                        @Suppress("UNCHECKED_CAST")
                        val paths = call.arguments as Map<String, String>
                        val total = paths.size

                        if (total == 0) {
                            soundPool = pool
                            result.success(null)
                            return@setMethodCallHandler
                        }

                        // AtomicInteger: onLoadComplete fires on a background thread.
                        val loaded = AtomicInteger(0)
                        val loadFailed = AtomicBoolean(false)
                        pool.setOnLoadCompleteListener { _, _, status ->
                            if (status != 0) loadFailed.set(true)
                            if (loaded.incrementAndGet() == total) {
                                runOnUiThread {
                                    if (loadFailed.get()) {
                                        pool.release()
                                        stopService(Intent(this@MainActivity, MetronomeService::class.java))
                                        result.error("LOAD_FAILED", "Failed to load audio file", null)
                                    } else {
                                        soundPool = pool
                                        // Warm up the audio output path so the first
                                        // real beat has no startup latency/hiccup.
                                        soundIds.values.forEach { id ->
                                            if (id != 0) pool.play(id, 0f, 0f, 1, 0, 1.0f)
                                        }
                                        result.success(null)
                                    }
                                }
                            }
                        }
                        paths.forEach { (name, path) ->
                            soundIds[name] = pool.load(path, 1)
                        }
                    }

                    // ── start: launch native beat thread ───────────────────
                    "start" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as Map<String, Any>
                        currentBpm   = (args["bpm"] as Number).toInt()
                        currentTicks = parseTicks(args["ticks"] as List<*>)
                        resetRequested.set(false)
                        startBeatThread()
                        result.success(null)
                    }

                    // ── stop ───────────────────────────────────────────────
                    "stop" -> {
                        stopBeatThread()
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
                        val sp = soundPool
                        soundPool = null
                        sp?.release()
                        soundIds.clear()
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

    private fun startBeatThread() {
        stopBeatThread()
        val gen = beatGeneration.incrementAndGet()
        threadRunning = true
        threadPaused  = false
        beatThread = Thread("cadence-beat") { runBeatLoop(gen) }.also { t ->
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

    // ── Beat loop (runs on dedicated audio-priority thread) ────────────────────
    //
    // Uses System.nanoTime() — a monotonic hardware counter unaffected by wall-
    // clock adjustments or Dart GC — for sub-millisecond scheduling precision.
    //
    // Sleep/spin strategy:
    //   > 2 ms until next beat  →  sleep 1 ms  (yield CPU to other threads)
    //   ≤ 2 ms until next beat  →  spin-wait   (guarantees ±1 ms accuracy)
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
                try { Thread.sleep(4) } catch (_: InterruptedException) { break }
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
                    try { Thread.sleep(4) } catch (_: InterruptedException) { break }
                    continue
                }

                val tick    = ticks[localTickIdx % ticks.size]
                val soundId = soundIds[tick.sound]
                val sp = soundPool
                if (soundId != null && soundId != 0 && sp != null) {
                    // Retry once: some OEM SoundPool implementations silently
                    // return stream ID 0 on the first play after an audio focus
                    // change or under memory pressure.
                    if (sp.play(soundId, tick.volume, tick.volume, 1, 0, 1.0f) == 0) {
                        sp.play(soundId, tick.volume, tick.volume, 1, 0, 1.0f)
                    }
                }

                val intervalNs = (tick.multiplier * 60_000_000_000.0 / bpm).toLong()
                nextBeatNs    += intervalNs
                localTickIdx  ++

                // Burst prevention: if we're already past the NEXT deadline
                // (e.g. after a long Doze wakeup), skip ahead rather than
                // firing a burst of catch-up beats.
                if (System.nanoTime() >= nextBeatNs) {
                    nextBeatNs = System.nanoTime() + intervalNs
                }

            } else {
                val remainingNs = nextBeatNs - nowNs
                if (remainingNs > 2_000_000L) {
                    try { Thread.sleep(1) } catch (_: InterruptedException) { break }
                }
                // else: spin-wait for the final ≤2 ms for sub-ms precision
            }
        }
    }
}
