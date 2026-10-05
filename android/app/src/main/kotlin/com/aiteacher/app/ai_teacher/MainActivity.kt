package com.aiteacher.app.ai_teacher

import android.Manifest
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.media.AudioFocusRequest
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {
    private val SETTINGS_CHANNEL = "app.aiteacher/settings"
    private val NATIVE_AUDIO_CHANNEL = "app.aiteacher/native_audio"
    private val DEVICE_INFO_CHANNEL = "app.aiteacher/device_info"
    private val TAG = "AI_TEACHER_AUDIO"

    private val PERMISSION_REQUEST_MIC = 1001
    private var pendingPermissionResult: MethodChannel.Result? = null

    private var tts: TextToSpeech? = null
    private var isTtsInitialized = false
    private var nativeAudioChannel: MethodChannel? = null

    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private var hasAudioFocus = false

    private val audioFocusChangeListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
        when (focusChange) {
            AudioManager.AUDIOFOCUS_LOSS,
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                Log.d(TAG, "AUDIO_FOCUS: Lost focus ($focusChange), stopping TTS")
                stopNativeAudio()
                runOnUiThread {
                    nativeAudioChannel?.invokeMethod("onAudioFocusLost", mapOf("focusChange" to focusChange))
                }
            }
            AudioManager.AUDIOFOCUS_GAIN -> {
                Log.d(TAG, "AUDIO_FOCUS: Gained focus")
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val binaryMessenger = flutterEngine.dartExecutor.binaryMessenger
        nativeAudioChannel = MethodChannel(binaryMessenger, NATIVE_AUDIO_CHANNEL)

        // Initialize Android Native TextToSpeech engine
        initNativeTts()

        // 1. Settings & Permissions Channel
        MethodChannel(binaryMessenger, SETTINGS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openTtsSettings" -> {
                    try {
                        val intent = Intent("com.android.settings.TTS_SETTINGS")
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_SETTINGS)
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(intent)
                            result.success(true)
                        } catch (ex: Exception) {
                            result.error("UNAVAILABLE", "Could not open settings", ex.message)
                        }
                    }
                }
                "openAppSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", packageName, null)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not open app settings", e.message)
                    }
                }
                "openBluetoothSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not open bluetooth settings", e.message)
                    }
                }
                "checkMicrophonePermission" -> {
                    val granted = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.RECORD_AUDIO
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "requestMicrophonePermission" -> {
                    val granted = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.RECORD_AUDIO
                    ) == PackageManager.PERMISSION_GRANTED
                    if (granted) {
                        result.success(true)
                    } else {
                        pendingPermissionResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.RECORD_AUDIO),
                            PERMISSION_REQUEST_MIC
                        )
                    }
                }
                "isSpeechRecognitionAvailable" -> {
                    val available = SpeechRecognizer.isRecognitionAvailable(this)
                    result.success(available)
                }
                else -> result.notImplemented()
            }
        }

        // 2. Native Audio / TTS Channel
        nativeAudioChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> {
                    if (tts == null) {
                        initNativeTts()
                    }
                    result.success(isTtsInitialized)
                }
                "checkVoices" -> {
                    result.success(getVoiceAvailabilityMap())
                }
                "speak" -> {
                    val text = call.argument<String>("text") ?: ""
                    val localeTag = call.argument<String>("locale") ?: "en-IN"
                    val utteranceId = call.argument<String>("utteranceId") ?: "utt_${System.currentTimeMillis()}"
                    val rate = (call.argument<Double>("rate") ?: 0.5).toFloat()
                    val pitch = (call.argument<Double>("pitch") ?: 1.0).toFloat()
                    val volume = (call.argument<Double>("volume") ?: 1.0).toFloat()

                    val success = speakNative(text, localeTag, utteranceId, rate, pitch, volume)
                    result.success(success)
                }
                "stop" -> {
                    result.success(stopNativeAudio())
                }
                "pause" -> {
                    result.success(stopNativeAudio())
                }
                "requestAudioFocus" -> {
                    result.success(requestAudioFocus())
                }
                "abandonAudioFocus" -> {
                    abandonAudioFocus()
                    result.success(true)
                }
                "isSpeaking" -> {
                    val speaking = tts?.isSpeaking ?: false
                    result.success(speaking)
                }
                "getEngine" -> {
                    result.success(tts?.defaultEngine ?: "unknown")
                }
                else -> result.notImplemented()
            }
        }

        // 3. Device Info Channel
        MethodChannel(binaryMessenger, DEVICE_INFO_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceInfo" -> {
                    try {
                        val actManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                        val memInfo = ActivityManager.MemoryInfo()
                        actManager.getMemoryInfo(memInfo)

                        val info = mapOf(
                            "manufacturer" to Build.MANUFACTURER,
                            "model" to Build.MODEL,
                            "device" to "${Build.MANUFACTURER} ${Build.MODEL}",
                            "androidVersion" to Build.VERSION.RELEASE,
                            "sdkInt" to Build.VERSION.SDK_INT,
                            "totalRamBytes" to memInfo.totalMem,
                            "availRamBytes" to memInfo.availMem,
                            "totalRamMb" to (memInfo.totalMem / (1024 * 1024)),
                            "availRamMb" to (memInfo.availMem / (1024 * 1024)),
                            "lowMemory" to memInfo.lowMemory
                        )
                        result.success(info)
                    } catch (e: Exception) {
                        result.error("DEVICE_INFO_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun initNativeTts() {
        try {
            tts = TextToSpeech(applicationContext, this)
        } catch (e: Exception) {
            isTtsInitialized = false
        }
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            isTtsInitialized = true
            // Configure AudioAttributes for MEDIA playback with SPEECH content type
            // This ensures routing to Bluetooth earbuds (A2DP) and phone stereo speakers
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build()
            tts?.setAudioAttributes(audioAttributes)

            tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) {
                    runOnUiThread {
                        nativeAudioChannel?.invokeMethod("onStart", mapOf("utteranceId" to utteranceId))
                    }
                }

                override fun onDone(utteranceId: String?) {
                    runOnUiThread {
                        nativeAudioChannel?.invokeMethod("onDone", mapOf("utteranceId" to utteranceId))
                    }
                }

                @Deprecated("Deprecated in Java")
                override fun onError(utteranceId: String?) {
                    runOnUiThread {
                        nativeAudioChannel?.invokeMethod(
                            "onError",
                            mapOf("utteranceId" to utteranceId, "errorCode" to -1, "message" to "Playback error")
                        )
                    }
                }

                override fun onError(utteranceId: String?, errorCode: Int) {
                    val msg = when (errorCode) {
                        TextToSpeech.ERROR_NOT_INSTALLED_YET -> "Voice data is not installed yet"
                        TextToSpeech.ERROR_NETWORK -> "Network error during speech synthesis"
                        TextToSpeech.ERROR_OUTPUT -> "Audio output device error"
                        TextToSpeech.ERROR_SERVICE -> "Text to speech service error"
                        TextToSpeech.ERROR_SYNTHESIS -> "Speech synthesis engine failure"
                        else -> "TTS native error code: $errorCode"
                    }
                    runOnUiThread {
                        nativeAudioChannel?.invokeMethod(
                            "onError",
                            mapOf("utteranceId" to utteranceId, "errorCode" to errorCode, "message" to msg)
                        )
                    }
                }

                override fun onRangeStart(utteranceId: String?, start: Int, end: Int, frame: Int) {
                    runOnUiThread {
                        nativeAudioChannel?.invokeMethod(
                            "onRangeStart",
                            mapOf("utteranceId" to utteranceId, "start" to start, "end" to end)
                        )
                    }
                }
            })

            runOnUiThread {
                nativeAudioChannel?.invokeMethod("onEngineReady", mapOf("ready" to true, "engine" to (tts?.defaultEngine ?: "")))
            }
        } else {
            isTtsInitialized = false
            runOnUiThread {
                nativeAudioChannel?.invokeMethod("onEngineReady", mapOf("ready" to false, "status" to status))
            }
        }
    }

    private fun requestAudioFocus(): Boolean {
        if (audioManager == null) {
            audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        }
        if (audioManager == null) return false
        if (hasAudioFocus) return true

        val result = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val playbackAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build()
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setAudioAttributes(playbackAttributes)
                .setAcceptsDelayedFocusGain(false)
                .setOnAudioFocusChangeListener(audioFocusChangeListener)
                .build()
            audioFocusRequest = request
            audioManager?.requestAudioFocus(request) ?: AudioManager.AUDIOFOCUS_REQUEST_FAILED
        } else {
            @Suppress("DEPRECATION")
            audioManager?.requestAudioFocus(
                audioFocusChangeListener,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
            ) ?: AudioManager.AUDIOFOCUS_REQUEST_FAILED
        }

        hasAudioFocus = (result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED)
        Log.d(TAG, "TTS_AUDIO_FOCUS: request granted=$hasAudioFocus")
        return hasAudioFocus
    }

    private fun abandonAudioFocus() {
        if (!hasAudioFocus) return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest?.let { audioManager?.abandonAudioFocusRequest(it) }
                audioFocusRequest = null
            } else {
                @Suppress("DEPRECATION")
                audioManager?.abandonAudioFocus(audioFocusChangeListener)
            }
        } catch (e: Exception) {
            Log.w(TAG, "abandonAudioFocus error: $e")
        } finally {
            hasAudioFocus = false
            Log.d(TAG, "TTS_AUDIO_FOCUS: abandoned")
        }
    }

    private fun stopNativeAudio(): Boolean {
        Log.d(TAG, "TTS_STOP: stopping TTS playback and releasing audio focus")
        var success = false
        try {
            val res = tts?.stop()
            success = (res == TextToSpeech.SUCCESS)
        } catch (e: Exception) {
            Log.w(TAG, "tts.stop() error: $e")
        }
        abandonAudioFocus()
        return success
    }

    private fun speakNative(
        text: String,
        localeTag: String,
        utteranceId: String,
        rate: Float,
        pitch: Float,
        volume: Float
    ): Boolean {
        if (!isTtsInitialized || tts == null) {
            initNativeTts()
            return false
        }

        try {
            // Request audio focus before starting speech
            requestAudioFocus()

            val targetLocale = resolveLocale(localeTag)
            val langResult = tts?.setLanguage(targetLocale)

            if (langResult == TextToSpeech.LANG_MISSING_DATA || langResult == TextToSpeech.LANG_NOT_SUPPORTED) {
                // If requested locale is missing data, try fallback
                if (localeTag.startsWith("te")) {
                    // Telugu is missing
                    Log.w(TAG, "TTS_ERROR: Telugu voice data missing on this device")
                    abandonAudioFocus()
                    runOnUiThread {
                        nativeAudioChannel?.invokeMethod(
                            "onLanguageUnavailable",
                            mapOf("requested" to localeTag, "reason" to "Telugu voice data missing on this device")
                        )
                    }
                    return false
                } else {
                    // Try en-US as fallback for English
                    tts?.setLanguage(Locale.US)
                }
            }

            tts?.setSpeechRate(rate)
            tts?.setPitch(pitch)

            val params = Bundle().apply {
                putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, volume)
                putInt(TextToSpeech.Engine.KEY_PARAM_STREAM, AudioManager.STREAM_MUSIC)
            }

            Log.d(TAG, "TTS_START: utteranceId=$utteranceId, locale=$localeTag, textLength=${text.length}")
            val result = tts?.speak(text, TextToSpeech.QUEUE_FLUSH, params, utteranceId)
            val ok = (result == TextToSpeech.SUCCESS)
            if (!ok) {
                Log.e(TAG, "TTS_ERROR: tts.speak returned non-success code $result")
                abandonAudioFocus()
            }
            return ok
        } catch (e: Exception) {
            Log.e(TAG, "TTS_ERROR: speakNative exception $e")
            abandonAudioFocus()
            return false
        }
    }

    private fun resolveLocale(localeTag: String): Locale {
        return when (localeTag.lowercase()) {
            "te-in", "te" -> Locale("te", "IN")
            "en-in" -> Locale("en", "IN")
            "en-us", "en" -> Locale("en", "US")
            else -> Locale.forLanguageTag(localeTag)
        }
    }

    private fun isLanguageSupported(locale: Locale): Boolean {
        if (!isTtsInitialized || tts == null) return false
        val res = tts?.isLanguageAvailable(locale) ?: TextToSpeech.LANG_NOT_SUPPORTED
        return res >= TextToSpeech.LANG_AVAILABLE
    }

    private fun getVoiceAvailabilityMap(): Map<String, Any> {
        val hasEnIn = isLanguageSupported(Locale("en", "IN"))
        val hasEnUs = isLanguageSupported(Locale.US)
        val hasEn = isLanguageSupported(Locale.ENGLISH) || hasEnIn || hasEnUs
        val hasTeIn = isLanguageSupported(Locale("te", "IN"))
        val hasTe = isLanguageSupported(Locale("te")) || hasTeIn

        val availableLanguagesList = mutableListOf<String>()
        try {
            tts?.availableLanguages?.forEach { loc ->
                availableLanguagesList.add(loc.toLanguageTag())
            }
        } catch (e: Exception) {
            // Ignore
        }

        return mapOf(
            "isReady" to isTtsInitialized,
            "engine" to (tts?.defaultEngine ?: "Default Android TTS"),
            "hasEnglishVoice" to hasEn,
            "hasEnglishIndiaVoice" to hasEnIn,
            "hasTeluguVoice" to hasTe,
            "hasTeluguIndiaVoice" to hasTeIn,
            "availableCount" to availableLanguagesList.size,
            "availableLocales" to availableLanguagesList.take(20)
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_MIC) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    override fun onPause() {
        super.onPause()
        Log.d(TAG, "TEACHER_PAUSE / ACTIVITY_ON_PAUSE: Stopping audio if speaking")
        if (tts?.isSpeaking == true) {
            stopNativeAudio()
            runOnUiThread {
                nativeAudioChannel?.invokeMethod("onActivityStopped", null)
            }
        }
    }

    override fun onStop() {
        super.onStop()
        Log.d(TAG, "TEACHER_STOPPED / ACTIVITY_ON_STOP: Stopping audio completely")
        stopNativeAudio()
        runOnUiThread {
            nativeAudioChannel?.invokeMethod("onActivityStopped", null)
        }
    }

    override fun onDestroy() {
        Log.d(TAG, "TEACHER_DISPOSED / ACTIVITY_ON_DESTROY: Shutting down TTS engine")
        try {
            stopNativeAudio()
            tts?.shutdown()
        } catch (e: Exception) {
            // Ignore
        }
        super.onDestroy()
    }
}
