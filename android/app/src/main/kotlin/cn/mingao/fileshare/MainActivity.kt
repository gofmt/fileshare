package cn.mingao.fileshare

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Bundle
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null
    private var pendingResult: MethodChannel.Result? = null

    private val CHANNEL = "cn.mingao.fileshare/storage"
    private val PICK_DIRECTORY_REQUEST = 1001

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        multicastLock = wifi.createMulticastLock("fileshare").apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickDirectory" -> {
                        pendingResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                            addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
                        }
                        startActivityForResult(intent, PICK_DIRECTORY_REQUEST)
                    }
                    "saveFile" -> {
                        val treeUri = call.argument<String>("treeUri")
                        val fileName = call.argument<String>("fileName")
                        val sourcePath = call.argument<String>("sourcePath")
                        if (treeUri == null || fileName == null || sourcePath == null) {
                            result.error("INVALID_ARGS", "参数缺失", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val savedUri = saveToDirectory(Uri.parse(treeUri), fileName, sourcePath)
                            result.success(savedUri)
                        } catch (e: Exception) {
                            result.error("SAVE_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PICK_DIRECTORY_REQUEST) {
            val result = pendingResult
            pendingResult = null
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val uri = data.data!!
                contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                )
                result?.success(uri.toString())
            } else {
                result?.success(null)
            }
        }
    }

    private fun saveToDirectory(treeUri: Uri, fileName: String, sourcePath: String): String? {
        val dir = DocumentFile.fromTreeUri(this, treeUri) ?: return null
        var target = dir.findFile(fileName)
        if (target == null) {
            target = dir.createFile("application/octet-stream", fileName)
        } else {
            // 重名处理：base (1).ext
            val dot = fileName.lastIndexOf('.')
            val base = if (dot > 0) fileName.substring(0, dot) else fileName
            val ext = if (dot > 0) fileName.substring(dot) else ""
            var i = 1
            var candidate = "$base ($i)$ext"
            while (dir.findFile(candidate) != null) {
                i++
                candidate = "$base ($i)$ext"
            }
            target = dir.createFile("application/octet-stream", candidate)
        }
        if (target == null) return null
        contentResolver.openOutputStream(target.uri)?.use { output ->
            File(sourcePath).inputStream().use { input -> input.copyTo(output) }
        }
        return target.uri.toString()
    }

    override fun onDestroy() {
        multicastLock?.release()
        multicastLock = null
        super.onDestroy()
    }
}