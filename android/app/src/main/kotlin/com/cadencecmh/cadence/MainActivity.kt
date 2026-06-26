package com.cadencecmh.cadence

import android.media.AudioAttributes
import android.media.SoundPool
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var soundPool: SoundPool? = null
    private val soundIds = HashMap<String, Int>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cadence/metronome")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "init" -> {
                        soundPool?.release()
                        soundIds.clear()

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
                        var loaded = 0

                        pool.setOnLoadCompleteListener { _, _, status ->
                            if (status == 0) {
                                loaded++
                                if (loaded >= total) {
                                    soundPool = pool
                                    result.success(null)
                                }
                            }
                        }

                        paths.forEach { (name, path) ->
                            soundIds[name] = pool.load(path, 1)
                        }
                    }

                    "play" -> {
                        val sound = call.argument<String>("sound")
                        val volume = call.argument<Double>("volume")?.toFloat() ?: 1.0f
                        val id = soundIds[sound]
                        if (id != null && id != 0) {
                            soundPool?.play(id, volume, volume, 1, 0, 1.0f)
                        }
                        result.success(null)
                    }

                    "dispose" -> {
                        soundPool?.release()
                        soundPool = null
                        soundIds.clear()
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
