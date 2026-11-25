package id.ayocuci.app

import android.content.Intent
import android.content.ClipData
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.ayocuci/file_provider"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getUri" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        try {
                            val file = File(path)
                            val uri: Uri = FileProvider.getUriForFile(
                                this,
                                "${applicationContext.packageName}.fileprovider",
                                file
                            )
                            result.success(uri.toString())
                        } catch (e: Exception) {
                            result.error("URI_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_PATH", "Path is null", null)
                    }
                }
                "shareImageToWhatsApp" -> {
                    val path = call.argument<String>("path")
                    val isBusiness = call.argument<Boolean>("isBusiness") ?: false
                    val phone = call.argument<String>("phone")
                    val text = call.argument<String>("text") ?: ""
                    if (path != null) {
                        try {
                            val file = File(path)
                            val uri: Uri = FileProvider.getUriForFile(
                                this,
                                "${applicationContext.packageName}.fileprovider",
                                file
                            )
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = "image/*"
                                putExtra(Intent.EXTRA_STREAM, uri)
                                if (text.isNotEmpty()) {
                                    putExtra(Intent.EXTRA_TEXT, text)
                                }
                                if (!phone.isNullOrBlank()) {
                                    putExtra("jid", "${phone}@s.whatsapp.net")
                                }
                                clipData = ClipData.newRawUri("nota", uri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                setPackage(if (isBusiness) "com.whatsapp.w4b" else "com.whatsapp")
                            }
                            grantUriPermission(
                                if (isBusiness) "com.whatsapp.w4b" else "com.whatsapp",
                                uri,
                                Intent.FLAG_GRANT_READ_URI_PERMISSION
                            )
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SHARE_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_PATH", "Path is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
