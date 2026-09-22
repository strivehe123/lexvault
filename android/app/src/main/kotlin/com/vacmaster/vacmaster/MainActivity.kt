package com.vacmaster.vacmaster

import android.Manifest
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.Environment
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        // Android 12+ (API 31+): immediately exit the system SplashScreen
        // so users see our full design (windowBackground with LexVault text,
        // tagline, and branding) instead of the circular-masked icon-only splash.
        // Both use the same background color (#4D7CFF) so there's no flash.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.setOnExitAnimationListener { splashScreenView ->
                splashScreenView.remove()
            }
        }
        super.onCreate(savedInstanceState)
    }

    private val AUDIO_CHANNEL = "com.vacmaster.vacmaster/audio"
    private val TAG = "VAC-STT"
    private val REQ_RECORD_AUDIO = 1001
    private var audioRecord: AudioRecord? = null
    @Volatile private var isRecording = false

    // 挂起的权限请求回调
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_RECORD_AUDIO) {
            val granted = grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
            Log.d(TAG, "RECORD_AUDIO request result: $granted")
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d(TAG, "configureFlutterEngine called")

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL)
            .setMethodCallHandler { call, result ->
                Log.d(TAG, "method: ${call.method}, args: ${call.arguments}")
                when (call.method) {
                    "hasPermission" -> {
                        val p = checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
                                PackageManager.PERMISSION_GRANTED
                        Log.d(TAG, "hasPermission = $p")
                        result.success(p)
                    }
                    "requestPermission" -> {
                        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
                                PackageManager.PERMISSION_GRANTED) {
                            result.success(true)
                        } else {
                            pendingPermissionResult = result
                            requestPermissions(
                                arrayOf(Manifest.permission.RECORD_AUDIO),
                                REQ_RECORD_AUDIO
                            )
                        }
                    }
                    "log" -> {
                        Log.d("VAC-INFO", call.arguments?.toString() ?: "")
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "$AUDIO_CHANNEL/stream")
            .setStreamHandler(AudioStreamHandler())
    }

    inner class AudioStreamHandler : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            val sink = events ?: run {
                Log.d(TAG, "onListen: sink is null")
                return
            }
            Log.d(TAG, "onListen: starting audio capture")

            if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) !=
                    PackageManager.PERMISSION_GRANTED) {
                Log.d(TAG, "onListen: NO PERMISSION")
                sink.error("PERMISSION", "RECORD_AUDIO not granted", null)
                return
            }

            val sampleRate = 16000
            val channelConfig = AudioFormat.CHANNEL_IN_MONO
            val audioFormat = AudioFormat.ENCODING_PCM_16BIT
            val minBuf = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)
            val bufSize = maxOf(minBuf, 1280)
            Log.d(TAG, "minBuf=$minBuf bufSize=$bufSize")

            try {
                audioRecord = AudioRecord(
                    MediaRecorder.AudioSource.MIC,
                    sampleRate,
                    channelConfig,
                    audioFormat,
                    bufSize * 2
                )
                Log.d(TAG, "AudioRecord created, state=${audioRecord?.state}")
            } catch (e: Exception) {
                Log.d(TAG, "AudioRecord init error: ${e.message}")
                sink.error("INIT_ERROR", e.message, null)
                return
            }

            isRecording = true
            audioRecord?.startRecording()
            Log.d(TAG, "startRecording called")

            // ⚠️ 关键修复：把录音循环放到后台线程！
            // EventChannel.onListen 默认在 Android 主线程执行，
            // audioRecord.read() 是阻塞 I/O，必须放后台线程，否则主线程 ANR
            // 但 sink.success() 标记了 @UiThread，必须切回主线程调用
            val mainHandler = Handler(Looper.getMainLooper())
            // 保存原始 PCM 到文件，方便电脑端验证音频质量
            val pcmFile = File(cacheDir, "record_${System.currentTimeMillis()}.pcm")
            val pcmOut = FileOutputStream(pcmFile)
            Log.d(TAG, "saving raw pcm to: ${pcmFile.absolutePath}")

            Thread {
                Log.d(TAG, "recording thread started")
                val buffer = ShortArray(640)
                var frameCount = 0
                var maxAmplitude = 0
                try {
                    while (isRecording) {
                        val read = audioRecord?.read(buffer, 0, buffer.size) ?: -1
                        if (read <= 0) continue

                        // 计算本帧最大振幅，验证麦克风是否真的采到声音
                        var frameMax = 0
                        for (i in 0 until read) {
                            val v = kotlin.math.abs(buffer[i].toInt())
                            if (v > frameMax) frameMax = v
                        }
                        if (frameMax > maxAmplitude) maxAmplitude = frameMax

                        val bytes = ByteBuffer.allocate(read * 2)
                            .order(ByteOrder.LITTLE_ENDIAN)  // ⚠️ 关键修复！Android AudioRecord 是小端，ByteBuffer 默认是大端
                        for (i in 0 until read) {
                            bytes.putShort(buffer[i])
                        }
                        val byteArray = bytes.array()

                        // 同时写入文件
                        pcmOut.write(byteArray)

                        // sink.success() 必须在主线程调用
                        mainHandler.post {
                            if (isRecording) {
                                sink.success(byteArray)
                            }
                        }
                        frameCount++
                        if (frameCount % 50 == 0) {
                            Log.d(TAG, "frames=$frameCount maxAmp=$maxAmplitude lastFrameMax=$frameMax")
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "recording thread error: ${e.message}")
                } finally {
                    try { pcmOut.close() } catch (_: Exception) {}
                    val pcmSize = pcmFile.length()
                    val durationSec = pcmSize / (16000.0 * 2)
                    Log.d(TAG, "recording loop exited, frames=$frameCount maxAmplitude=$maxAmplitude, pcm=${pcmFile.absolutePath} size=$pcmSize bytes (${"%.1f".format(durationSec)}s)")
                    try {
                        audioRecord?.stop()
                        audioRecord?.release()
                    } catch (_: Exception) {}
                    audioRecord = null
                    try {
                        mainHandler.post { sink.endOfStream() }
                    } catch (_: Exception) {}
                }
            }.start()
        }

        override fun onCancel(arguments: Any?) {
            Log.d(TAG, "onCancel called")
            isRecording = false
            audioRecord?.stop()
            audioRecord?.release()
            audioRecord = null
        }
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy")
        isRecording = false
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null
        super.onDestroy()
    }
}
