package com.khojlo.khojlo

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var firstFrameShown = false
    private val waitingForFirstFrame = mutableListOf<MethodChannel.Result>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The launch animation starts once its first frame is on screen: the native
        // launch screen stays up until then, which can be well after Flutter built it.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "khojlo/launch")
            .setMethodCallHandler { call, result ->
                when {
                    call.method != "firstFrameShown" -> result.notImplemented()
                    firstFrameShown -> result.success(null)
                    else -> waitingForFirstFrame.add(result)
                }
            }
    }

    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        firstFrameShown = true
        waitingForFirstFrame.forEach { it.success(null) }
        waitingForFirstFrame.clear()
    }
}
