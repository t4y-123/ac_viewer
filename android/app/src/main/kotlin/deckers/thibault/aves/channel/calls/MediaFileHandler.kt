package deckers.thibault.aves.channel.calls

import android.app.Activity
import android.graphics.Rect
import android.net.Uri
import com.bumptech.glide.Glide
import deckers.thibault.aves.channel.calls.Coresult.Companion.safe
import deckers.thibault.aves.channel.calls.Coresult.Companion.safeSuspend
import deckers.thibault.aves.channel.calls.fetchers.RegionFetcher
import deckers.thibault.aves.channel.calls.fetchers.SvgRegionFetcher
import deckers.thibault.aves.channel.calls.fetchers.ThumbnailFetcher
import deckers.thibault.aves.channel.calls.fetchers.TiffRegionFetcher
import deckers.thibault.aves.model.FieldMap
import deckers.thibault.aves.model.provider.ImageProvider.ImageOpCallback
import deckers.thibault.aves.model.provider.ImageProviderFactory.getProvider
import deckers.thibault.aves.utils.MimeTypes
import deckers.thibault.aves.utils.StorageUtils.ensureTrailingSeparator
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

class MediaFileHandler(private val activity: Activity) : MethodCallHandler {
    private val density = activity.resources.displayMetrics.density

    private val regionFetcher = RegionFetcher(activity)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getEntry" -> GlobalScope.launch(Dispatchers.IO) { safe(call, result, ::getEntry) }
            "getThumbnail" -> GlobalScope.launch(Dispatchers.IO) { safeSuspend(call, result, ::getThumbnail) }
            "getRegion" -> GlobalScope.launch(Dispatchers.IO) { safeSuspend(call, result, ::getRegion) }
            "captureFrame" -> GlobalScope.launch(Dispatchers.IO) { safeSuspend(call, result, ::captureFrame) }
            "rename" -> GlobalScope.launch(Dispatchers.IO) { safeSuspend(call, result, ::rename) }
            "clearSizedThumbnailDiskCache" -> GlobalScope.launch(Dispatchers.IO) { safe(call, result, ::clearSizedThumbnailDiskCache) }
            else -> result.notImplemented()
        }
    }

    private fun getEntry(call: MethodCall, result: MethodChannel.Result) {
        val mimeType = call.argument<String>("mimeType") // MIME type is optional
        val uri = call.argument<String>("uri")?.let { Uri.parse(it) }
        if (uri == null) {
            result.error("getEntry-args", "failed because of missing arguments", null)
            return
        }

        val provider = getProvider(uri)
        if (provider == null) {
            result.error("getEntry-provider", "failed to find provider for uri=$uri", null)
            return
        }

        provider.fetchSingle(activity, uri, mimeType, object : ImageOpCallback {
            override fun onSuccess(fields: FieldMap) = result.success(fields)
            override fun onFailure(throwable: Throwable) = result.error("getEntry-failure", "failed to get entry for uri=$uri", throwable.message)
        })
    }

    private suspend fun getThumbnail(call: MethodCall, result: MethodChannel.Result) {
        val uri = call.argument<String>("uri")
        val mimeType = call.argument<String>("mimeType")
        val dateModifiedSecs = call.argument<Number>("dateModifiedSecs")?.toLong()
        val rotationDegrees = call.argument<Int>("rotationDegrees")
        val isFlipped = call.argument<Boolean>("isFlipped")
        val widthDip = call.argument<Number>("widthDip")?.toDouble()
        val heightDip = call.argument<Number>("heightDip")?.toDouble()
        val pageId = call.argument<Int>("pageId")
        val defaultSizeDip = call.argument<Number>("defaultSizeDip")?.toDouble()

        if (uri == null || mimeType == null || dateModifiedSecs == null || rotationDegrees == null || isFlipped == null || widthDip == null || heightDip == null || defaultSizeDip == null) {
            result.error("getThumbnail-args", "failed because of missing arguments", null)
            return
        }

        // convert DIP to physical pixels here, instead of using `devicePixelRatio` in Flutter
        ThumbnailFetcher(
            activity,
            uri,
            mimeType,
            dateModifiedSecs,
            rotationDegrees,
            isFlipped,
            width = (widthDip * density).roundToInt(),
            height = (heightDip * density).roundToInt(),
            pageId = pageId,
            defaultSize = (defaultSizeDip * density).roundToInt(),
            result,
        ).fetch()
    }

    private suspend fun getRegion(call: MethodCall, result: MethodChannel.Result) {
        val uri = call.argument<String>("uri")?.let { Uri.parse(it) }
        val mimeType = call.argument<String>("mimeType")
        val pageId = call.argument<Int>("pageId")
        val sampleSize = call.argument<Int>("sampleSize")
        val x = call.argument<Int>("regionX")
        val y = call.argument<Int>("regionY")
        val width = call.argument<Int>("regionWidth")
        val height = call.argument<Int>("regionHeight")
        val imageWidth = call.argument<Int>("imageWidth")
        val imageHeight = call.argument<Int>("imageHeight")

        if (uri == null || mimeType == null || sampleSize == null || x == null || y == null || width == null || height == null || imageWidth == null || imageHeight == null) {
            result.error("getRegion-args", "failed because of missing arguments", null)
            return
        }

        val regionRect = Rect(x, y, x + width, y + height)
        when (mimeType) {
            MimeTypes.SVG -> SvgRegionFetcher(activity).fetch(
                uri = uri,
                regionRect = regionRect,
                imageWidth = imageWidth,
                imageHeight = imageHeight,
                result = result,
            )
            MimeTypes.TIFF -> TiffRegionFetcher(activity).fetch(
                uri = uri,
                page = pageId ?: 0,
                sampleSize = sampleSize,
                regionRect = regionRect,
                result = result,
            )
            else -> regionFetcher.fetch(
                uri = uri,
                mimeType = mimeType,
                pageId = pageId,
                sampleSize = sampleSize,
                regionRect = regionRect,
                imageWidth = imageWidth,
                imageHeight = imageHeight,
                result = result,
            )
        }
    }

    private suspend fun captureFrame(call: MethodCall, result: MethodChannel.Result) {
        val uri = call.argument<String>("uri")?.let { Uri.parse(it) }
        val desiredName = call.argument<String>("desiredName")
        val exifFields = call.argument<FieldMap>("exif") ?: HashMap()
        val bytes = call.argument<ByteArray>("bytes")
        var destinationDir = call.argument<String>("destinationPath")
        if (uri == null || desiredName == null || bytes == null || destinationDir == null) {
            result.error("captureFrame-args", "failed because of missing arguments", null)
            return
        }

        val provider = getProvider(uri)
        if (provider == null) {
            result.error("captureFrame-provider", "failed to find provider for uri=$uri", null)
            return
        }

        destinationDir = ensureTrailingSeparator(destinationDir)
        provider.captureFrame(activity, desiredName, exifFields, bytes, destinationDir, object : ImageOpCallback {
            override fun onSuccess(fields: FieldMap) = result.success(fields)
            override fun onFailure(throwable: Throwable) = result.error("captureFrame-failure", "failed to capture frame for uri=$uri", throwable.message)
        })
    }

    private suspend fun rename(call: MethodCall, result: MethodChannel.Result) {
        val entryMap = call.argument<FieldMap>("entry")
        val newName = call.argument<String>("newName")
        if (entryMap == null || newName == null) {
            result.error("rename-args", "failed because of missing arguments", null)
            return
        }

        val uri = (entryMap["uri"] as String?)?.let { Uri.parse(it) }
        val path = entryMap["path"] as String?
        val mimeType = entryMap["mimeType"] as String?
        if (uri == null || path == null || mimeType == null) {
            result.error("rename-args", "failed because entry fields are missing", null)
            return
        }

        val provider = getProvider(uri)
        if (provider == null) {
            result.error("rename-provider", "failed to find provider for uri=$uri", null)
            return
        }

        provider.rename(activity, path, uri, mimeType, newName, object : ImageOpCallback {
            override fun onSuccess(fields: FieldMap) = result.success(fields)
            override fun onFailure(throwable: Throwable) = result.error("rename-failure", "failed to rename", throwable.message)
        })
    }

    private fun clearSizedThumbnailDiskCache(@Suppress("UNUSED_PARAMETER") call: MethodCall, result: MethodChannel.Result) {
        Glide.get(activity).clearDiskCache()
        result.success(null)
    }

    companion object {
        const val CHANNEL = "deckers.thibault/aves/media_file"
    }
}