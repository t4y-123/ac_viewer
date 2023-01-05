package anonymity.ac.viewer.channel.streams

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import anonymity.ac.viewer.model.FieldMap
import anonymity.ac.viewer.model.provider.MediaStoreImageProvider
import anonymity.ac.viewer.utils.LogUtils
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class MediaStoreStreamHandler(private val context: Context, arguments: Any?) : EventChannel.StreamHandler {
    private val ioScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private lateinit var eventSink: EventSink
    private lateinit var handler: Handler

    private var knownEntries: Map<Int?, Int?>? = null
    private var directory: String? = null

    init {
        if (arguments is Map<*, *>) {
            @Suppress("unchecked_cast")
            knownEntries = arguments["knownEntries"] as Map<Int?, Int?>?
            directory = arguments["directory"] as String?
        }
    }

    override fun onListen(arguments: Any?, eventSink: EventSink) {
        this.eventSink = eventSink
        handler = Handler(Looper.getMainLooper())

        ioScope.launch { fetchAll() }
    }

    override fun onCancel(arguments: Any?) {}

    private fun success(result: FieldMap) {
        handler.post {
            try {
                eventSink.success(result)
            } catch (e: Exception) {
                Log.w(LOG_TAG, "failed to use event sink", e)
            }
        }
    }

    private fun endOfStream() {
        handler.post {
            try {
                eventSink.endOfStream()
            } catch (e: Exception) {
                Log.w(LOG_TAG, "failed to use event sink", e)
            }
        }
    }

    private fun fetchAll() {
        MediaStoreImageProvider().fetchAll(context, knownEntries ?: emptyMap(), directory) { success(it) }
        endOfStream()
    }

    companion object {
        private val LOG_TAG = LogUtils.createTag<MediaStoreStreamHandler>()
        const val CHANNEL = "deckers.thibault/aves/media_store_stream"
    }
}